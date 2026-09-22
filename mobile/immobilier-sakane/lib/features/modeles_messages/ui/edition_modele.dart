import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/utils/droits.dart';
import 'package:immobilier/core/utils/show_dialogue_question.dart';
import 'package:immobilier/core/utils/show_toast.dart';
import 'package:immobilier/features/modeles_messages/cubit/modeles_messages_cubit.dart';
import 'package:immobilier/models/modele_message.dart';
import 'package:toastification/toastification.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

/// Modification d'un message automatique : texte, variables, aperçu,
/// retour au modèle d'origine et historique des changements.
class EditionModelePage extends StatefulWidget {
  final ModeleMessage modele;

  const EditionModelePage({super.key, required this.modele});

  @override
  State<EditionModelePage> createState() => _EditionModelePageState();
}

class _EditionModelePageState extends State<EditionModelePage> {
  /// Droit « Modifier les modèles » : sans lui, la page est en lecture seule.
  final bool _modifiable = peut(AppPermission.updateMessageTemplates);
  late final TextEditingController _contenu;
  final _focus = FocusNode();
  late bool _actif;
  bool _modifie = false;

  @override
  void initState() {
    super.initState();
    _contenu = TextEditingController(text: widget.modele.contenu ?? '');
    _actif = widget.modele.actif;
    _contenu.addListener(() {
      final change = _contenu.text != (widget.modele.contenu ?? '');
      if (change != _modifie) setState(() => _modifie = change);
    });
  }

  @override
  void dispose() {
    _contenu.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(widget.modele.nom ?? 'Modèle'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () => _voirHistorique(context),
            icon: const Icon(Icons.history),
            tooltip: "Historique des modifications",
          ),
        ],
      ),
      body: BlocConsumer<ModelesMessagesCubit, ModelesMessagesState>(
        listener: (context, state) {
          if (state.saveStatus == AppStatus.success) {
            showToast(state.message ?? "Enregistré", context, second: 2);
            final maj = state.courant;
            if (maj != null && maj.id == widget.modele.id) {
              _contenu.text = maj.contenu ?? '';
              setState(() {
                _actif = maj.actif;
                _modifie = false;
              });
            }
          } else if (state.saveStatus == AppStatus.error) {
            showToast("", context,
                description: state.error ?? "Enregistrement impossible",
                type: ToastificationType.error,
                second: 4);
          }
          if (state.apercuStatus == AppStatus.error) {
            showToast("", context,
                description: state.error ?? "Aperçu indisponible",
                type: ToastificationType.error,
                second: 3);
          }
        },
        builder: (context, state) {
          final enCours = state.saveStatus == AppStatus.loading;

          return ListView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 30),
            children: [
              if (!_modifiable)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.lock_outline, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Lecture seule : vous n'avez pas le droit de modifier les modèles.",
                          style: TextStyle(fontSize: 12.5),
                        ),
                      ),
                    ],
                  ),
                ),
              if (widget.modele.description != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    widget.modele.description!,
                    style:
                        TextStyle(fontSize: 12.5, color: Colors.black87),
                  ),
                ),

              TextField(
                controller: _contenu,
                focusNode: _focus,
                readOnly: !_modifiable,
                maxLines: 12,
                minLines: 6,
                maxLength: 4000,
                style: const TextStyle(fontSize: 13.5, height: 1.4, color: Colors.black87),
                decoration: InputDecoration(
                  labelText: "Texte du message",
                  alignLabelWithHint: true,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(9)),
                ),
              ),

              _variables(context, state),

              const SizedBox(height: 8),
              SwitchListTile(
                value: _actif,
                onChanged: !_modifiable ? null : (v) => setState(() {
                  _actif = v;
                  _modifie = true;
                }),
                contentPadding: EdgeInsets.zero,
                title: const Text("Message actif",
                    style: TextStyle(fontSize: 13.5)),
                subtitle: Text(
                  _actif
                      ? "Ce message est envoyé automatiquement."
                      : "Le message d'origine sera utilisé à la place.",
                  style: TextStyle(fontSize: 11.5, color: Colors.black87),
                ),
              ),

              const SizedBox(height: 14),
              _imageDuModele(context, state),

              const SizedBox(height: 10),
              _boutonApercu(context, state),
              _apercu(state),

              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: enCours || !_modifie || !_modifiable ? null : () => _enregistrer(context),
                  icon: enCours
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_outlined, size: 19),
                  label: const Text("Enregistrer",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),

              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: enCours || !_modifiable ? null : () => _restaurer(context),
                  icon: const Icon(Icons.restore, size: 18),
                  label: const Text("Rétablir le texte d'origine"),
                  style: TextButton.styleFrom(
                      foregroundColor: Colors.blueGrey.shade700),
                ),
              ),

              if (widget.modele.defaut != null) _texteOrigine(),
            ],
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------

  Widget _variables(BuildContext context, ModelesMessagesState state) {
    // Les variables propres au modèle passent en premier ; les autres
    // restent accessibles car un message peut évoluer.
    final propres = widget.modele.variables;
    final toutes = state.variables ?? [];
    final ordonnees = [
      ...toutes.where((v) => propres.contains(v.variable)),
      ...toutes.where((v) => !propres.contains(v.variable)),
    ];
    if (ordonnees.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Appuyez pour insérer une variable :",
          style: TextStyle(fontSize: 12, color: Colors.black87),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: ordonnees.map((v) {
            final propre = propres.contains(v.variable);
            return ActionChip(
              // Sans couleur, le texte de la pastille prenait celle du
              // theme et devenait illisible sur fond blanc.
              label: Text(v.variable,
                  style: const TextStyle(fontSize: 11.5, color: Colors.black87)),
              tooltip: v.libelle ?? v.exemple,
              onPressed: !_modifiable ? null : () => _inserer(v.variable),
              backgroundColor: propre ? Colors.white : Colors.grey.shade100,
              side: BorderSide(
                color: propre
                    ? AppColors.primaryColor.withValues(alpha: 0.5)
                    : Colors.grey.shade300,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  /// Insère la variable à l'endroit du curseur.
  void _inserer(String variable) {
    final texte = _contenu.text;
    final selection = _contenu.selection;
    final debut = selection.start >= 0 ? selection.start : texte.length;
    final fin = selection.end >= 0 ? selection.end : debut;

    _contenu.value = TextEditingValue(
      text: texte.replaceRange(debut, fin, variable),
      selection: TextSelection.collapsed(offset: debut + variable.length),
    );
    _focus.requestFocus();
  }

  /// Image jointe au message. Elle accompagne le texte a l'envoi.
  Widget _imageDuModele(BuildContext context, ModelesMessagesState state) {
    final courant = state.courant?.id == widget.modele.id
        ? state.courant
        : widget.modele;
    final image = courant?.image;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Image jointe",
          style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Colors.black87),
        ),
        const SizedBox(height: 7),
        if (image != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              image,
              height: 150,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 80,
                color: Colors.grey.shade200,
                alignment: Alignment.center,
                child: const Text("Image indisponible",
                    style: TextStyle(fontSize: 12)),
              ),
            ),
          ),
          Row(
            children: [
              TextButton.icon(
                onPressed: !_modifiable ? null : () => _choisirImage(context),
                icon: const Icon(Icons.swap_horiz, size: 17),
                label: const Text("Remplacer", style: TextStyle(fontSize: 12.5)),
              ),
              TextButton.icon(
                onPressed: !_modifiable ? null : () {
                  if (widget.modele.id != null) {
                    context
                        .read<ModelesMessagesCubit>()
                        .retirerImage(widget.modele.id!);
                  }
                },
                icon: const Icon(Icons.delete_outline, size: 17),
                label: const Text("Retirer", style: TextStyle(fontSize: 12.5)),
                style:
                    TextButton.styleFrom(foregroundColor: Colors.red.shade700),
              ),
            ],
          ),
        ] else
          OutlinedButton.icon(
            onPressed: !_modifiable ? null : () => _choisirImage(context),
            icon: const Icon(Icons.image_outlined, size: 19),
            label: const Text("Ajouter une image au message"),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 13),
              side: BorderSide(color: Colors.grey.shade400),
            ),
          ),
      ],
    );
  }

  void _choisirImage(BuildContext context) async {
    final cubit = context.read<ModelesMessagesCubit>();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
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
    );
    if (source == null || widget.modele.id == null) return;

    final fichier = await ImagePicker()
        .pickImage(source: source, imageQuality: 82, maxWidth: 1280);
    if (fichier != null) {
      cubit.deposerImage(widget.modele.id!, File(fichier.path));
    }
  }

  Widget _boutonApercu(BuildContext context, ModelesMessagesState state) {
    final enCours = state.apercuStatus == AppStatus.loading;
    return OutlinedButton.icon(
      onPressed: enCours
          ? null
          : () => context
              .read<ModelesMessagesCubit>()
              .apercu(_contenu.text),
      icon: enCours
          ? const SizedBox(
              width: 15,
              height: 15,
              child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.visibility_outlined, size: 18),
      label: const Text("Aperçu avec des valeurs d'exemple"),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
        side: BorderSide(color: AppColors.primaryColor),
        foregroundColor: AppColors.primaryColor,
      ),
    );
  }

  Widget _apercu(ModelesMessagesState state) {
    final rendu = state.apercuRendu;
    if (rendu == null || rendu.apercu.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        // Rappelle la bulle WhatsApp pour situer le rendu réel.
        color: const Color(0xFFDCF8C6),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.chat_bubble_outline,
                  size: 15, color: Colors.green.shade900),
              const SizedBox(width: 6),
              Text("Ce que verra le destinataire",
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade900)),
            ],
          ),
          const SizedBox(height: 8),
          Text(rendu.apercu,
              style: const TextStyle(fontSize: 13.5, height: 1.4)),
          if (rendu.inconnues.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 16, color: Colors.orange.shade800),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      "Variables non reconnues : ${rendu.inconnues.join(', ')}.\n"
                      "Elles apparaîtront telles quelles dans le message.",
                      style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.orange.shade900,
                          height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _texteOrigine() {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 10),
        title: Text("Voir le texte d'origine",
            style: TextStyle(fontSize: 13, color: Colors.black87)),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(widget.modele.defaut ?? '',
                style: TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: Colors.black87)),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------

  void _enregistrer(BuildContext context) {
    if (_contenu.text.trim().isEmpty) {
      showToast("Le message ne peut pas être vide", context,
          type: ToastificationType.warning, second: 2);
      return;
    }
    if (widget.modele.id == null) return;
    context
        .read<ModelesMessagesCubit>()
        .enregistrer(widget.modele.id!, _contenu.text.trim(), actif: _actif);
  }

  void _restaurer(BuildContext context) async {
    final cubit = context.read<ModelesMessagesCubit>();
    final ok = await showDialogueQuestion(
      context,
      "Rétablir le texte d'origine de ce message ?",
      "Rétablir",
      "Annuler",
    );
    if (ok == true && widget.modele.id != null) {
      cubit.restaurerDefaut(widget.modele.id!);
    }
  }

  void _voirHistorique(BuildContext context) {
    final state = context.read<ModelesMessagesCubit>().state;
    final historique = state.courant?.id == widget.modele.id
        ? (state.courant?.historique ?? [])
        : (widget.modele.historique ?? []);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (_, controleur) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: historique.isEmpty
              ? Center(
                  child: Text(
                    "Ce message n'a jamais été modifié.",
                    style: TextStyle(fontSize: 13.5, color: Colors.black87),
                  ),
                )
              : ListView(
                  controller: controleur,
                  children: [
                    const Text("Historique des modifications",
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    ...historique.map(_ligneHistorique),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _ligneHistorique(ModificationModele m) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.edit_outlined, size: 14, color: Colors.black87),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  "${m.auteur ?? 'Administrateur'}"
                  "${m.date != null ? ' — ${_dateHeure(m.date!)}' : ''}",
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (m.contenuAvant != null) ...[
            Text("Avant",
                style: TextStyle(fontSize: 11, color: Colors.red.shade700)),
            Text(m.contenuAvant!,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12, height: 1.3, color: Colors.black87)),
            const SizedBox(height: 6),
          ],
          Text("Après",
              style: TextStyle(fontSize: 11, color: Colors.green.shade700)),
          Text(m.contenuApres ?? '',
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, height: 1.3)),
        ],
      ),
    );
  }

  String _dateHeure(DateTime d) =>
      "${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}"
      " à ${d.hour.toString().padLeft(2, '0')}h${d.minute.toString().padLeft(2, '0')}";
}
