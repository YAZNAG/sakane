import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:immobilier/components/error_widget.dart';
import 'package:immobilier/components/loading_indicator.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/core/constants/app_strings.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/features/permissions/cubit/permissions_utilisateur_cubit.dart';
import 'package:immobilier/features/permissions/ui/permissions_widgets.dart';
import 'package:immobilier/models/permissions_roles.dart';

enum _Filtre { tous, personnalises, effectifs }

/// Les droits d'un utilisateur précis. Chaque droit est soit hérité du
/// rôle, soit accordé en plus, soit retiré ; l'état final est affiché à
/// côté.
class PermissionsUtilisateurPage extends StatefulWidget {
  /// Prévient l'écran principal pour mettre à jour la ligne de la liste.
  final ValueChanged<UtilisateurPermissions>? onEnregistre;

  const PermissionsUtilisateurPage({super.key, this.onEnregistre});

  static Widget page({
    required UtilisateurPermissions utilisateur,
    required List<ModulePermissions> modules,
    ValueChanged<UtilisateurPermissions>? onEnregistre,
  }) =>
      BlocProvider(
        create: (_) => PermissionsUtilisateurCubit(
          utilisateur: utilisateur,
          modules: modules,
        )..charger(),
        child: PermissionsUtilisateurPage(onEnregistre: onEnregistre),
      );

  @override
  State<PermissionsUtilisateurPage> createState() =>
      _PermissionsUtilisateurPageState();
}

class _PermissionsUtilisateurPageState
    extends State<PermissionsUtilisateurPage> {
  final Set<String> _ouverts = {};
  final Set<String> _sousFermes = {};
  final _recherche = TextEditingController();
  String _requete = '';
  _Filtre _filtre = _Filtre.tous;

  @override
  void dispose() {
    _recherche.dispose();
    super.dispose();
  }

  Future<void> _enregistrer(
      BuildContext context, PermissionsUtilisateurState state) async {
    final cubit = context.read<PermissionsUtilisateurCubit>();
    final perdus = state.perdus.length;
    if (perdus > 0) {
      final pluriel = perdus > 1 ? 's' : '';
      final ok = await confirmerDroits(
        context,
        titre: 'Confirmer le retrait',
        message: '${state.utilisateur.nom} perdra $perdus '
            'droit$pluriel qu\'il a aujourd\'hui.',
        confirmer: 'Enregistrer',
        danger: true,
      );
      if (!ok) return;
    }
    await cubit.enregistrer();
  }

  Future<void> _reinitialiser(
      BuildContext context, PermissionsUtilisateurState state) async {
    final cubit = context.read<PermissionsUtilisateurCubit>();
    final a = state.accordes.length;
    final r = state.retires.length;
    final ok = await confirmerDroits(
      context,
      titre: 'Revenir aux droits du rôle',
      message: 'Les exceptions de ${state.utilisateur.nom} seront effacées '
          '($a accordé${a > 1 ? 's' : ''}, $r retiré${r > 1 ? 's' : ''}) : '
          'il retrouvera exactement les droits de son rôle. '
          'Pensez à enregistrer ensuite.',
      confirmer: 'Réinitialiser',
      danger: true,
    );
    if (ok) cubit.reinitialiser();
  }

  Future<void> _quitter(BuildContext context) async {
    final navigator = Navigator.of(context);
    if (!await confirmerAbandon(context)) return;
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PermissionsUtilisateurCubit,
        PermissionsUtilisateurState>(
      listenWhen: (a, b) => a.saveStatus != b.saveStatus,
      listener: (context, state) {
        if (state.saveStatus == AppStatus.success) {
          messageDroits(context, state.message ?? 'Droits enregistrés');
          widget.onEnregistre?.call(state.utilisateur);
        } else if (state.saveStatus == AppStatus.error) {
          messageDroits(context, state.error ?? "L'enregistrement a échoué",
              erreur: true);
        }
      },
      builder: (context, state) {
        return PopScope(
          canPop: !state.modifie,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _quitter(context);
          },
          child: Scaffold(
            backgroundColor: Colors.grey.shade50,
            appBar: AppBar(
              title: Column(
                children: [
                  Text(
                    state.utilisateur.nom,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 17),
                  ),
                  const Text(
                    'Droits et permissions',
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
              centerTitle: true,
              elevation: 0,
              foregroundColor: Colors.white,
              backgroundColor: AppColors.primaryColor,
            ),
            body: _corps(context, state),
            bottomNavigationBar: state.modifie
                ? BarreEnregistrementDroits(
                    enCours: state.enregistrement,
                    precision: '${state.utilisateur.nom} · '
                        '+${state.accordes.length} / −${state.retires.length}',
                    onAnnuler: () =>
                        context.read<PermissionsUtilisateurCubit>().annuler(),
                    onEnregistrer: () => _enregistrer(context, state),
                  )
                : null,
          ),
        );
      },
    );
  }

  Widget _corps(BuildContext context, PermissionsUtilisateurState state) {
    final cubit = context.read<PermissionsUtilisateurCubit>();
    if (state.detail == null) {
      if (state.fetchStatus == AppStatus.error) {
        return Center(
          child: MyErrorWidget(
            error: state.error ?? "Une erreur s'est produite",
            action: AppStrings.tryAgain,
            actionCLick: cubit.charger,
          ),
        );
      }
      return Center(child: MyLoadingIndicator());
    }

    final requete = normaliserRecherche(_requete);
    final deplie = requete.isNotEmpty || _filtre != _Filtre.tous;
    bool garder(PermissionDroit p) {
      switch (_filtre) {
        case _Filtre.tous:
          return true;
        case _Filtre.personnalises:
          return state.personnalise(p.code);
        case _Filtre.effectifs:
          return state.effectif(p.code);
      }
    }

    final cartes = <Widget>[];
    for (final m in state.modules) {
      final sous = filtrerSousModules(m, requete, garder: garder);
      if (sous.isEmpty) continue;
      cartes.add(_carteModule(context, state, m, sous, deplie: deplie));
    }

    return Column(
      children: [
        _filtres(state),
        Divider(height: 1, color: Colors.grey.shade300),
        Expanded(
          child: RefreshIndicator(
            onRefresh: cubit.charger,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 26),
              children: [
                _entete(context, state),
                const SizedBox(height: 10),
                if (state.utilisateur.verrouille) ...[
                  const BandeauDroits(
                    icone: Icons.lock_outline_rounded,
                    texte: 'Administrateur : tous les droits, non modifiable.',
                  ),
                  const SizedBox(height: 10),
                ],
                if (cartes.isEmpty)
                  _aucunResultat()
                else
                  ...cartes,
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _aucunResultat() {
    final texte = switch (_filtre) {
      _Filtre.personnalises when _requete.isEmpty =>
        "Aucun droit personnalisé : l'utilisateur a exactement les droits de son rôle.",
      _Filtre.effectifs when _requete.isEmpty =>
        "L'utilisateur n'a aucun droit.",
      _ => 'Aucun droit ne correspond à la recherche.',
    };
    return Padding(
      padding: const EdgeInsets.only(top: 30),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, size: 46, color: Colors.grey.shade400),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              texte,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, color: Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }

  /// Recherche, filtres rapides et dépliage, fixés en haut.
  Widget _filtres(PermissionsUtilisateurState state) {
    final personnalises = state.accordes.length + state.retires.length;
    Widget choix(_Filtre f, String libelle) {
      final actif = _filtre == f;
      return ChoiceChip(
        label: Text(libelle),
        selected: actif,
        onSelected: (_) => setState(() => _filtre = f),
        showCheckmark: false,
        visualDensity: VisualDensity.compact,
        labelStyle: TextStyle(
          fontSize: 12.5,
          fontWeight: actif ? FontWeight.bold : FontWeight.w500,
          color: actif ? AppColors.primaryColor : Colors.grey.shade800,
        ),
        selectedColor: AppColors.primaryColor.withValues(alpha: .12),
        backgroundColor: Colors.grey.shade100,
        side: BorderSide(
          color: actif ? AppColors.primaryColor : Colors.grey.shade300,
        ),
      );
    }

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Column(
        children: [
          ChampRechercheDroits(
            controller: _recherche,
            onChanged: (v) => setState(() => _requete = v),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                choix(_Filtre.tous, 'Tous'),
                const SizedBox(width: 6),
                choix(_Filtre.personnalises, 'Personnalisés ($personnalises)'),
                const SizedBox(width: 6),
                choix(_Filtre.effectifs, 'Effectifs (${state.nombreEffectifs})'),
              ],
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: BoutonsDepliage(
              onDeplier: () => setState(() {
                _ouverts.addAll(state.modules.map((m) => m.code));
                _sousFermes.clear();
              }),
              onReplier: () => setState(() {
                _ouverts.clear();
                _sousFermes.clear();
              }),
            ),
          ),
        ],
      ),
    );
  }

  /// L'utilisateur, ses rôles et le bilan de ses droits.
  Widget _entete(BuildContext context, PermissionsUtilisateurState state) {
    final u = state.utilisateur;
    final personnalise = state.accordes.isNotEmpty || state.retires.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.primaryColor.withValues(alpha: .12),
                child: Text(
                  u.initiales,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppColors.primaryColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      u.nom,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: couleurTexteDroits,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.badge_outlined,
                            size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            u.rolesLisibles,
                            style: TextStyle(
                                fontSize: 12.5, color: Colors.grey.shade700),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (state.modifie) const BadgeNonEnregistre(),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _stat(
                valeur: '${state.nombreEffectifs} / ${state.total}',
                libelle: 'Effectifs',
                couleur: AppColors.primaryColor,
              ),
              const SizedBox(width: 8),
              _stat(
                valeur: '+${state.accordes.length}',
                libelle: 'Accordés',
                couleur: Colors.green.shade700,
              ),
              const SizedBox(width: 8),
              _stat(
                valeur: '−${state.retires.length}',
                libelle: 'Retirés',
                couleur: Colors.red.shade700,
              ),
            ],
          ),
          if (state.modifiable && personnalise) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: state.enregistrement
                    ? null
                    : () => _reinitialiser(context, state),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red.shade700,
                  textStyle: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
                icon: const Icon(Icons.restart_alt_rounded, size: 18),
                label: const Text('Réinitialiser (revenir au rôle)'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _stat({
    required String valeur,
    required String libelle,
    required Color couleur,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: couleur.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Column(
          children: [
            Text(
              valeur,
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.bold, color: couleur),
            ),
            const SizedBox(height: 1),
            Text(
              libelle,
              style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _carteModule(
    BuildContext context,
    PermissionsUtilisateurState state,
    ModulePermissions m,
    List<SousModulePermissions> sous, {
    required bool deplie,
  }) {
    final cubit = context.read<PermissionsUtilisateurCubit>();
    final ouvert = deplie || _ouverts.contains(m.code);
    final perso = state.personnalisesParmi(m.codes);
    final enfants = <Widget>[];
    for (final s in sous) {
      final cle = '${m.code}/${s.code}';
      final sousOuvert = deplie || !_sousFermes.contains(cle);
      if (!m.sansSousModules) {
        enfants.add(EnTeteSousModule(
          sousModule: s,
          ouvert: sousOuvert,
          onOuvrir: () => setState(() {
            if (!_sousFermes.remove(cle)) _sousFermes.add(cle);
          }),
          compteur: CompteurDroits(
            n: state.effectifsParmi(s.codes),
            total: s.codes.length,
            petit: true,
          ),
        ));
      }
      if (sousOuvert || m.sansSousModules) {
        for (final p in s.permissions) {
          enfants.add(_LigneDroitUtilisateur(
            droit: p,
            etat: state.etat(p.code),
            roleDonne: state.parRole.contains(p.code),
            effectif: state.effectif(p.code),
            verrouille: state.utilisateur.verrouille,
            retrait: m.sansSousModules ? 14 : 26,
            onChanged: state.modifiable && !state.enregistrement
                ? (e) => cubit.definir(p.code, e)
                : null,
          ));
        }
      }
    }
    return CarteModuleDroits(
      key: ValueKey('utilisateur-${m.code}'),
      module: m,
      ouvert: ouvert,
      onOuvrir: () => setState(() {
        if (!_ouverts.remove(m.code)) _ouverts.add(m.code);
      }),
      compteur: CompteurDroits(
          n: state.effectifsParmi(m.codes), total: m.codes.length),
      action: const SizedBox(width: 4),
      sousTitre: perso > 0
          ? Text(
              '$perso personnalisé${perso > 1 ? 's' : ''}',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Colors.orange.shade800,
              ),
            )
          : null,
      enfants: enfants,
    );
  }
}

/// Un droit pour un utilisateur : libellé, état choisi, résultat final.
class _LigneDroitUtilisateur extends StatelessWidget {
  final PermissionDroit droit;
  final EtatDroitUtilisateur etat;
  final bool roleDonne;
  final bool effectif;
  final bool verrouille;
  final double retrait;
  final ValueChanged<EtatDroitUtilisateur>? onChanged;

  const _LigneDroitUtilisateur({
    required this.droit,
    required this.etat,
    required this.roleDonne,
    required this.effectif,
    required this.verrouille,
    required this.retrait,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final fond = switch (etat) {
      EtatDroitUtilisateur.accorde => Colors.green.shade50,
      EtatDroitUtilisateur.retire => Colors.red.shade50,
      EtatDroitUtilisateur.role => Colors.transparent,
    };
    return Container(
      decoration: BoxDecoration(
        color: fond,
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      padding: EdgeInsets.fromLTRB(retrait, 8, 10, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  droit.libelle,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: effectif ? couleurTexteDroits : Colors.grey.shade700,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              PastilleAction(droit.action),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _Resultat(effectif: effectif),
              const Spacer(),
              if (!verrouille)
                _SelecteurEtat(
                  etat: etat,
                  roleDonne: roleDonne,
                  onChanged: onChanged,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// « Autorisé » en vert ou « Refusé » en gris.
class _Resultat extends StatelessWidget {
  final bool effectif;

  const _Resultat({required this.effectif});

  @override
  Widget build(BuildContext context) {
    final couleur = effectif ? Colors.green.shade700 : Colors.grey.shade500;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          effectif ? Icons.check_circle_rounded : Icons.cancel_rounded,
          size: 17,
          color: couleur,
        ),
        const SizedBox(width: 4),
        Text(
          effectif ? 'Autorisé' : 'Refusé',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: couleur,
          ),
        ),
      ],
    );
  }
}

/// Sélecteur compact à trois positions : Rôle / Accordé / Retiré.
class _SelecteurEtat extends StatelessWidget {
  final EtatDroitUtilisateur etat;
  final bool roleDonne;
  final ValueChanged<EtatDroitUtilisateur>? onChanged;

  const _SelecteurEtat({
    required this.etat,
    required this.roleDonne,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _segment(
              EtatDroitUtilisateur.role,
              libelle: 'Rôle',
              icone: roleDonne ? Icons.check_rounded : Icons.close_rounded,
              couleur: AppColors.primaryColor,
              tooltip: roleDonne
                  ? 'Hérité du rôle : le rôle donne ce droit'
                  : "Hérité du rôle : le rôle ne donne pas ce droit",
            ),
            _separateur(),
            _segment(
              EtatDroitUtilisateur.accorde,
              libelle: 'Accordé',
              couleur: Colors.green.shade700,
              tooltip: 'Accordé en plus du rôle',
            ),
            _separateur(),
            _segment(
              EtatDroitUtilisateur.retire,
              libelle: 'Retiré',
              couleur: Colors.red.shade700,
              tooltip: 'Retiré malgré le rôle',
            ),
          ],
        ),
      ),
    );
  }

  Widget _separateur() =>
      Container(width: 1, color: Colors.grey.shade300);

  Widget _segment(
    EtatDroitUtilisateur valeur, {
    required String libelle,
    required Color couleur,
    required String tooltip,
    IconData? icone,
  }) {
    final actif = etat == valeur;
    final texte = actif ? Colors.white : Colors.grey.shade700;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: actif
            ? (onChanged == null ? couleur.withValues(alpha: .55) : couleur)
            : Colors.transparent,
        child: InkWell(
          onTap: onChanged == null || actif ? null : () => onChanged!(valeur),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  libelle,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: actif ? FontWeight.bold : FontWeight.w500,
                    color: texte,
                  ),
                ),
                if (icone != null) ...[
                  const SizedBox(width: 2),
                  Icon(
                    icone,
                    size: 13,
                    color: actif
                        ? Colors.white
                        : (roleDonne
                            ? Colors.green.shade700
                            : Colors.red.shade400),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
