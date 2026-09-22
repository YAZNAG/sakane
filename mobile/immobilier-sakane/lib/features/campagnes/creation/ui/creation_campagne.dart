import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:immobilier/components/error_widget.dart';
import 'package:immobilier/components/loading_indicator.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/core/constants/app_strings.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/utils/show_toast.dart';
import 'package:immobilier/features/campagnes/commun/campagne_ui.dart';
import 'package:immobilier/features/campagnes/creation/cubit/creation_campagne_cubit.dart';
import 'package:immobilier/models/campagne.dart';
import 'package:toastification/toastification.dart';
import 'package:immobilier/features/campagnes/creation/ui/components/choix_clients.dart';

/// Rédaction d'une campagne en trois étapes : le message, les
/// destinataires, puis l'envoi (immédiat, programmé ou brouillon).
class CreationCampagnePage extends StatefulWidget {
  const CreationCampagnePage({super.key});

  static Widget page() => BlocProvider(
        create: (_) => CreationCampagneCubit()..charger(),
        child: const CreationCampagnePage(),
      );

  @override
  State<CreationCampagnePage> createState() => _CreationCampagnePageState();
}

enum _ModeEnvoi { maintenant, programmer, brouillon }

class _CreationCampagnePageState extends State<CreationCampagnePage> {
  static const _etapes = ["Message", "Destinataires", "Envoi"];

  /// Valeurs d'exemple montrees dans l'apercu.
  static const _exemples = {
    '{client_name}': 'Karim Benali',
    '{client_first_name}': 'Karim',
    '{client_last_name}': 'Benali',
  };

  final _formKey = GlobalKey<FormState>();
  final _titre = TextEditingController();
  final _message = TextEditingController();
  final _lien = TextEditingController();
  final _messageFocus = FocusNode();

  int _etape = 0;
  _ModeEnvoi _mode = _ModeEnvoi.maintenant;
  DateTime? _planifiee;

  @override
  void dispose() {
    _titre.dispose();
    _message.dispose();
    _lien.dispose();
    _messageFocus.dispose();
    super.dispose();
  }

  Color get _primaire => AppColors.primaryColor;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CampagneUi.fond,
      appBar: AppBar(
        title: const Text('Nouvelle campagne'),
        centerTitle: true,
      ),
      body: BlocConsumer<CreationCampagneCubit, CreationCampagneState>(
        listener: _reagir,
        builder: (context, state) {
          if (state.fetchStatus == AppStatus.loading) {
            return Center(child: MyLoadingIndicator());
          }
          if (state.fetchStatus == AppStatus.error) {
            return MyErrorWidget(
              error: state.error ?? "Erreur",
              action: AppStrings.tryAgain,
              actionCLick: () => context.read<CreationCampagneCubit>().charger(),
            );
          }
          return Column(
            children: [
              _indicateurEtapes(),
              Expanded(
                child: Form(
                  key: _formKey,
                  // Les trois etapes restent montees : la saisie est conservee
                  // et la validation finale couvre aussi l'etape 1.
                  child: IndexedStack(
                    index: _etape,
                    children: [
                      _etapeMessage(context, state),
                      _etapeDestinataires(context, state),
                      _etapeEnvoi(context, state),
                    ],
                  ),
                ),
              ),
              _barreBas(context, state),
            ],
          );
        },
      ),
    );
  }

  void _reagir(BuildContext context, CreationCampagneState state) {
    if (state.testStatus == AppStatus.success) {
      showToast("Message test envoyé", context,
          description: "Vérifiez votre WhatsApp.", second: 3);
    } else if (state.testStatus == AppStatus.error) {
      showToast("", context,
          description: state.error ?? "L'envoi test n'a pas abouti",
          type: ToastificationType.error,
          second: 4);
    }

    if (state.saveStatus == AppStatus.success) {
      showToast(
          switch (_mode) {
            _ModeEnvoi.maintenant => "Campagne lancée",
            _ModeEnvoi.programmer => "Campagne programmée",
            _ModeEnvoi.brouillon => "Brouillon enregistré",
          },
          context,
          second: 2);
      GoRouter.of(context).pop(true);
    } else if (state.saveStatus == AppStatus.error) {
      showToast("", context,
          description: state.error ?? "Enregistrement impossible",
          type: ToastificationType.error,
          second: 4);
    }
  }

  // ---------------------------------------------------------------
  // Navigation entre etapes
  // ---------------------------------------------------------------

  Widget _indicateurEtapes() {
    // Ecran etroit : seul le libelle de l'etape en cours reste affiche.
    final etroit = MediaQuery.sizeOf(context).width < 360;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          for (var i = 0; i < _etapes.length; i++) ...[
            if (i > 0)
              Expanded(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  color: i <= _etape ? _primaire : CampagneUi.bordure,
                ),
              ),
            InkWell(
              borderRadius: BorderRadius.circular(20),
              // Retour libre en arriere, avance via le bouton "Suivant".
              onTap: i < _etape ? () => setState(() => _etape = i) : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i <= _etape ? _primaire : Colors.white,
                        border: Border.all(
                            color: i <= _etape ? _primaire : CampagneUi.bordure,
                            width: 1.5),
                      ),
                      child: i < _etape
                          ? const Icon(Icons.check_rounded,
                              size: 16, color: Colors.white)
                          : Text("${i + 1}",
                              style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: i == _etape
                                      ? Colors.white
                                      : CampagneUi.gris)),
                    ),
                    if (!etroit || i == _etape) ...[
                      const SizedBox(width: 6),
                      Text(_etapes[i],
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight:
                                i == _etape ? FontWeight.bold : FontWeight.w500,
                            color: i == _etape
                                ? CampagneUi.texte
                                : CampagneUi.gris)),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _barreBas(BuildContext context, CreationCampagneState state) {
    final enregistrement = state.saveStatus == AppStatus.loading;
    final derniere = _etape == _etapes.length - 1;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: CampagneUi.bordure)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (_etape > 0) ...[
              SizedBox(
                height: 50,
                child: OutlinedButton(
                  onPressed: enregistrement
                      ? null
                      : () => setState(() => _etape -= 1),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: CampagneUi.texte,
                    side: const BorderSide(color: CampagneUi.bordure),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text("Retour"),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: SizedBox(
                height: 50,
                child: derniere
                    ? _boutonFinal(context, state, enregistrement)
                    : ElevatedButton.icon(
                        onPressed: () => _suivant(context, state),
                        icon: const Icon(Icons.arrow_forward_rounded),
                        label: const Text("Suivant",
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.bold)),
                        style: _styleBouton(_primaire),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  ButtonStyle _styleBouton(Color couleur) => ElevatedButton.styleFrom(
        backgroundColor: couleur,
        foregroundColor: Colors.white,
        disabledBackgroundColor: couleur.withValues(alpha: .45),
        disabledForegroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      );

  void _suivant(BuildContext context, CreationCampagneState state) {
    FocusScope.of(context).unfocus();
    if (_etape == 0 && !(_formKey.currentState?.validate() ?? false)) return;
    if (_etape == 1 &&
        state.estimationStatus != AppStatus.loading &&
        (state.estimation?.nombre ?? 0) == 0) {
      showToast("", context,
          description: "Aucun client ne correspond à cette sélection.",
          type: ToastificationType.warning,
          second: 3);
      return;
    }
    setState(() => _etape += 1);
  }

  // ---------------------------------------------------------------
  // Etape 1 : message
  // ---------------------------------------------------------------

  Widget _etapeMessage(BuildContext context, CreationCampagneState state) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
      children: [
        _carte(
          titre: "Contenu",
          icone: Icons.edit_note_rounded,
          enfants: [
            TextFormField(
              controller: _titre,
              textInputAction: TextInputAction.next,
              decoration: _deco(
                "Titre de la campagne",
                aide: "Sert uniquement à retrouver la campagne dans l'historique.",
              ),
              validator: (v) => (v == null || v.trim().length < 3)
                  ? "Donnez un titre à la campagne"
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _message,
              focusNode: _messageFocus,
              minLines: 4,
              maxLines: 8,
              maxLength: 4000,
              onChanged: (_) => setState(() {}),
              decoration: _deco("Texte du message"),
              validator: (v) => (v == null || v.trim().length < 5)
                  ? "Rédigez le message à envoyer"
                  : null,
            ),
            _variables(),
          ],
        ),
        const SizedBox(height: 12),
        _carte(
          titre: "Image et lien",
          icone: Icons.attach_file_rounded,
          sousTitre: "Facultatifs",
          enfants: [
            _image(context, state),
            const SizedBox(height: 14),
            TextFormField(
              controller: _lien,
              keyboardType: TextInputType.url,
              textDirection: TextDirection.ltr,
              onChanged: (_) => setState(() {}),
              decoration: _deco("Lien", aide: CampagneUi.lienAide)
                  .copyWith(prefixIcon: const Icon(Icons.link_rounded)),
              validator: CampagneUi.validerLien,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _carte(
          titre: "Aperçu",
          icone: Icons.visibility_outlined,
          sousTitre: "Avec des valeurs d'exemple",
          enfants: [_apercu(state)],
        ),
      ],
    );
  }

  Widget _variables() {
    const variables = {
      '{client_name}': 'Nom complet',
      '{client_first_name}': 'Prénom',
      '{client_last_name}': 'Nom de famille',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Personnaliser : appuyez pour insérer",
          style: TextStyle(fontSize: 12, color: CampagneUi.gris),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: variables.entries
              .map((v) => ActionChip(
                    avatar: Icon(Icons.add_rounded, size: 16, color: _primaire),
                    label: Text(v.value,
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: _primaire)),
                    tooltip: v.key,
                    onPressed: () => _inserer(v.key),
                    backgroundColor: _primaire.withValues(alpha: .07),
                    side: BorderSide(color: _primaire.withValues(alpha: .25)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  ))
              .toList(),
        ),
      ],
    );
  }

  /// Insère la variable à l'endroit du curseur, pas en fin de texte.
  void _inserer(String variable) {
    final texte = _message.text;
    final selection = _message.selection;
    final position =
        selection.start >= 0 ? selection.start : texte.length;

    final nouveau =
        texte.replaceRange(position, selection.end >= 0 ? selection.end : position, variable);

    _message.value = TextEditingValue(
      text: nouveau,
      selection: TextSelection.collapsed(offset: position + variable.length),
    );
    _messageFocus.requestFocus();
    setState(() {});
  }

  /// Bulle facon WhatsApp, mise a jour a chaque frappe.
  Widget _apercu(CreationCampagneState state) {
    var texte = _message.text.trim();
    _exemples.forEach((cle, valeur) => texte = texte.replaceAll(cle, valeur));
    final lien = _lien.text.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFECE5DD),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Align(
        alignment: AlignmentDirectional.centerEnd,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 300),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: CampagneUi.bulle,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (state.image != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(state.image!,
                      height: 150, width: double.infinity, fit: BoxFit.cover),
                ),
                const SizedBox(height: 6),
              ],
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  texte.isEmpty ? "Votre message apparaîtra ici…" : texte,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: texte.isEmpty ? CampagneUi.grisClair : CampagneUi.texte,
                    fontStyle: texte.isEmpty ? FontStyle.italic : null,
                  ),
                ),
              ),
              if (lien.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
                  child: Text(lien,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(
                          fontSize: 13.5,
                          color: Color(0xFF027EB5),
                          decoration: TextDecoration.underline)),
                ),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4, right: 2, left: 2),
                  child: Text(CampagneUi.heure(DateTime.now()),
                      style: const TextStyle(
                          fontSize: 10.5, color: CampagneUi.gris)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _image(BuildContext context, CreationCampagneState state) {
    final cubit = context.read<CreationCampagneCubit>();

    if (state.image != null) {
      return Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.file(state.image!,
                width: 64, height: 64, fit: BoxFit.cover),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text("Image jointe au message",
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: CampagneUi.texte)),
          ),
          IconButton(
            onPressed: () => _choisirImage(context),
            icon: const Icon(Icons.swap_horiz_rounded),
            tooltip: "Remplacer",
          ),
          IconButton(
            onPressed: () => cubit.choisirImage(null),
            icon: const Icon(Icons.delete_outline, color: CampagneUi.rouge),
            tooltip: "Retirer",
          ),
        ],
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: () => _choisirImage(context),
        icon: const Icon(Icons.add_photo_alternate_outlined, size: 20),
        label: const Text("Ajouter une image"),
        style: OutlinedButton.styleFrom(
          foregroundColor: CampagneUi.texte,
          side: const BorderSide(color: CampagneUi.bordure),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  void _choisirImage(BuildContext context) async {
    final cubit = context.read<CreationCampagneCubit>();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text("Prendre une photo"),
                onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text("Choisir dans la galerie"),
                onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
    if (source == null) return;

    final fichier = await ImagePicker()
        .pickImage(source: source, imageQuality: 82, maxWidth: 1280);
    if (fichier != null) cubit.choisirImage(File(fichier.path));
  }

  // ---------------------------------------------------------------
  // Etape 2 : destinataires
  // ---------------------------------------------------------------

  Widget _etapeDestinataires(BuildContext context, CreationCampagneState state) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
      children: [
        _carte(
          titre: "Qui reçoit le message ?",
          icone: Icons.groups_outlined,
          enfants: [_choixSegment(context, state)],
        ),
        const SizedBox(height: 12),
        _estimation(context, state),
      ],
    );
  }

  static IconData _iconeSegment(String? code) {
    switch (code) {
      case 'tous':
        return Icons.groups_rounded;
      case 'avec_reservation':
        return Icons.event_available_rounded;
      case 'sans_reservation':
        return Icons.event_busy_rounded;
      case 'par_bien':
        return Icons.apartment_rounded;
      case 'par_periode':
        return Icons.date_range_rounded;
      case 'en_sejour':
        return Icons.hotel_rounded;
      case 'selection':
        return Icons.checklist_rounded;
      default:
        return Icons.people_outline;
    }
  }

  Widget _choixSegment(BuildContext context, CreationCampagneState state) {
    final cubit = context.read<CreationCampagneCubit>();
    final segments = state.segments ?? [];
    final segment = state.segment;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final s in segments) ...[
          _optionSegment(
            code: s["code"],
            libelle: s["name"] ?? '',
            choisi: segment.type == s["code"],
            onTap: () {
              final v = s["code"];
              if (v == null || v == segment.type) return;
              cubit.majSegment(SegmentClients(
                type: v,
                realestateId: segment.realestateId,
                du: segment.du,
                au: segment.au,
              ));
            },
          ),
          if (segment.type == s["code"]) _detailSegment(context, state),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _optionSegment({
    required String? code,
    required String libelle,
    required bool choisi,
    required VoidCallback onTap,
  }) {
    return Material(
      color: choisi ? _primaire.withValues(alpha: .07) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: choisi ? _primaire : CampagneUi.bordure,
                width: choisi ? 1.6 : 1),
          ),
          child: Row(
            children: [
              Icon(_iconeSegment(code),
                  size: 21, color: choisi ? _primaire : CampagneUi.gris),
              const SizedBox(width: 12),
              Expanded(
                child: Text(libelle,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: choisi ? FontWeight.bold : FontWeight.w500,
                        color: CampagneUi.texte)),
              ),
              Icon(
                choisi
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                size: 21,
                color: choisi ? _primaire : CampagneUi.grisClair,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Precisions demandees par certains segments (bien, periode, liste).
  Widget _detailSegment(BuildContext context, CreationCampagneState state) {
    final cubit = context.read<CreationCampagneCubit>();
    final segment = state.segment;

    Widget contenu;
    switch (segment.type) {
      case 'par_bien':
        contenu = DropdownButtonFormField<int>(
          initialValue: segment.realestateId,
          isExpanded: true,
          decoration: _deco("Bien concerné"),
          items: (state.biens ?? [])
              .map((b) => DropdownMenuItem(
                    value: b.id,
                    child: Text(b.title ?? '',
                        style: const TextStyle(fontSize: 13.5)),
                  ))
              .toList(),
          onChanged: (v) => cubit.majSegment(
              SegmentClients(type: 'par_bien', realestateId: v)),
        );
      case 'par_periode':
        contenu = Row(
          children: [
            Expanded(
              child: _champDate(
                context,
                "Du",
                segment.du,
                (d) => cubit.majSegment(SegmentClients(
                    type: 'par_periode', du: d, au: segment.au)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _champDate(
                context,
                "Au",
                segment.au,
                (d) => cubit.majSegment(SegmentClients(
                    type: 'par_periode', du: segment.du, au: d)),
              ),
            ),
          ],
        );
      case 'selection':
        contenu = _selectionManuelle(context, state);
      default:
        return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(8, 10, 0, 2),
      child: contenu,
    );
  }

  /// Bouton d'ouverture de la liste des clients, et rappel de ce qui a
  /// deja ete retenu.
  Widget _selectionManuelle(BuildContext context, CreationCampagneState state) {
    final cubit = context.read<CreationCampagneCubit>();
    final choisis = state.segment.clients;
    final clients = state.clients ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: clients.isEmpty
                ? null
                : () async {
                    final retenus = await ChoixClients.ouvrir(
                      context,
                      clients: clients,
                      selection: choisis,
                    );
                    if (retenus == null) return;
                    cubit.majSegment(SegmentClients(
                      type: 'selection',
                      clients: retenus,
                    ));
                  },
            icon: const Icon(Icons.people_alt_outlined, size: 19),
            label: Text(
              choisis.isEmpty
                  ? "Choisir les clients"
                  : "Modifier la sélection (${choisis.length})",
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: _primaire),
              foregroundColor: _primaire,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        if (choisis.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              clients.isEmpty
                  ? "Aucun client enregistré."
                  : "Aucun client choisi pour l'instant.",
              style: const TextStyle(fontSize: 12, color: CampagneUi.gris),
            ),
          ),
      ],
    );
  }

  Widget _estimation(BuildContext context, CreationCampagneState state) {
    final cubit = context.read<CreationCampagneCubit>();
    final chargement = state.estimationStatus == AppStatus.loading;
    final e = state.estimation;
    final aucun = e != null && e.nombre == 0;
    final couleur = aucun ? CampagneUi.rouge : CampagneUi.vert;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: CampagneUi.carte(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: (e == null ? CampagneUi.ardoise : couleur)
                      .withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: chargement
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.2))
                    : Icon(aucun ? Icons.person_off_outlined : Icons.group_rounded,
                        color: e == null ? CampagneUi.ardoise : couleur),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      chargement
                          ? "Calcul en cours…"
                          : e == null
                              ? "Nombre de destinataires"
                              : aucun
                                  ? "Aucun destinataire"
                                  : CampagneUi.pluriel(e.nombre, 'destinataire'),
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: CampagneUi.texte),
                    ),
                    if (!chargement && e != null && !aucun)
                      Text(
                        "≈ ${CampagneUi.duree((e.nombre / 2).ceil())} d'envoi, 2 messages par minute",
                        style: const TextStyle(
                            fontSize: 12.5, color: CampagneUi.gris),
                      ),
                    if (!chargement && state.estimationStatus == AppStatus.error)
                      const Text("L'estimation n'a pas abouti.",
                          style: TextStyle(
                              fontSize: 12.5, color: CampagneUi.rouge)),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: chargement ? null : cubit.estimer,
                icon: const Icon(Icons.calculate_outlined, size: 18),
                label: const Text("Estimer"),
              ),
            ],
          ),
          if (!chargement && e != null) ...[
            if (aucun)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text("Aucun client ne correspond à cette sélection.",
                    style: TextStyle(fontSize: 13, color: CampagneUi.rouge)),
              ),
            if (e.exemples.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text("Exemples",
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: CampagneUi.gris)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: e.exemples
                    .take(5)
                    .map((n) => Chip(
                          label: Text(n, style: const TextStyle(fontSize: 12)),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: CampagneUi.fond,
                          side: const BorderSide(color: CampagneUi.bordure),
                        ))
                    .toList(),
              ),
            ],
            if (e.exclus > 0)
              _note(
                Icons.do_not_disturb_on_outlined,
                "${CampagneUi.pluriel(e.exclus, 'client')} "
                "exclu${e.exclus > 1 ? 's' : ''} : refus des messages promotionnels.",
                CampagneUi.orange,
              ),
          ],
          _note(
            Icons.info_outline_rounded,
            "Un même numéro ne reçoit le message qu'une seule fois, même s'il "
            "apparaît plusieurs fois.",
            CampagneUi.gris,
          ),
        ],
      ),
    );
  }

  Widget _note(IconData icone, String texte, Color couleur) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icone, size: 16, color: couleur),
            const SizedBox(width: 8),
            Expanded(
              child: Text(texte,
                  style: TextStyle(fontSize: 12.5, height: 1.35, color: couleur)),
            ),
          ],
        ),
      );

  // ---------------------------------------------------------------
  // Etape 3 : envoi
  // ---------------------------------------------------------------

  Widget _etapeEnvoi(BuildContext context, CreationCampagneState state) {
    final n = state.estimation?.nombre ?? 0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
      children: [
        _recap(state),
        const SizedBox(height: 12),
        _carte(
          titre: "Quand envoyer ?",
          icone: Icons.schedule_send_outlined,
          enfants: [
            _optionEnvoi(_ModeEnvoi.maintenant, Icons.send_rounded,
                "Maintenant", "L'envoi démarre dès l'enregistrement."),
            const SizedBox(height: 8),
            _optionEnvoi(_ModeEnvoi.programmer, Icons.event_rounded,
                "Programmer à une date", "L'envoi démarrera tout seul."),
            if (_mode == _ModeEnvoi.programmer) _choixDate(context),
            const SizedBox(height: 8),
            _optionEnvoi(_ModeEnvoi.brouillon, Icons.drafts_outlined,
                "Enregistrer en brouillon", "À lancer plus tard, depuis l'historique."),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _primaire.withValues(alpha: .06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _primaire.withValues(alpha: .25)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.speed_rounded, size: 20, color: _primaire),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  n > 0
                      ? "Envoi automatique : 2 messages par minute, "
                          "≈ ${CampagneUi.duree((n / 2).ceil())} pour "
                          "${CampagneUi.pluriel(n, 'destinataire')}, dans l'ordre de la liste."
                      : "Envoi automatique : 2 messages par minute, dans l'ordre de la liste.",
                  style: const TextStyle(
                      fontSize: 13, height: 1.4, color: CampagneUi.texte),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _boutonTest(context, state),
      ],
    );
  }

  Widget _recap(CreationCampagneState state) {
    final n = state.estimation?.nombre ?? 0;
    final segment = (state.segments ?? []).firstWhere(
        (s) => s["code"] == state.segment.type,
        orElse: () => const {});

    Widget ligne(IconData icone, String texte) => Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            children: [
              Icon(icone, size: 16, color: CampagneUi.gris),
              const SizedBox(width: 8),
              Expanded(
                child: Text(texte,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, color: CampagneUi.texte)),
              ),
            ],
          ),
        );

    return _carte(
      titre: "Récapitulatif",
      icone: Icons.fact_check_outlined,
      enfants: [
        Text(_titre.text.trim().isEmpty ? "Sans titre" : _titre.text.trim(),
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: CampagneUi.texte)),
        ligne(Icons.groups_outlined,
            "${CampagneUi.pluriel(n, 'destinataire')} · ${segment["name"] ?? state.segment.type}"),
        if (state.image != null) ligne(Icons.image_outlined, "Avec une image"),
        if (_lien.text.trim().isNotEmpty)
          ligne(Icons.link_rounded, _lien.text.trim()),
      ],
    );
  }

  Widget _optionEnvoi(
      _ModeEnvoi mode, IconData icone, String titre, String detail) {
    final choisi = _mode == mode;
    return Material(
      color: choisi ? _primaire.withValues(alpha: .07) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          setState(() => _mode = mode);
          if (mode == _ModeEnvoi.programmer && _planifiee == null) {
            _choisirDateHeure(context);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: choisi ? _primaire : CampagneUi.bordure,
                width: choisi ? 1.6 : 1),
          ),
          child: Row(
            children: [
              Icon(icone, size: 22, color: choisi ? _primaire : CampagneUi.gris),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titre,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight:
                                choisi ? FontWeight.bold : FontWeight.w600,
                            color: CampagneUi.texte)),
                    Text(detail,
                        style: const TextStyle(
                            fontSize: 12, color: CampagneUi.gris)),
                  ],
                ),
              ),
              Icon(
                choisi
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                size: 21,
                color: choisi ? _primaire : CampagneUi.grisClair,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _choixDate(BuildContext context) {
    final date = _planifiee;
    final passee = date != null && date.isBefore(DateTime.now());
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(8, 10, 0, 0),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _choisirDateHeure(context),
        child: InputDecorator(
          decoration: _deco("Date et heure d'envoi").copyWith(
            prefixIcon: const Icon(Icons.event_rounded),
            suffixIcon: const Icon(Icons.edit_calendar_outlined),
            errorText: passee ? "Choisissez une date à venir" : null,
          ),
          child: Text(
            date == null ? "Choisir…" : CampagneUi.dateHeure(date),
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: date == null ? CampagneUi.gris : CampagneUi.texte),
          ),
        ),
      ),
    );
  }

  void _choisirDateHeure(BuildContext context) async {
    final maintenant = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _planifiee ?? maintenant.add(const Duration(hours: 1)),
      firstDate: maintenant,
      lastDate: maintenant.add(const Duration(days: 365)),
    );
    if (date == null || !context.mounted) return;

    final heure = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
          _planifiee ?? maintenant.add(const Duration(hours: 1))),
    );
    if (heure == null) return;

    setState(() {
      _planifiee =
          DateTime(date.year, date.month, date.day, heure.hour, heure.minute);
    });
  }

  Widget _boutonTest(BuildContext context, CreationCampagneState state) {
    final enCours = state.testStatus == AppStatus.loading;

    return SizedBox(
      height: 48,
      child: OutlinedButton.icon(
        onPressed: enCours ? null : () => _demanderNumeroTest(context),
        icon: enCours
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.science_outlined, size: 19),
        label: Text(enCours ? "Envoi…" : "Envoi test vers un numéro"),
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          side: BorderSide(color: _primaire.withValues(alpha: .6)),
          foregroundColor: _primaire,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  void _demanderNumeroTest(BuildContext context) async {
    if (_message.text.trim().length < 5) {
      showToast("Rédigez d'abord le message", context,
          type: ToastificationType.warning, second: 2);
      return;
    }

    final cubit = context.read<CreationCampagneCubit>();
    final numero = await demanderNumeroTest(context);
    if (numero != null) {
      cubit.envoyerTest(
        telephone: numero,
        message: _message.text.trim(),
        lien: _lien.text.trim().isEmpty ? null : _lien.text.trim(),
      );
    }
  }

  Widget _boutonFinal(
      BuildContext context, CreationCampagneState state, bool enCours) {
    final possible = (state.estimation?.nombre ?? 0) > 0;
    final (libelle, icone) = switch (_mode) {
      _ModeEnvoi.maintenant => ("Lancer l'envoi", Icons.send_rounded),
      _ModeEnvoi.programmer => ("Programmer l'envoi", Icons.schedule_send_rounded),
      _ModeEnvoi.brouillon => ("Enregistrer le brouillon", Icons.save_outlined),
    };

    return ElevatedButton.icon(
      onPressed: enCours || !possible ? null : () => _enregistrer(context, state),
      icon: enCours
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : Icon(icone, size: 20),
      label: Text(libelle,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
      style: _styleBouton(_primaire),
    );
  }

  void _enregistrer(BuildContext context, CreationCampagneState state) async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      // Le message est incomplet : retour a la premiere etape.
      setState(() => _etape = 0);
      return;
    }

    final cubit = context.read<CreationCampagneCubit>();

    if (_mode == _ModeEnvoi.programmer) {
      if (_planifiee == null || _planifiee!.isBefore(DateTime.now())) {
        showToast("", context,
            description: "Choisissez une date et une heure à venir.",
            type: ToastificationType.warning,
            second: 3);
        if (_planifiee == null) _choisirDateHeure(context);
        return;
      }
    }

    if (_mode == _ModeEnvoi.maintenant) {
      final n = state.estimation?.nombre ?? 0;
      final ok = await confirmerCampagne(
        context,
        titre: "Lancer l'envoi maintenant ?",
        message: "${CampagneUi.pluriel(n, 'message')} vont partir "
            "automatiquement, 2 par minute, dans l'ordre de la liste "
            "(≈ ${CampagneUi.duree((n / 2).ceil())}). Vous pourrez mettre "
            "en pause à tout moment.",
        confirmer: "Lancer",
        icone: Icons.send_rounded,
        couleur: _primaire,
      );
      if (!ok) return;
    }

    cubit.enregistrer(
      titre: _titre.text.trim(),
      message: _message.text.trim(),
      lien: _lien.text.trim().isEmpty ? null : _lien.text.trim(),
      quand: _mode == _ModeEnvoi.programmer ? _planifiee : null,
      maintenant: _mode == _ModeEnvoi.maintenant,
    );
  }

  // ---------------------------------------------------------------
  // Éléments communs
  // ---------------------------------------------------------------

  Widget _carte({
    required String titre,
    required IconData icone,
    String? sousTitre,
    required List<Widget> enfants,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: CampagneUi.carte(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _primaire.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icone, size: 19, color: _primaire),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(titre,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: CampagneUi.texte)),
              ),
              if (sousTitre != null)
                Text(sousTitre,
                    style: const TextStyle(
                        fontSize: 12, color: CampagneUi.gris)),
            ],
          ),
          const SizedBox(height: 14),
          ...enfants,
        ],
      ),
    );
  }

  InputDecoration _deco(String label, {String? aide}) => InputDecoration(
        labelText: label,
        helperText: aide,
        helperMaxLines: 2,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: CampagneUi.bordure),
        ),
      );

  Widget _champDate(BuildContext context, String label, DateTime? valeur,
      void Function(DateTime) onChoix) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: valeur ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (d != null) onChoix(d);
      },
      child: InputDecorator(
        decoration: _deco(label),
        child: Text(
          valeur == null
              ? "—"
              : "${CampagneUi.deux(valeur.day)}/"
                  "${CampagneUi.deux(valeur.month)}/${valeur.year}",
          style: const TextStyle(fontSize: 13.5),
        ),
      ),
    );
  }
}
