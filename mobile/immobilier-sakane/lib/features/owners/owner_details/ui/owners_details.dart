import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:toastification/toastification.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:immobilier/components/error_widget.dart';
import 'package:immobilier/components/loading_indicator.dart';
import 'package:immobilier/core/constants/app_strings.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/constants/enums/permissions.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/core/utils/show_toast.dart';
import 'package:immobilier/features/owners/owner_details/cubit/owner_detail_cubit.dart';
import 'package:immobilier/features/owners/owner_details/ui/formulaire_contrat.dart';
import 'package:immobilier/models/contrat_proprietaire.dart';
import 'package:immobilier/models/manager.dart';
import 'package:immobilier/models/owner.dart';
import 'package:immobilier/models/realestate.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/routes.dart';
import 'package:immobilier/components/images_galery.dart';
import 'package:immobilier/models/media.dart';

/// Taille maximale acceptée par le serveur pour un contrat.
const int _tailleMaxContrat = 15 * 1024 * 1024;

class OwnerDetailsPage extends StatefulWidget {
  const OwnerDetailsPage({super.key});

  static Widget page(int id) => BlocProvider(
    create: (ctx) => OwnerDetailCubit(id)..fetchData(),
    child: OwnerDetailsPage(),
  );

  @override
  State<OwnerDetailsPage> createState() => _OwnerDetailsPageState();
}

class _OwnerDetailsPageState extends State<OwnerDetailsPage> {
  static final DateFormat _formatDate = DateFormat('dd/MM/yyyy');

  /// Contrats en cours d'ouverture (téléchargement PDF).
  final Set<int> _ouvertures = {};

  bool get _peutModifier => Dependencies.get<Manager>().can(AppPermission.updateOwner);

  /// Droit « Joindre / supprimer un contrat propriétaire ».
  bool get _peutGererContrats => Dependencies.get<Manager>().can(AppPermission.manageOwnerContracts);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          'Détails du propriétaire',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        foregroundColor: Colors.white,
        backgroundColor: AppColors.primaryColor,
        elevation: 0,
        centerTitle: true,
        actions: [
          if (_peutModifier)
            BlocBuilder<OwnerDetailCubit, OwnerDetailState>(
              builder: (context, state) {
                if (state.owner == null) return SizedBox.shrink();
                return IconButton(
                  icon: Icon(Icons.edit_outlined, color: Colors.white),
                  tooltip: 'Modifier',
                  onPressed: () async {
                    await GoRouter.of(context).push(
                      Routes.editOwner.replaceFirst(':id', state.owner!.id.toString()),
                      extra: state.owner,
                    );
                    _fetchData(silencieux: true);
                  },
                );
              },
            ),
        ],
      ),
      body: BlocConsumer<OwnerDetailCubit, OwnerDetailState>(
        listenWhen: (avant, apres) => avant.actionStatus != apres.actionStatus,
        listener: (context, state) {
          if (state.actionStatus == AppStatus.success && state.actionMessage != null) {
            showToast(state.actionMessage!, context);
          } else if (state.actionStatus == AppStatus.error) {
            showToast(state.actionError ?? 'Une erreur est survenue.', context,
                type: ToastificationType.error);
          }
        },
        builder: (context, state) {
          return Stack(
            children: [
              Positioned.fill(child: _buildContent(state)),
              if (state.actionStatus == AppStatus.loading) ...[
                Positioned.fill(
                  child: ModalBarrier(dismissible: false, color: Colors.black26),
                ),
                Center(child: MyLoadingIndicator()),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildContent(OwnerDetailState state) {
    if (state.fetchStatus == AppStatus.loading) {
      return Center(child: MyLoadingIndicator());
    } else if (state.fetchStatus == AppStatus.error) {
      return MyErrorWidget(
        error: state.error ?? "Error",
        action: AppStrings.tryAgain,
        actionCLick: _fetchData,
      );
    } else if (state.fetchStatus == AppStatus.success && state.owner != null) {
      final owner = state.owner!;
      final realestates = owner.realestates ?? [];
      final idsBiens = realestates.map((r) => r.id).whereType<int>().toSet();
      // Contrats sans appartement, ou liés à un bien qui n'apparaît plus dans la liste.
      final autresContrats = owner.contrats
          .where((c) => c.bienId == null || !idsBiens.contains(c.bienId))
          .toList();

      return RefreshIndicator(
        color: AppColors.primaryColor,
        onRefresh: () => _fetchData(silencieux: true),
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              _buildOwnerHeader(owner),
              _buildRealestatesSection(owner),
              SizedBox(height: 16),
              _buildAutresContratsSection(autresContrats),
              SizedBox(height: 24),
            ],
          ),
        ),
      );
    }
    return SizedBox();
  }

  // ---------------------------------------------------------------------------
  // En-tête
  // ---------------------------------------------------------------------------

  Widget _buildOwnerHeader(Owner owner) {
    final nbAppartements = owner.realestates?.length ?? 0;
    final nbContrats = owner.contrats.length;
    final tel = owner.tel?.trim() ?? '';
    final email = owner.email?.trim() ?? '';
    final adresse = owner.address?.trim() ?? '';

    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(20),
      decoration: _carte(),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: AppColors.primaryColor.withValues(alpha: 0.12),
                child: Text(
                  _initiales(owner.name),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryColor,
                  ),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      owner.name ?? 'Nom non défini',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      "Propriétaire #${owner.id}",
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _compteur(
                  Icons.apartment,
                  nbAppartements,
                  nbAppartements > 1 ? 'Appartements' : 'Appartement',
                  Colors.green,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _compteur(
                  Icons.description_outlined,
                  nbContrats,
                  nbContrats > 1 ? 'Contrats' : 'Contrat',
                  Colors.indigo,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          if (tel.isNotEmpty) ...[
            _buildContactRow(
              Icons.phone,
              "Téléphone",
              tel,
              actions: [
                _boutonRond(
                  icon: Icons.call,
                  couleur: AppColors.primaryColor,
                  tooltip: 'Appeler',
                  onTap: () => _appeler(tel),
                ),
                SizedBox(width: 8),
                _boutonRond(
                  icon: FontAwesomeIcons.whatsapp,
                  couleur: Color(0xFF25D366),
                  tooltip: 'WhatsApp',
                  onTap: () => _whatsapp(tel),
                ),
              ],
            ),
            SizedBox(height: 10),
          ],
          if (email.isNotEmpty) ...[
            _buildContactRow(
              Icons.email,
              "Email",
              email,
              actions: [
                _boutonRond(
                  icon: Icons.send,
                  couleur: AppColors.primaryColor,
                  tooltip: 'Envoyer un email',
                  onTap: () => _ouvrirUri(Uri(scheme: 'mailto', path: email),
                      "Impossible d'ouvrir l'application email"),
                ),
              ],
            ),
            SizedBox(height: 10),
          ],
          if (adresse.isNotEmpty)
            _buildContactRow(Icons.location_on, "Adresse", adresse),
          if (tel.isEmpty && email.isEmpty && adresse.isEmpty)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: Colors.grey.shade600),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Aucune information de contact disponible",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _compteur(IconData icon, int valeur, String libelle, MaterialColor couleur) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: couleur.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: couleur.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: couleur.shade700),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$valeur',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: couleur.shade800,
                  ),
                ),
                Text(
                  libelle,
                  style: TextStyle(fontSize: 12, color: couleur.shade700),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactRow(IconData icon, String label, String value, {List<Widget> actions = const []}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primaryColor),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
                SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
  }

  Widget _boutonRond({
    required IconData icon,
    required Color couleur,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: couleur,
        shape: CircleBorder(),
        child: InkWell(
          customBorder: CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(8),
            child: FaIcon(icon, size: 18, color: Colors.white),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Appartements
  // ---------------------------------------------------------------------------

  Widget _buildRealestatesSection(Owner owner) {
    final realestates = owner.realestates ?? [];

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      padding: EdgeInsets.all(16),
      decoration: _carte(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _enteteSection(Icons.apartment, "Appartements", realestates.length),
          SizedBox(height: 16),
          if (realestates.isEmpty)
            _etatVide(Icons.home_work_outlined, "Aucun appartement")
          else
            ListView.separated(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: realestates.length,
              separatorBuilder: (context, index) => SizedBox(height: 16),
              itemBuilder: (context, index) {
                final bien = realestates[index];
                final contrats = owner.contrats.where((c) => c.bienId != null && c.bienId == bien.id).toList();
                return _buildRealestateCard(bien, contrats);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildRealestateCard(Realestate realestate, List<ContratProprietaire> contrats) {
    final imageUrl = realestate.media?.isNotEmpty == true
        ? realestate.media!.first.url
        : null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            child: InkWell(
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              onTap: () => _navigateToRealestateDetails(realestate),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image
                  if (imageUrl != null && imageUrl.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                      child: Image.network(
                        imageUrl,
                        height: 160,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => _buildImagePlaceholder(),
                      ),
                    )
                  else
                    _buildImagePlaceholder(),

                  Padding(
                    padding: EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Titre et statut
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                realestate.title ?? 'Titre non défini',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (realestate.status != null && (realestate.status!.name ?? '').isNotEmpty)
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(realestate.status!.value, realestate.status!.color),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  realestate.status!.name ?? '',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),

                        SizedBox(height: 8),

                        // Type et transaction
                        Row(
                          children: [
                            if (realestate.category != null) ...[
                              Icon(Icons.category, size: 14, color: Colors.grey.shade600),
                              SizedBox(width: 4),
                              Text(
                                realestate.category!.name ?? '',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                              ),
                              if (realestate.typeTransaction != null) ...[
                                SizedBox(width: 8),
                                Text('•', style: TextStyle(color: Colors.grey.shade600)),
                                SizedBox(width: 8),
                              ],
                            ],
                            if (realestate.typeTransaction != null) ...[
                              Icon(Icons.swap_horiz, size: 14, color: Colors.grey.shade600),
                              SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  realestate.typeTransaction!.name ?? '',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),

                        SizedBox(height: 10),

                        // Caractéristiques
                        Container(
                          padding: EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildPropertyDetail(Icons.square_foot, "${realestate.surface ?? 0} m²"),
                              _buildPropertyDetail(Icons.bed, "${realestate.nbRooms ?? 0} ch"),
                              _buildPropertyDetail(Icons.bathroom, "${realestate.nbBathroom ?? 0} sdb"),
                            ],
                          ),
                        ),

                        SizedBox(height: 10),

                        // Adresse
                        if (realestate.address != null) ...[
                          Row(
                            children: [
                              Icon(Icons.location_on, size: 14, color: Colors.grey.shade600),
                              SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  [
                                    realestate.address!.address,
                                    realestate.address!.city?.name,
                                  ].where((e) => e != null && e.toString().trim().isNotEmpty).join(', '),
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 10),
                        ],

                        // Prix
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                if (realestate.rate != null && realestate.rate! > 0) ...[
                                  Icon(Icons.star, size: 16, color: Colors.amber.shade700),
                                  SizedBox(width: 4),
                                  Text(
                                    "${realestate.rate!.toStringAsFixed(1)} (${realestate.rateCount ?? 0})",
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            Text(
                              "${realestate.price ?? 0} MAD",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          Divider(height: 1, color: Colors.grey.shade300),

          // Contrats de l'appartement
          Padding(
            padding: EdgeInsets.fromLTRB(12, 8, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.description_outlined, size: 16, color: AppColors.primaryColor),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        "Contrats (${contrats.length})",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    if (_peutGererContrats)
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primaryColor,
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () => _joindreContrat(bien: realestate),
                        icon: Icon(Icons.attach_file, size: 16),
                        label: Text("Joindre un contrat", style: TextStyle(fontSize: 12)),
                      ),
                  ],
                ),
                if (contrats.isEmpty)
                  Padding(
                    padding: EdgeInsets.only(left: 22, top: 2, bottom: 6),
                    child: Text(
                      "Aucun contrat",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  )
                else
                  ...contrats.map(_buildContratRow),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Autres contrats
  // ---------------------------------------------------------------------------

  Widget _buildAutresContratsSection(List<ContratProprietaire> contrats) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      padding: EdgeInsets.all(16),
      decoration: _carte(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _enteteSection(Icons.folder_outlined, "Autres contrats", contrats.length),
          SizedBox(height: 4),
          Text(
            "Contrats non liés à un appartement",
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          SizedBox(height: 8),
          if (contrats.isEmpty)
            _etatVide(Icons.description_outlined, "Aucun contrat")
          else
            ...contrats.map(_buildContratRow),
          if (_peutGererContrats) ...[
            SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryColor,
                  side: BorderSide(color: AppColors.primaryColor),
                ),
                onPressed: () => _joindreContrat(),
                icon: Icon(Icons.attach_file, size: 18),
                label: Text("Joindre un contrat"),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContratRow(ContratProprietaire contrat) {
    final nom = (contrat.titre ?? '').trim().isNotEmpty
        ? contrat.titre!.trim()
        : ((contrat.nomFichier ?? '').trim().isNotEmpty ? contrat.nomFichier!.trim() : 'Contrat #${contrat.id}');
    final periode = _periode(contrat);
    final ajout = [
      if (contrat.creeLe != null) 'Ajouté le ${_formatDate.format(contrat.creeLe!)}',
      if ((contrat.par ?? '').trim().isNotEmpty) 'par ${contrat.par!.trim()}',
    ].join(' ');
    final enOuverture = _ouvertures.contains(contrat.id);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: enOuverture ? null : () => _ouvrirContrat(contrat),
        onLongPress: _peutGererContrats ? () => _confirmerSuppression(contrat) : null,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: contrat.estPdf ? Colors.red.shade50 : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  contrat.estPdf ? Icons.picture_as_pdf : Icons.image_outlined,
                  size: 20,
                  color: contrat.estPdf ? Colors.red.shade600 : AppColors.primaryColor,
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nom,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (periode != null)
                      Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Row(
                          children: [
                            Icon(Icons.date_range, size: 12, color: Colors.grey.shade600),
                            SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                periode,
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (ajout.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Text(
                          ajout,
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              if (enOuverture)
                Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryColor),
                  ),
                )
              else
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, size: 20, color: Colors.grey.shade600),
                  tooltip: 'Actions',
                  onSelected: (choix) {
                    if (choix == 'ouvrir') _ouvrirContrat(contrat);
                    if (choix == 'supprimer') _confirmerSuppression(contrat);
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'ouvrir',
                      child: Row(
                        children: [
                          Icon(Icons.open_in_new, size: 18),
                          SizedBox(width: 10),
                          Text('Ouvrir'),
                        ],
                      ),
                    ),
                    if (_peutGererContrats)
                      PopupMenuItem(
                        value: 'supprimer',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, size: 18, color: Colors.red.shade600),
                            SizedBox(width: 10),
                            Text('Supprimer', style: TextStyle(color: Colors.red.shade600)),
                          ],
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  String? _periode(ContratProprietaire contrat) {
    final debut = contrat.dateDebut != null ? _formatDate.format(contrat.dateDebut!) : null;
    final fin = contrat.dateFin != null ? _formatDate.format(contrat.dateFin!) : null;
    if (debut != null && fin != null) return '$debut → $fin';
    if (debut != null) return 'Depuis le $debut';
    if (fin != null) return "Jusqu'au $fin";
    return null;
  }

  // ---------------------------------------------------------------------------
  // Éléments communs
  // ---------------------------------------------------------------------------

  BoxDecoration _carte() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 8,
          offset: Offset(0, 2),
        ),
      ],
    );
  }

  Widget _enteteSection(IconData icon, String titre, int nombre) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: AppColors.primaryColor),
            SizedBox(width: 8),
            Text(
              titre,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            "$nombre",
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

  Widget _etatVide(IconData icon, String texte) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            Icon(icon, size: 44, color: Colors.grey.shade400),
            SizedBox(height: 8),
            Text(texte, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      height: 120,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_not_supported, size: 40, color: Colors.grey.shade500),
          SizedBox(height: 6),
          Text("Aucune image", style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _buildPropertyDetail(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.primaryColor),
        SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String? statusValue, String? couleurServeur) {
    final hex = (couleurServeur ?? '').replaceFirst('#', '').trim();
    if (hex.length == 6) {
      final valeur = int.tryParse(hex, radix: 16);
      if (valeur != null) return Color(0xFF000000 | valeur);
    }
    switch (statusValue) {
      case 'active':
        return Colors.green.shade600;
      case 'inactive':
        return Colors.red.shade600;
      case 'pending':
        return Colors.orange.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  String _initiales(String? nom) {
    final mots = (nom ?? '').trim().split(RegExp(r'\s+')).where((m) => m.isNotEmpty).toList();
    if (mots.isEmpty) return '?';
    if (mots.length == 1) return mots.first.substring(0, 1).toUpperCase();
    return (mots.first.substring(0, 1) + mots.last.substring(0, 1)).toUpperCase();
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _fetchData({bool silencieux = false}) {
    return BlocProvider.of<OwnerDetailCubit>(context).fetchData(silencieux: silencieux);
  }

  Future<void> _navigateToRealestateDetails(Realestate realestate) async {
    if (realestate.id == null) return;
    await GoRouter.of(context).push(
      Routes.homeImmobilier.replaceAll(":id", realestate.id.toString()),
    );
    if (mounted) _fetchData(silencieux: true);
  }

  Future<void> _appeler(String tel) {
    return _ouvrirUri(Uri(scheme: 'tel', path: tel.replaceAll(' ', '')),
        "Impossible d'ouvrir l'application téléphone");
  }

  Future<void> _whatsapp(String tel) {
    var numero = tel.replaceAll(RegExp(r'[^0-9+]'), '');
    if (numero.startsWith('+')) {
      numero = numero.substring(1);
    } else if (numero.startsWith('00')) {
      numero = numero.substring(2);
    } else if (numero.startsWith('0')) {
      // Numéro national marocain : 06… → 2126…
      numero = '212${numero.substring(1)}';
    }
    return _ouvrirUri(Uri.parse('https://wa.me/$numero'), "Impossible d'ouvrir WhatsApp");
  }

  Future<void> _ouvrirUri(Uri uri, String erreur) async {
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) showToast(erreur, context, type: ToastificationType.error);
    } catch (_) {
      if (mounted) showToast(erreur, context, type: ToastificationType.error);
    }
  }

  Future<void> _ouvrirContrat(ContratProprietaire contrat) async {
    if (contrat.url.isEmpty) {
      showToast("Fichier du contrat introuvable", context, type: ToastificationType.error);
      return;
    }
    if (!contrat.estPdf) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ImagesGalery(medias: [Media(id: contrat.id, url: contrat.url)]),
        ),
      );
      return;
    }

    setState(() => _ouvertures.add(contrat.id));
    try {
      final dir = await getTemporaryDirectory();
      final chemin = '${dir.path}/contrat_proprietaire_${contrat.id}.pdf';
      final fichier = File(chemin);
      if (!fichier.existsSync() || fichier.lengthSync() == 0) {
        await Dio().download(contrat.url, chemin);
      }
      final resultat = await OpenFile.open(chemin);
      if (resultat.type != ResultType.done && mounted) {
        showToast(
          "Impossible d'ouvrir le contrat",
          context,
          description: resultat.message,
          type: ToastificationType.error,
        );
      }
    } catch (_) {
      if (mounted) {
        showToast("Impossible de télécharger le contrat", context, type: ToastificationType.error);
      }
    } finally {
      if (mounted) setState(() => _ouvertures.remove(contrat.id));
    }
  }

  Future<void> _confirmerSuppression(ContratProprietaire contrat) async {
    if (!_peutGererContrats) return;
    final cubit = BlocProvider.of<OwnerDetailCubit>(context);
    final nom = (contrat.titre ?? '').trim().isNotEmpty ? contrat.titre!.trim() : (contrat.nomFichier ?? 'ce contrat');
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Supprimer le contrat ?'),
        content: Text('« $nom » sera définitivement supprimé.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirme == true) {
      await cubit.supprimerContrat(contrat.id);
    }
  }

  Future<void> _joindreContrat({Realestate? bien}) async {
    final cubit = BlocProvider.of<OwnerDetailCubit>(context);

    final source = await showModalBottomSheet<String>(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                bien?.title != null ? 'Joindre un contrat — ${bien!.title}' : 'Joindre un contrat',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
            ListTile(
              leading: Icon(Icons.upload_file, color: AppColors.primaryColor),
              title: Text('Fichier PDF / image'),
              subtitle: Text('PDF, JPG ou PNG — 15 Mo max.'),
              onTap: () => Navigator.of(ctx).pop('fichier'),
            ),
            ListTile(
              leading: Icon(Icons.photo_camera_outlined, color: AppColors.primaryColor),
              title: Text('Prendre une photo'),
              onTap: () => Navigator.of(ctx).pop('camera'),
            ),
            ListTile(
              leading: Icon(Icons.photo_library_outlined, color: AppColors.primaryColor),
              title: Text('Choisir une photo'),
              onTap: () => Navigator.of(ctx).pop('galerie'),
            ),
            SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    File? fichier;
    String nomFichier = '';
    try {
      if (source == 'fichier') {
        final choisi = await FilePicker.pickFile(
          type: FileType.custom,
          allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        );
        if (choisi == null) return;
        nomFichier = choisi.name;
        if (choisi.path != null) {
          fichier = File(choisi.path!);
        } else {
          // Fichier non local (ex. fournisseur de contenu) : copie temporaire.
          final dir = await getTemporaryDirectory();
          fichier = File('${dir.path}/${DateTime.now().millisecondsSinceEpoch}_${choisi.name}');
          await fichier.writeAsBytes(await choisi.readAsBytes());
        }
      } else {
        final photo = await ImagePicker().pickImage(
          source: source == 'camera' ? ImageSource.camera : ImageSource.gallery,
          imageQuality: 85,
        );
        if (photo == null) return;
        fichier = File(photo.path);
        nomFichier = photo.name;
      }
    } catch (_) {
      if (mounted) showToast("Impossible de récupérer le fichier", context, type: ToastificationType.error);
      return;
    }
    if (!mounted) return;

    final extension = nomFichier.split('.').last.toLowerCase();
    if (!['pdf', 'jpg', 'jpeg', 'png'].contains(extension)) {
      showToast("Format non accepté", context,
          description: "Formats acceptés : PDF, JPG, PNG.", type: ToastificationType.error);
      return;
    }
    final taille = await fichier.length();
    if (!mounted) return;
    if (taille > _tailleMaxContrat) {
      showToast("Fichier trop volumineux", context,
          description: "La taille maximale est de 15 Mo.", type: ToastificationType.error);
      return;
    }

    final formulaire = await FormulaireContratDialog.afficher(
      context,
      nomFichier: nomFichier,
      tailleOctets: taille,
      bien: bien?.title,
    );
    if (formulaire == null) return;

    await cubit.ajouterContrat(
      fichier,
      bienId: bien?.id,
      titre: formulaire.titre,
      dateDebut: formulaire.dateDebut,
      dateFin: formulaire.dateFin,
    );
  }
}
