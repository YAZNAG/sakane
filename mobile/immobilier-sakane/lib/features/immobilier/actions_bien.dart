import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:immobilier/core/constants/enums/permissions.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/core/utils/show_toast.dart';
import 'package:immobilier/features/immobilier/detail_immobilier/ui/components/partage_bien.dart';
import 'package:immobilier/models/manager.dart';
import 'package:immobilier/models/realestate.dart';
import 'package:immobilier/repository/repository.dart';
import 'package:immobilier/routes.dart';
import 'package:toastification/toastification.dart';

/// Ce que l'on peut faire d'un bien, d'où qu'on le regarde : partager sa
/// fiche, ouvrir son détail, le modifier.
///
/// Ces trois gestes n'existaient que dans la location de vacances. Un
/// bien à vendre ou loué à l'année se partage tout autant — c'est même
/// l'essentiel du travail d'un agent — et se corrige aussi souvent. Le
/// menu est donc le même partout, et respecte les mêmes droits.
class ActionsBien {
  /// Récupère la fiche complète — la carte d'une vente ou d'un bail n'en
  /// porte qu'un résumé — puis ouvre la feuille de partage.
  static Future<void> partager(BuildContext context, int bienId) async {
    final ferme = _attendre(context);
    Realestate? bien;
    String? erreur;
    try {
      bien = await Dependencies.get<Repository>().fetchRealesate(bienId);
    } catch (ex) {
      erreur = ex.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
    }
    ferme();

    if (!context.mounted) return;
    if (bien == null) {
      showToast('', context,
          description: erreur ?? "La fiche du bien n'a pas pu être chargée.",
          type: ToastificationType.error,
          second: 3);
      return;
    }
    await PartageBien.partager(context, bien);
  }

  /// La fiche du bien : photos, équipements, caractéristiques, carte.
  static Future<void> voirDetail(BuildContext context, int bienId) {
    return GoRouter.of(context)
        .push(Routes.immobilierDetails.replaceAll(':id', bienId.toString()))
        .then((_) {});
  }

  /// Le formulaire de modification, en plusieurs étapes.
  static Future<void> modifier(BuildContext context, int bienId) {
    return GoRouter.of(context)
        .push(Routes.updateImmobilier.replaceAll(':id', bienId.toString()))
        .then((_) {});
  }

  /// Un voile d'attente le temps de rapatrier la fiche : sans lui, le
  /// partage semble ne rien faire.
  static VoidCallback _attendre(BuildContext context) {
    var ouvert = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      ),
    );
    return () {
      if (ouvert && context.mounted) {
        ouvert = false;
        Navigator.of(context, rootNavigator: true).pop();
      }
    };
  }
}

/// Le menu des trois gestes, à poser sur une carte ou dans une barre de
/// titre. Il disparaît de lui-même quand l'utilisateur n'a aucun des
/// droits correspondants.
class MenuActionsBien extends StatelessWidget {
  final int bienId;

  /// Rappelé après une modification, pour rafraîchir l'écran appelant.
  final Future<void> Function()? onRetour;

  final Color couleurIcone;
  final double taille;

  const MenuActionsBien({
    super.key,
    required this.bienId,
    this.onRetour,
    this.couleurIcone = const Color(0xFF6B7B84),
    this.taille = 20,
  });

  @override
  Widget build(BuildContext context) {
    final manager = Dependencies.get<Manager>();
    final peutPartager = manager.can(AppPermission.shareProperty);
    final peutVoir = manager.can(AppPermission.viewProperties);
    final peutModifier = manager.can(AppPermission.updateProperty);

    if (!peutPartager && !peutVoir && !peutModifier) {
      return const SizedBox.shrink();
    }

    return PopupMenuButton<String>(
      tooltip: 'Actions sur le bien',
      padding: EdgeInsets.zero,
      icon: Icon(Icons.more_vert, size: taille, color: couleurIcone),
      onSelected: (choix) async {
        switch (choix) {
          case 'partager':
            await ActionsBien.partager(context, bienId);
            break;
          case 'detail':
            await ActionsBien.voirDetail(context, bienId);
            if (onRetour != null) await onRetour!();
            break;
          case 'modifier':
            await ActionsBien.modifier(context, bienId);
            if (onRetour != null) await onRetour!();
            break;
        }
      },
      itemBuilder: (_) => [
        if (peutPartager)
          const PopupMenuItem(
            value: 'partager',
            child: Row(children: [
              Icon(Icons.share_outlined, size: 18),
              SizedBox(width: 10),
              Text('Partager le bien'),
            ]),
          ),
        if (peutVoir)
          const PopupMenuItem(
            value: 'detail',
            child: Row(children: [
              Icon(Icons.info_outline, size: 18),
              SizedBox(width: 10),
              Text('Voir le détail'),
            ]),
          ),
        if (peutModifier)
          const PopupMenuItem(
            value: 'modifier',
            child: Row(children: [
              Icon(Icons.edit_outlined, size: 18),
              SizedBox(width: 10),
              Text('Modifier le bien'),
            ]),
          ),
      ],
    );
  }
}

/// Les trois gestes en boutons, pour une fiche : plus visibles qu'un menu
/// quand l'écran est tout entier consacré à ce bien.
class BoutonsActionsBien extends StatelessWidget {
  final int bienId;
  final Color teinte;
  final Future<void> Function()? onRetour;

  const BoutonsActionsBien({
    super.key,
    required this.bienId,
    required this.teinte,
    this.onRetour,
  });

  @override
  Widget build(BuildContext context) {
    final manager = Dependencies.get<Manager>();
    final boutons = <Widget>[
      if (manager.can(AppPermission.shareProperty))
        _bouton(
          context,
          icone: Icons.share_outlined,
          libelle: 'Partager',
          plein: true,
          onTap: () => ActionsBien.partager(context, bienId),
        ),
      if (manager.can(AppPermission.viewProperties))
        _bouton(
          context,
          icone: Icons.info_outline,
          libelle: 'Détail du bien',
          onTap: () async {
            await ActionsBien.voirDetail(context, bienId);
            if (onRetour != null) await onRetour!();
          },
        ),
      if (manager.can(AppPermission.updateProperty))
        _bouton(
          context,
          icone: Icons.edit_outlined,
          libelle: 'Modifier',
          onTap: () async {
            await ActionsBien.modifier(context, bienId);
            if (onRetour != null) await onRetour!();
          },
        ),
    ];

    if (boutons.isEmpty) return const SizedBox.shrink();

    return Row(
      children: [
        for (var i = 0; i < boutons.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: boutons[i]),
        ],
      ],
    );
  }

  Widget _bouton(
    BuildContext context, {
    required IconData icone,
    required String libelle,
    required VoidCallback onTap,
    bool plein = false,
  }) {
    return Material(
      color: plein ? teinte : Colors.white,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
          decoration: BoxDecoration(
            border: Border.all(color: plein ? teinte : const Color(0xFFE2E8EC)),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Column(
            children: [
              Icon(icone, size: 19, color: plein ? Colors.white : teinte),
              const SizedBox(height: 4),
              Text(
                libelle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: plein ? Colors.white : const Color(0xFF17262E),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
