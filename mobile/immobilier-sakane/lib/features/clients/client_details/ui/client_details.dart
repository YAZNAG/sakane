import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:immobilier/components/bouton_export.dart';
import 'package:immobilier/components/error_widget.dart';
import 'package:immobilier/components/loading_indicator.dart';
import 'package:immobilier/components/tableaux_export.dart';
import 'package:immobilier/core/constants/app_strings.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/constants/enums/permissions.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/core/extensions/extension_on_date.dart';
import 'package:immobilier/core/extensions/extension_on_string.dart';
import 'package:immobilier/core/utils/show_dialogue_question.dart';
import 'package:immobilier/core/utils/show_toast.dart';
import 'package:immobilier/features/clients/client_details/cubit/client_detail_cubit.dart';
import 'package:immobilier/features/immobilier/contrat/ui/visionneuse_contrat.dart';
import 'package:immobilier/models/booking.dart';
import 'package:immobilier/models/client.dart';
import 'package:immobilier/models/manager.dart';
import 'package:immobilier/models/media.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:toastification/toastification.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../routes.dart';
import 'package:immobilier/components/images_galery.dart';

class ClientDetailsPage extends StatefulWidget {
  const ClientDetailsPage({super.key});

  static Widget page(int id) => BlocProvider(
    create: (ctx) => ClientDetailCubit(id)..fetchData(),
    child: ClientDetailsPage(),
  );

  @override
  State<ClientDetailsPage> createState() => _ClientDetailsPageState();
}

class _ClientDetailsPageState extends State<ClientDetailsPage> {
  final Set<int> _loadingDocs = {};
  final Set<String> _contratsEnCours = {};
  final Manager _manager = Dependencies.get<Manager>();

  static const _rouge = Color(0xFFC62828);
  static const _extensionsImage = ['jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp', 'heic', 'heif'];
  static const _extensionsFichier = ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'txt', 'odt', 'csv'];

  // ─── Utilitaires ───────────────────────────────────────────────────────────

  static String _extension(String url) =>
      url.split('?').first.split('.').last.toLowerCase();

  /// Une image, sauf extension de fichier bureautique connue.
  static bool _estImage(Media doc) {
    final url = doc.url;
    if (url == null || url.isEmpty) return false;
    final ext = _extension(url);
    if (_extensionsImage.contains(ext)) return true;
    return !_extensionsFichier.contains(ext);
  }

  static String _nomComplet(Client c) =>
      [c.firstName, c.lastName].whereType<String>().join(' ').trim();

  static String _nomArabe(Client c) =>
      [c.firstNameAr, c.lastNameAr].whereType<String>().join(' ').trim();

  static String _initiales(Client c) {
    String i = '';
    if (c.firstName?.isNotEmpty == true) i += c.firstName![0].toUpperCase();
    if (c.lastName?.isNotEmpty == true) i += c.lastName![0].toUpperCase();
    return i.isEmpty ? '?' : i;
  }

  static String _montant(double v) {
    final brut = v.toStringAsFixed(0);
    final buffer = StringBuffer();
    for (int i = 0; i < brut.length; i++) {
      if (i > 0 && (brut.length - i) % 3 == 0 && brut[i - 1] != '-') buffer.write(' ');
      buffer.write(brut[i]);
    }
    return '${buffer.toString()} MAD';
  }

  static Color? _couleurStatut(Booking b) {
    try {
      return b.status?.color?.toColor;
    } catch (_) {
      return null;
    }
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  TableauExportable? _tableauExport() {
    final client = context.read<ClientDetailCubit>().state.client;
    if (client == null) return null;
    final nom = _nomComplet(client);
    return tableauReservations(
      'Historique – ${nom.isEmpty ? 'Client n° ${client.id}' : nom}',
      client.bookings ?? [],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          'Détails du client',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        foregroundColor: Colors.white,
        backgroundColor: AppColors.primaryColor,
        elevation: 0,
        centerTitle: true,
        actions: [BoutonExport(tableau: _tableauExport)],
      ),
      body: BlocConsumer<ClientDetailCubit, ClientDetailState>(
        listenWhen: (a, b) => a.listeNoireStatus != b.listeNoireStatus,
        listener: _listener,
        builder: (context, state) => _buildContent(state),
      ),
    );
  }

  void _listener(BuildContext context, ClientDetailState state) {
    final messenger = ScaffoldMessenger.of(context);
    if (state.listeNoireStatus == AppStatus.success) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(state.listeNoireMessage ?? AppStrings.success),
          backgroundColor: state.client?.listeNoire != null ? _rouge : Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ));
    } else if (state.listeNoireStatus == AppStatus.error) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(state.listeNoireMessage ?? AppStrings.error),
          backgroundColor: _rouge,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 4),
        ));
    }
  }

  Widget _buildContent(ClientDetailState state) {
    if (state.fetchDataStatus == AppStatus.loading) {
      return Center(child: MyLoadingIndicator());
    } else if (state.fetchDataStatus == AppStatus.error) {
      return MyErrorWidget(
        error: state.error ?? "Error",
        action: AppStrings.tryAgain,
        actionCLick: _fetchData,
      );
    } else if (state.fetchDataStatus == AppStatus.success && state.client != null) {
      final client = state.client!;
      return RefreshIndicator(
        onRefresh: () async => _fetchData(),
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildEntete(client),
              SizedBox(height: 12),
              _buildActionsRapides(client),
              SizedBox(height: 12),
              _buildResume(client.bookings ?? []),
              if (_manager.can(AppPermission.blacklistClient)) ...[
                SizedBox(height: 12),
                _buildBoutonListeNoire(client, state.listeNoireStatus == AppStatus.loading),
              ],
              SizedBox(height: 16),
              _buildContact(client),
              SizedBox(height: 16),
              _buildDocumentsSection(client),
              SizedBox(height: 16),
              _buildHistorique(client.bookings ?? []),
              SizedBox(height: 16),
              _buildContrats(client.bookings ?? []),
            ],
          ),
        ),
      );
    }
    return SizedBox();
  }

  // ─── Carte d'en-tête ───────────────────────────────────────────────────────

  BoxDecoration _carte({Color? bordure}) => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: bordure != null ? Border.all(color: bordure) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      );

  Widget _buildEntete(Client client) {
    final nom = _nomComplet(client);
    final nomAr = _nomArabe(client);
    final listeNoire = client.listeNoire;
    final aPhoto = client.profile != null && client.profile!.isNotEmpty;

    return Container(
      decoration: _carte(bordure: listeNoire != null ? Colors.red.shade200 : null),
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: listeNoire != null ? _rouge : AppColors.primaryColor,
                backgroundImage: aPhoto ? NetworkImage(client.profile!) : null,
                child: aPhoto
                    ? null
                    : Text(
                        _initiales(client),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nom.isEmpty ? 'Client n° ${client.id}' : nom,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    if (nomAr.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Text(
                          nomAr,
                          textDirection: TextDirection.rtl,
                          style: TextStyle(fontSize: 15, color: Colors.grey.shade700),
                        ),
                      ),
                    SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if ((client.identityNumber ?? '').isNotEmpty)
                          _pastille(Icons.badge_outlined, 'CIN ${client.identityNumber}',
                              AppColors.primaryColor),
                        if ((client.nationalite ?? '').trim().isNotEmpty)
                          _pastille(Icons.flag_outlined, client.nationalite!.trim(),
                              AppColors.primaryColor),
                        _pastille(Icons.tag, 'Client n° ${client.id}', Colors.grey.shade700),
                        if (client.rate != null && client.rate! > 0)
                          _pastille(Icons.star, client.rate!.toStringAsFixed(1),
                              Colors.amber.shade800),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (listeNoire != null) ...[
            SizedBox(height: 14),
            _buildBandeauListeNoire(listeNoire),
          ],
        ],
      ),
    );
  }

  Widget _pastille(IconData icone, String texte, Color couleur) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 13, color: couleur),
          SizedBox(width: 4),
          Text(
            texte,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: couleur),
          ),
        ],
      ),
    );
  }

  Widget _buildBandeauListeNoire(ListeNoire listeNoire) {
    final details = [
      if (listeNoire.le != null) 'Le ${listeNoire.le!.formattedDateFr}',
      if ((listeNoire.par ?? '').isNotEmpty) 'par ${listeNoire.par}',
    ].join(' ');
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _rouge,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.block, color: Colors.white, size: 22),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LISTE NOIRE',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  (listeNoire.motif ?? '').isEmpty ? 'Motif non précisé' : listeNoire.motif!,
                  style: TextStyle(color: Colors.white, fontSize: 13.5, height: 1.3),
                ),
                if (details.isNotEmpty) ...[
                  SizedBox(height: 4),
                  Text(
                    details,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Actions rapides ───────────────────────────────────────────────────────

  Widget _buildActionsRapides(Client client) {
    final aTel = (client.tel ?? '').trim().isNotEmpty;
    return Row(
      children: [
        Expanded(
          child: _boutonAction(
            icone: Icons.phone,
            libelle: 'Appeler',
            couleur: AppColors.primaryColor,
            onTap: aTel ? () => _appeler(client.tel!) : null,
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _boutonAction(
            icone: FontAwesomeIcons.whatsapp,
            libelle: 'WhatsApp',
            couleur: Color(0xFF25D366),
            onTap: aTel ? () => _whatsapp(client) : null,
          ),
        ),
        if (_manager.can(AppPermission.updateClient)) ...[
          SizedBox(width: 10),
          Expanded(
            child: _boutonAction(
              icone: Icons.edit_outlined,
              libelle: 'Modifier',
              couleur: Colors.orange.shade700,
              onTap: () => _modifier(client),
            ),
          ),
        ],
      ],
    );
  }

  Widget _boutonAction({
    required IconData icone,
    required String libelle,
    required Color couleur,
    VoidCallback? onTap,
  }) {
    final actif = onTap != null;
    final c = actif ? couleur : Colors.grey.shade400;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.withValues(alpha: 0.35)),
          ),
          child: Column(
            children: [
              FaIcon(icone, color: c, size: 22),
              SizedBox(height: 4),
              Text(
                libelle,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Résumé ────────────────────────────────────────────────────────────────

  Widget _buildResume(List<Booking> bookings) {
    final total = bookings.fold<double>(0, (s, b) => s + (b.amount ?? 0));
    DateTime? dernier;
    for (final b in bookings) {
      final d = b.checkin;
      if (d != null && (dernier == null || d.isAfter(dernier))) dernier = d;
    }
    return Row(
      children: [
        Expanded(child: _tuileResume(Icons.event_note, 'Réservations', '${bookings.length}')),
        SizedBox(width: 8),
        Expanded(child: _tuileResume(Icons.payments_outlined, 'Total', _montant(total))),
        SizedBox(width: 8),
        Expanded(
          child: _tuileResume(
            Icons.history,
            'Dernier séjour',
            dernier?.formattedDateFr ?? '—',
          ),
        ),
      ],
    );
  }

  Widget _tuileResume(IconData icone, String libelle, String valeur) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: _carte(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, size: 18, color: AppColors.primaryColor),
          SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              valeur,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
          ),
          SizedBox(height: 2),
          Text(
            libelle,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ─── Liste noire ───────────────────────────────────────────────────────────

  Widget _buildBoutonListeNoire(Client client, bool enCours) {
    final surListe = client.listeNoire != null;
    final icone = enCours
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: surListe ? _rouge : Colors.white,
            ),
          )
        : Icon(surListe ? Icons.check_circle_outline : Icons.block, size: 20);
    if (surListe) {
      return OutlinedButton.icon(
        onPressed: enCours ? null : _confirmerRetraitListeNoire,
        icon: icone,
        label: Text('Retirer de la liste noire'),
        style: OutlinedButton.styleFrom(
          foregroundColor: _rouge,
          side: BorderSide(color: _rouge),
          padding: EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
    return ElevatedButton.icon(
      onPressed: enCours ? null : _demanderMotifListeNoire,
      icon: icone,
      label: Text('Mettre sur liste noire'),
      style: ElevatedButton.styleFrom(
        backgroundColor: _rouge,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _demanderMotifListeNoire() async {
    final cubit = context.read<ClientDetailCubit>();
    final motif = await showDialog<String>(
      context: context,
      builder: (_) => _DialogueMotifListeNoire(),
    );
    if (!mounted || motif == null) return;
    cubit.ajouterListeNoire(motif);
  }

  Future<void> _confirmerRetraitListeNoire() async {
    final cubit = context.read<ClientDetailCubit>();
    final ok = await showDialogueQuestion(
      context,
      'Retirer ce client de la liste noire ? Il pourra de nouveau réserver.',
    );
    if (!mounted || ok != true) return;
    cubit.retirerListeNoire();
  }

  // ─── Contact ───────────────────────────────────────────────────────────────

  Widget _titreSection(IconData icone, String titre, {int? compteur}) {
    return Row(
      children: [
        Icon(icone, size: 20, color: AppColors.primaryColor),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            titre,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
        ),
        if (compteur != null)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$compteur',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryColor,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildContact(Client client) {
    final lignes = <Widget>[
      if ((client.tel ?? '').isNotEmpty) _ligneContact(Icons.phone_outlined, 'Téléphone', client.tel!),
      if ((client.email ?? '').isNotEmpty) _ligneContact(Icons.email_outlined, 'Email', client.email!),
    ];
    return Container(
      padding: EdgeInsets.all(16),
      decoration: _carte(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _titreSection(Icons.contact_phone_outlined, 'Coordonnées'),
          SizedBox(height: 8),
          if (lignes.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Aucune coordonnée',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            )
          else
            ...lignes,
        ],
      ),
    );
  }

  Widget _ligneContact(IconData icone, String libelle, String valeur) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icone, size: 18, color: AppColors.primaryColor),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(libelle, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                SizedBox(height: 2),
                Text(
                  valeur,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Documents ─────────────────────────────────────────────────────────────

  Widget _buildDocumentsSection(Client client) {
    final docs = client.docs ?? [];
    return Container(
      padding: EdgeInsets.all(16),
      decoration: _carte(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _titreSection(Icons.folder_open, 'Documents', compteur: docs.length),
          SizedBox(height: 12),
          if (docs.isEmpty)
            _etatVide(Icons.description_outlined, 'Aucun document')
          else
            GridView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              physics: NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1,
              ),
              itemCount: docs.length,
              itemBuilder: (context, index) => _buildDocumentItem(docs, index),
            ),
        ],
      ),
    );
  }

  Widget _buildDocumentItem(List<Media> docs, int index) {
    final doc = docs[index];
    final isLoading = _loadingDocs.contains(doc.id);
    final image = _estImage(doc);

    return GestureDetector(
      onTap: isLoading
          ? null
          : image
              ? () => _ouvrirGalerie(docs, doc)
              : () => _viewDocument(doc),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: image
                  ? Image.network(
                      doc.url!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (_, __, ___) => Center(
                        child: Icon(Icons.broken_image, color: Colors.grey.shade400, size: 32),
                      ),
                    )
                  : Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.insert_drive_file_outlined,
                              color: AppColors.primaryColor, size: 32),
                          if ((doc.url ?? '').isNotEmpty) ...[
                            SizedBox(height: 4),
                            Text(
                              _extension(doc.url!).toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
            ),
          ),
          if (isLoading)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  ),
                ),
              ),
            )
          else
            Positioned(
              bottom: 4,
              right: 4,
              child: Container(
                padding: EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(image ? Icons.zoom_out_map : Icons.open_in_new,
                    size: 14, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  /// Ouvre la visionneuse sur toutes les images du client, en commençant
  /// par celle touchée : on passe de l'une à l'autre en glissant.
  void _ouvrirGalerie(List<Media> docs, Media touche) {
    final images = docs.where(_estImage).toList();
    final index = images.indexOf(touche);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ImagesGalery(medias: images, index: index < 0 ? 0 : index),
      ),
    );
  }

  Future<void> _viewDocument(Media doc) async {
    if (doc.url == null || doc.id == null) return;
    setState(() => _loadingDocs.add(doc.id!));
    try {
      final dir = await getTemporaryDirectory();
      final ext = _extension(doc.url!);
      final filePath = '${dir.path}/doc_${doc.id}.$ext';
      final file = File(filePath);
      if (!file.existsSync()) {
        await Dio().download(doc.url!, filePath);
      }
      await OpenFile.open(filePath);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Impossible d'ouvrir le document")),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingDocs.remove(doc.id!));
    }
  }

  // ─── Historique des réservations ───────────────────────────────────────────

  Widget _buildHistorique(List<Booking> bookings) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: _carte(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _titreSection(Icons.event_note, 'Historique des réservations', compteur: bookings.length),
          SizedBox(height: 12),
          if (bookings.isEmpty)
            _etatVide(Icons.event_busy, 'Aucune réservation')
          else
            ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              physics: NeverScrollableScrollPhysics(),
              itemCount: bookings.length,
              separatorBuilder: (_, __) => SizedBox(height: 10),
              itemBuilder: (_, index) => _buildBookingCard(bookings[index]),
            ),
        ],
      ),
    );
  }

  Widget _buildBookingCard(Booking booking) {
    final realestate = booking.realestate;
    final checkin = booking.checkin;
    final checkout = booking.checkout;
    final nights = (checkin != null && checkout != null)
        ? checkout.difference(checkin).inDays
        : null;
    final image = (realestate?.media?.isNotEmpty ?? false) ? realestate!.media!.first.url : null;
    final couleur = _couleurStatut(booking) ?? Colors.grey.shade600;
    final navigable = realestate?.id != null;

    return Material(
      color: Colors.grey.shade50,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: navigable ? () => _navigateToImmobilier(realestate!.id!) : null,
        child: Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: image != null && image.isNotEmpty
                        ? Image.network(
                            image,
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _buildPropertyPlaceholder(),
                          )
                        : _buildPropertyPlaceholder(),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          realestate?.title ?? 'Bien non renseigné',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 3),
                        Text(
                          '${checkin?.formattedDateFr ?? '—'} → ${checkout?.formattedDateFr ?? '—'}',
                          style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
                        ),
                        if ((realestate?.address?.city?.name ?? '').isNotEmpty) ...[
                          SizedBox(height: 2),
                          Text(
                            realestate!.address!.city!.name!,
                            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (navigable)
                    Icon(Icons.chevron_right, color: Colors.grey.shade400),
                ],
              ),
              SizedBox(height: 10),
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: couleur.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      booking.status?.name ?? 'Statut inconnu',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: couleur),
                    ),
                  ),
                  SizedBox(width: 8),
                  if (nights != null)
                    _buildBookingInfo(Icons.nights_stay_outlined,
                        '$nights nuit${nights > 1 ? 's' : ''}'),
                  Spacer(),
                  Text(
                    _montant(booking.amount ?? 0),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                ],
              ),
              if ((booking.creePar ?? '').isNotEmpty) ...[
                SizedBox(height: 6),
                _buildBookingInfo(Icons.person_outline, 'Créée par ${booking.creePar}'),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ─── Historique des contrats ───────────────────────────────────────────────

  static bool _aUrl(String? url) => (url ?? '').trim().isNotEmpty;

  Widget _buildContrats(List<Booking> bookings) {
    final avecContrat = bookings
        .where((b) => _aUrl(b.privateContract) || _aUrl(b.publicContract))
        .toList();
    return Container(
      padding: EdgeInsets.all(16),
      decoration: _carte(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _titreSection(Icons.description_outlined, 'Historique des contrats',
              compteur: avecContrat.length),
          SizedBox(height: 12),
          if (avecContrat.isEmpty)
            _etatVide(Icons.insert_drive_file_outlined, 'Aucun contrat')
          else
            ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              physics: NeverScrollableScrollPhysics(),
              itemCount: avecContrat.length,
              separatorBuilder: (_, __) => SizedBox(height: 10),
              itemBuilder: (_, index) => _buildContratCard(avecContrat[index]),
            ),
        ],
      ),
    );
  }

  Widget _buildContratCard(Booking booking) {
    final couleur = _couleurStatut(booking) ?? Colors.grey.shade600;
    final prive = _aUrl(booking.privateContract);
    final public = _aUrl(booking.publicContract);
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.picture_as_pdf_outlined,
                    size: 20, color: AppColors.primaryColor),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.realestate?.title ?? 'Bien non renseigné',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 3),
                    Text(
                      '${booking.checkin?.formattedDateFr ?? '—'} → ${booking.checkout?.formattedDateFr ?? '—'}',
                      style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: couleur.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  booking.status?.name ?? 'Statut inconnu',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: couleur),
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          Row(
            children: [
              if (prive)
                Expanded(
                  child: _boutonContrat(
                      booking, booking.privateContract!, 'prive', 'Contrat privé'),
                ),
              if (prive && public) SizedBox(width: 8),
              if (public)
                Expanded(
                  child: _boutonContrat(
                      booking, booking.publicContract!, 'public', 'Contrat public'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _boutonContrat(Booking booking, String url, String type, String libelle) {
    final enCours = _contratsEnCours.contains('${booking.id}-$type');
    return OutlinedButton.icon(
      onPressed: enCours ? null : () => _ouvrirContrat(booking, url, type, libelle),
      icon: enCours
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryColor),
            )
          : Icon(Icons.visibility_outlined, size: 18),
      label: Text(libelle, style: TextStyle(fontSize: 12.5)),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primaryColor,
        side: BorderSide(color: AppColors.primaryColor.withValues(alpha: 0.4)),
        padding: EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  /// Telecharge le contrat puis l'ouvre dans la visionneuse (partage inclus).
  Future<void> _ouvrirContrat(Booking booking, String url, String type, String libelle) async {
    final cle = '${booking.id}-$type';
    final cubit = context.read<ClientDetailCubit>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _contratsEnCours.add(cle));
    try {
      final nom = 'contrat_${type}_${booking.id ?? url.hashCode}.pdf';
      final chemin = await cubit.telechargerContrat(url, nom);
      if (!mounted) return;
      setState(() => _contratsEnCours.remove(cle));
      final bien = booking.realestate?.title ?? '';
      await VisionneuseContrat.ouvrir(
        context,
        chemin: chemin,
        titre: bien.isEmpty ? libelle : '$libelle – $bien',
      );
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(content: Text("Le contrat n'a pas pu être ouvert.")),
      );
    } finally {
      if (mounted && _contratsEnCours.contains(cle)) {
        setState(() => _contratsEnCours.remove(cle));
      }
    }
  }

  Widget _etatVide(IconData icone, String texte) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            Icon(icone, size: 44, color: Colors.grey.shade400),
            SizedBox(height: 8),
            Text(texte, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  Widget _buildPropertyPlaceholder() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.home_outlined, color: Colors.grey.shade400, size: 28),
    );
  }

  Widget _buildBookingInfo(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade600),
        SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
      ],
    );
  }

  // ─── Navigation / actions ──────────────────────────────────────────────────

  void _fetchData() {
    BlocProvider.of<ClientDetailCubit>(context).fetchData();
  }

  void _navigateToImmobilier(int id) {
    GoRouter.of(context).push(Routes.homeImmobilier.replaceAll(":id", id.toString()));
  }

  Future<void> _modifier(Client client) async {
    await GoRouter.of(context).push(
      Routes.editClient.replaceFirst(':id', client.id.toString()),
      extra: client,
    );
    if (mounted) _fetchData();
  }

  Future<void> _lancer(Uri uri) async {
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) throw Exception();
    } catch (_) {
      if (mounted) {
        showToast("", description: "Action impossible sur cet appareil", context,
            type: ToastificationType.error);
      }
    }
  }

  void _appeler(String tel) => _lancer(Uri(scheme: 'tel', path: tel.replaceAll(' ', '')));

  void _whatsapp(Client client) {
    var chiffres = (client.tel ?? '').replaceAll(RegExp(r'\D'), '');
    if (chiffres.startsWith('00')) chiffres = chiffres.substring(2);
    // Numéro local (06..., 07...) : on préfixe l'indicatif du client ou du Maroc.
    if (chiffres.startsWith('0')) {
      final indicatif = (client.countryCode ?? '212').replaceAll(RegExp(r'\D'), '');
      chiffres = '${indicatif.isEmpty ? '212' : indicatif}${chiffres.substring(1)}';
    }
    _lancer(Uri.parse('https://wa.me/$chiffres'));
  }
}

/// Demande le motif de la mise sur liste noire (3 caractères au moins).
class _DialogueMotifListeNoire extends StatefulWidget {
  @override
  State<_DialogueMotifListeNoire> createState() => _DialogueMotifListeNoireState();
}

class _DialogueMotifListeNoireState extends State<_DialogueMotifListeNoire> {
  final _controller = TextEditingController();
  String? _erreur;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _valider() {
    final motif = _controller.text.trim();
    if (motif.length < 3) {
      setState(() => _erreur = 'Indiquez un motif (3 caractères minimum)');
      return;
    }
    Navigator.of(context).pop(motif);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Row(
        children: [
          Icon(Icons.block, color: Color(0xFFC62828)),
          SizedBox(width: 8),
          Expanded(child: Text('Mettre sur liste noire', style: TextStyle(fontSize: 17))),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ce client ne pourra plus faire de réservation. Précisez le motif :',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          ),
          SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLines: 3,
            minLines: 2,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) {
              if (_erreur != null) setState(() => _erreur = null);
            },
            decoration: InputDecoration(
              hintText: 'Ex. : dégradations, impayé...',
              errorText: _erreur,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: _valider,
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFFC62828),
            foregroundColor: Colors.white,
          ),
          child: Text('Confirmer'),
        ),
      ],
    );
  }
}
