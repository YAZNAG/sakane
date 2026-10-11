import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/constants/enums/permissions.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/core/utils/show_toast.dart';
import 'package:immobilier/features/activite_equipe/commun/activite_ui.dart';
import 'package:immobilier/features/syndics/cubit/groupes_whatsapp_cubit.dart';
import 'package:immobilier/models/groupe_whatsapp.dart';
import 'package:immobilier/models/manager.dart';
import 'package:toastification/toastification.dart';

/// Les groupes WhatsApp de l'agence.
///
/// Un message envoyé à un groupe touche tous ses membres : c'est utile quand
/// un immeuble a plusieurs responsables, ou quand l'agence veut que son
/// équipe voie ce qui part. Un groupe s'ajoute de deux façons — en le
/// choisissant parmi ceux dont le numéro de l'agence est déjà membre, ou en
/// collant son lien d'invitation, auquel cas le numéro rejoint le groupe.
class GroupesWhatsappPage extends StatelessWidget {
  const GroupesWhatsappPage({super.key});

  static Widget page() => BlocProvider<GroupesWhatsappCubit>(
        create: (_) => GroupesWhatsappCubit()..charger(),
        child: const GroupesWhatsappPage(),
      );

  /// Ouvre l'écran, puis dit si quelque chose a changé.
  static Future<void> ouvrir(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => GroupesWhatsappPage.page()),
    );
  }

  bool get _peutGerer =>
      Dependencies.get<Manager>().can(AppPermission.manageWhatsappGroups);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(
        title: const Text('Groupes WhatsApp',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        elevation: 0,
        foregroundColor: Colors.white,
        backgroundColor: AppColors.primaryColor,
      ),
      floatingActionButton: !_peutGerer
          ? null
          : Builder(
              builder: (ctx) => FloatingActionButton.extended(
                onPressed: () => _ajouter(ctx),
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.group_add_outlined),
                label: const Text('Ajouter un groupe',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
      body: BlocConsumer<GroupesWhatsappCubit, GroupesWhatsappState>(
        listenWhen: (avant, apres) =>
            avant.actionStatus != apres.actionStatus &&
            apres.actionStatus == AppStatus.error,
        listener: (context, state) => showToast('', context,
            description: state.error ?? 'Action impossible',
            type: ToastificationType.error,
            second: 4),
        builder: (context, state) {
          if (state.enAttente) {
            return const Padding(
              padding: EdgeInsets.fromLTRB(14, 14, 14, 0),
              child: SqueletteActivite(totaux: 0, lignes: 4),
            );
          }
          if (state.fetchStatus == AppStatus.error && state.donnees == null) {
            return Padding(
              padding: const EdgeInsets.all(14),
              child: ErreurActivite(
                message: state.error ?? 'Les groupes sont introuvables.',
                onReessayer: () => context.read<GroupesWhatsappCubit>().charger(),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => context.read<GroupesWhatsappCubit>().charger(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 96),
              children: [
                _explication(),
                const SizedBox(height: 14),
                if (state.groupes.isEmpty)
                  const VideActivite(
                    titre: 'Aucun groupe enregistré',
                    detail:
                        'Ajoutez un groupe pour que le contrat parte à tous ses membres, au lieu d’un seul numéro.',
                    icone: Icons.groups_outlined,
                  )
                else
                  for (final groupe in state.groupes)
                    _carte(context, groupe),
                if (state.disponibles.isNotEmpty && _peutGerer) ...[
                  const SizedBox(height: 18),
                  _titre(
                      'Sur WhatsApp, pas encore enregistrés (${state.disponibles.length})'),
                  const SizedBox(height: 8),
                  for (final dispo in state.disponibles)
                    _carteDisponible(context, dispo),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _titre(String texte) => Text(
        texte.toUpperCase(),
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.bold,
          letterSpacing: .6,
          color: couleurGrisActivite,
        ),
      );

  Widget _explication() {
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
      decoration: BoxDecoration(
        color: AppColors.primaryColor.withValues(alpha: .06),
        border: Border.all(color: AppColors.primaryColor.withValues(alpha: .22)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: AppColors.primaryColor),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Un syndic peut recevoir le contrat dans un groupe plutôt que sur '
              'son numéro : choisissez le groupe dans sa fiche. Le numéro de '
              'l’agence doit être membre du groupe pour pouvoir y écrire.',
              style: TextStyle(fontSize: 12.5, height: 1.35, color: couleurTexteActivite),
            ),
          ),
        ],
      ),
    );
  }

  Widget _carte(BuildContext context, GroupeWhatsapp groupe) {
    final details = [
      if (groupe.participants != null)
        '${groupe.participants} ${pluriel(groupe.participants!, 'membre')}',
      if (groupe.syndics > 0)
        '${groupe.syndics} ${pluriel(groupe.syndics, 'syndic')}',
      if (groupe.verifieLe != null) 'vérifié ${dateCourteActivite(groupe.verifieLe)}',
    ].join(' · ');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(13, 12, 6, 12),
      decoration: carteActivite,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: (groupe.actif ? couleurVertActivite : couleurGrisActivite)
                  .withValues(alpha: .12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.groups,
                size: 21,
                color: groupe.actif ? couleurVertActivite : couleurGrisActivite),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        groupe.nom,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                            color: couleurTexteActivite),
                      ),
                    ),
                    if (!groupe.actif)
                      const PastilleActivite(
                          texte: 'Désactivé', teinte: couleurGrisActivite),
                  ],
                ),
                if (details.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    details,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11.5,
                        color: couleurGrisActivite,
                        fontFeatures: chiffresActivite),
                  ),
                ],
              ],
            ),
          ),
          if (_peutGerer) _menu(context, groupe) else const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _menu(BuildContext context, GroupeWhatsapp groupe) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 20, color: couleurGrisActivite),
      onSelected: (choix) async {
        final cubit = context.read<GroupesWhatsappCubit>();
        switch (choix) {
          case 'renommer':
            final nom = await _demanderNom(context, groupe.nom);
            if (nom == null) return;
            if (await cubit.renommer(groupe.id, nom) && context.mounted) {
              showToast('Groupe renommé', context, second: 2);
            }
            break;
          case 'verifier':
            if (await cubit.verifier(groupe.id) && context.mounted) {
              showToast('Groupe vérifié', context, second: 2);
            }
            break;
          case 'activer':
            await cubit.activer(groupe.id, !groupe.actif);
            break;
          case 'supprimer':
            final confirme = await _confirmer(
              context,
              titre: 'Retirer ce groupe ?',
              texte: groupe.syndics > 0
                  ? '${groupe.syndics} ${pluriel(groupe.syndics, 'syndic')} y '
                      'reçoit : il reviendra à son numéro. Le groupe WhatsApp '
                      'lui-même n’est pas supprimé.'
                  : 'Le groupe WhatsApp lui-même n’est pas supprimé : il ne '
                      'sera simplement plus proposé ici.',
            );
            if (confirme != true) return;
            if (await cubit.supprimer(groupe.id) && context.mounted) {
              showToast('Groupe retiré', context, second: 2);
            }
            break;
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'renommer',
          child: Row(children: [
            Icon(Icons.edit_outlined, size: 18),
            SizedBox(width: 10),
            Text('Renommer'),
          ]),
        ),
        const PopupMenuItem(
          value: 'verifier',
          child: Row(children: [
            Icon(Icons.verified_outlined, size: 18),
            SizedBox(width: 10),
            Text('Vérifier le groupe'),
          ]),
        ),
        PopupMenuItem(
          value: 'activer',
          child: Row(children: [
            Icon(groupe.actif ? Icons.pause_circle_outline : Icons.play_circle_outline,
                size: 18),
            const SizedBox(width: 10),
            Text(groupe.actif ? 'Désactiver' : 'Réactiver'),
          ]),
        ),
        const PopupMenuItem(
          value: 'supprimer',
          child: Row(children: [
            Icon(Icons.delete_outline, size: 18, color: couleurRougeActivite),
            SizedBox(width: 10),
            Text('Retirer'),
          ]),
        ),
      ],
    );
  }

  /// Un groupe vu sur WhatsApp : un seul geste pour l'enregistrer.
  Widget _carteDisponible(BuildContext context, GroupeDisponible dispo) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: carteActivite,
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(13, 2, 8, 2),
        leading: Icon(Icons.groups_outlined, color: couleurGrisActivite),
        title: Text(
          // WhatsApp ne donne pas toujours le nom d'un groupe : on le dit,
          // plutot que d'afficher un identifiant brut.
          dispo.nom == dispo.jid ? 'Groupe sans nom' : dispo.nom,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              fontSize: 13.5, fontWeight: FontWeight.w600, color: couleurTexteActivite),
        ),
        subtitle: dispo.nom != dispo.jid
            ? null
            : Text(
                dispo.jid.split('@').first,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: couleurGrisActivite),
              ),
        trailing: TextButton.icon(
          onPressed: () async {
            final cubit = context.read<GroupesWhatsappCubit>();
            if (await cubit.ajouter(jid: dispo.jid, nom: dispo.nom) &&
                context.mounted) {
              showToast('« ${dispo.nom} » enregistré', context, second: 2);
            }
          },
          icon: const Icon(Icons.add, size: 17),
          label: const Text('Ajouter'),
          style: TextButton.styleFrom(foregroundColor: AppColors.primaryColor),
        ),
      ),
    );
  }

  // ── Les gestes ────────────────────────────────────────────────────

  Future<void> _ajouter(BuildContext context) async {
    final cubit = context.read<GroupesWhatsappCubit>();
    final saisie = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FeuilleAjout(disponibles: cubit.state.disponibles),
    );
    if (saisie == null) return;

    final ok = await cubit.ajouter(
      jid: saisie['jid'],
      nom: saisie['nom'],
      lien: saisie['lien'],
    );
    if (ok && context.mounted) {
      showToast('Groupe ajouté', context, second: 2);
    }
  }

  Future<String?> _demanderNom(BuildContext context, String actuel) {
    final champ = TextEditingController(text: actuel);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Nom du groupe',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: champ,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Syndic Résidence Al Fath'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler',
                style: TextStyle(color: couleurGrisActivite)),
          ),
          ElevatedButton(
            onPressed: () {
              final nom = champ.text.trim();
              if (nom.length < 2) return;
              Navigator.of(ctx).pop(nom);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.white,
                elevation: 0),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirmer(BuildContext context,
      {required String titre, required String texte}) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(titre,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Text(texte,
            style: const TextStyle(fontSize: 13.5, color: couleurGrisActivite)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Non', style: TextStyle(color: couleurGrisActivite)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
                backgroundColor: couleurRougeActivite,
                foregroundColor: Colors.white,
                elevation: 0),
            child: const Text('Retirer'),
          ),
        ],
      ),
    );
  }
}

/// Deux façons d'ajouter un groupe : le choisir, ou coller son lien.
class _FeuilleAjout extends StatefulWidget {
  final List<GroupeDisponible> disponibles;

  const _FeuilleAjout({required this.disponibles});

  @override
  State<_FeuilleAjout> createState() => _FeuilleAjoutState();
}

class _FeuilleAjoutState extends State<_FeuilleAjout> {
  final _lien = TextEditingController();
  final _nom = TextEditingController();
  String? _choisi;

  @override
  void dispose() {
    _lien.dispose();
    _nom.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(context).size.height * .9),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD7DEE3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text('Ajouter un groupe WhatsApp',
                  style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.bold,
                      color: couleurTexteActivite)),
              const SizedBox(height: 16),
              if (widget.disponibles.isNotEmpty) ...[
                const Text('CHOISIR UN GROUPE DU NUMÉRO DE L’AGENCE',
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: .6,
                        color: couleurGrisActivite)),
                const SizedBox(height: 8),
                for (final g in widget.disponibles)
                  RadioListTile<String>(
                    value: g.jid,
                    groupValue: _choisi,
                    onChanged: (v) => setState(() {
                      _choisi = v;
                      _lien.clear();
                    }),
                    activeColor: AppColors.primaryColor,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(g.nom,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13.5, color: couleurTexteActivite)),
                  ),
                const SizedBox(height: 10),
                const Divider(height: 1, color: couleurBordureActivite),
                const SizedBox(height: 14),
              ],
              const Text('OU COLLER UN LIEN D’INVITATION',
                  style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: .6,
                      color: couleurGrisActivite)),
              const SizedBox(height: 8),
              TextField(
                controller: _lien,
                onChanged: (v) => setState(() {
                  if (v.trim().isNotEmpty) _choisi = null;
                }),
                inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
                style: const TextStyle(fontSize: 13.5),
                decoration: InputDecoration(
                  hintText: 'https://chat.whatsapp.com/…',
                  hintStyle: const TextStyle(fontSize: 12.5),
                  prefixIcon: const Icon(Icons.link, size: 19),
                  filled: true,
                  fillColor: couleurFondActivite,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: couleurBordureActivite),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'Le numéro de l’agence rejoindra le groupe : sans être '
                  'membre, il ne peut pas y écrire.',
                  style: TextStyle(fontSize: 11, color: couleurGrisActivite),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _nom,
                style: const TextStyle(fontSize: 13.5),
                decoration: InputDecoration(
                  labelText: 'Nom à afficher (optionnel)',
                  labelStyle: const TextStyle(fontSize: 13),
                  prefixIcon: const Icon(Icons.label_outline, size: 19),
                  filled: true,
                  fillColor: couleurFondActivite,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: couleurBordureActivite),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        side: const BorderSide(color: couleurBordureActivite),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Annuler',
                          style: TextStyle(color: couleurGrisActivite)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _valider,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Ajouter',
                          style: TextStyle(fontWeight: FontWeight.bold)),
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

  void _valider() {
    final lien = _lien.text.trim();
    final nom = _nom.text.trim();

    if (_choisi == null && lien.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Choisissez un groupe, ou collez son lien d’invitation.'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    Navigator.of(context).pop({
      if (_choisi != null) 'jid': _choisi!,
      if (lien.isNotEmpty) 'lien': lien,
      if (nom.isNotEmpty)
        'nom': nom
      else if (_choisi != null)
        'nom': widget.disponibles
            .firstWhere((g) => g.jid == _choisi,
                orElse: () => const GroupeDisponible(jid: '', nom: ''))
            .nom,
    });
  }
}
