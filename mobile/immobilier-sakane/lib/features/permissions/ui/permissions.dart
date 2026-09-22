import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:immobilier/components/error_widget.dart';
import 'package:immobilier/components/loading_indicator.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/core/constants/app_strings.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/features/permissions/cubit/permissions_cubit.dart';
import 'package:immobilier/features/permissions/ui/permissions_utilisateur.dart';
import 'package:immobilier/features/permissions/ui/permissions_widgets.dart';
import 'package:immobilier/models/permissions_roles.dart';

/// Droits et permissions, en deux onglets :
/// - « Par rôle » : ce que chaque rôle permet, module par module ;
/// - « Par utilisateur » : les exceptions propres à un utilisateur.
///
/// Les modules, sous-modules et droits viennent du serveur : rien n'est
/// écrit en dur ici, un droit ajouté plus tard apparaît tout seul.
class PermissionsPage extends StatefulWidget {
  const PermissionsPage({super.key});

  static Widget page() => BlocProvider(
        create: (_) => PermissionsCubit()..charger(),
        child: const PermissionsPage(),
      );

  @override
  State<PermissionsPage> createState() => _PermissionsPageState();
}

class _PermissionsPageState extends State<PermissionsPage> {
  /// Les modules dépliés ; l'écran s'ouvre tout replié.
  final Set<String> _ouverts = {};

  /// Les sous-modules repliés (« module/sous-module »).
  final Set<String> _sousFermes = {};

  final _recherche = TextEditingController();
  final _rechercheUtilisateurs = TextEditingController();
  String _requete = '';
  String _requeteUtilisateurs = '';

  @override
  void dispose() {
    _recherche.dispose();
    _rechercheUtilisateurs.dispose();
    super.dispose();
  }

  /// Retirer un droit coupe un accès à des utilisateurs : on le dit
  /// avant d'envoyer.
  Future<void> _enregistrer(BuildContext context, PermissionsState state) async {
    final cubit = context.read<PermissionsCubit>();
    final role = state.roleCourant;
    if (role == null) return;
    final retires = state.retires.length;
    if (retires > 0) {
      final pluriel = retires > 1 ? 's' : '';
      final ok = await confirmerDroits(
        context,
        titre: 'Confirmer le retrait',
        message: '$retires droit$pluriel retiré$pluriel au rôle '
            '« ${role.libelle} ». '
            '${role.utilisateurs > 0 ? 'Les utilisateurs de ce rôle perdront ces accès (sauf droit accordé personnellement).' : ''}',
        confirmer: 'Enregistrer',
        danger: true,
      );
      if (!ok) return;
    }
    await cubit.enregistrer();
  }

  Future<void> _choisirRole(
      BuildContext context, PermissionsState state, String nom) async {
    if (nom == state.roleChoisi) return;
    final cubit = context.read<PermissionsCubit>();
    if (state.modifie && !await confirmerAbandon(context)) return;
    cubit.choisirRole(nom);
  }

  Future<void> _quitter(BuildContext context) async {
    final navigator = Navigator.of(context);
    final cubit = context.read<PermissionsCubit>();
    if (!await confirmerAbandon(context)) return;
    cubit.annuler();
    navigator.pop();
  }

  void _ouvrirUtilisateur(BuildContext context, UtilisateurPermissions u) {
    final cubit = context.read<PermissionsCubit>();
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PermissionsUtilisateurPage.page(
        utilisateur: u,
        modules: cubit.state.modules,
        onEnregistre: cubit.majUtilisateur,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PermissionsCubit, PermissionsState>(
      listenWhen: (a, b) => a.saveStatus != b.saveStatus,
      listener: (context, state) {
        if (state.saveStatus == AppStatus.success) {
          messageDroits(context, state.message ?? 'Droits enregistrés');
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
          child: DefaultTabController(
            length: 2,
            child: Scaffold(
              backgroundColor: Colors.grey.shade50,
              appBar: AppBar(
                title: const Text(
                  'Droits et permissions',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.white),
                ),
                centerTitle: true,
                elevation: 0,
                foregroundColor: Colors.white,
                backgroundColor: AppColors.primaryColor,
                bottom: const TabBar(
                  indicatorColor: Colors.white,
                  indicatorWeight: 3,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                  labelStyle: TextStyle(fontWeight: FontWeight.bold),
                  tabs: [
                    Tab(
                        icon: Icon(Icons.groups_rounded, size: 20),
                        text: 'Par rôle',
                        iconMargin: EdgeInsets.only(bottom: 2)),
                    Tab(
                        icon: Icon(Icons.person_search_rounded, size: 20),
                        text: 'Par utilisateur',
                        iconMargin: EdgeInsets.only(bottom: 2)),
                  ],
                ),
              ),
              body: _corps(context, state),
              bottomNavigationBar: state.modifie
                  ? BarreEnregistrementDroits(
                      enCours: state.enregistrement,
                      precision: _precision(state),
                      onAnnuler: () =>
                          context.read<PermissionsCubit>().annuler(),
                      onEnregistrer: () => _enregistrer(context, state),
                    )
                  : null,
            ),
          ),
        );
      },
    );
  }

  String _precision(PermissionsState state) {
    final parts = <String>[];
    if (state.ajoutes.isNotEmpty) parts.add('+${state.ajoutes.length}');
    if (state.retires.isNotEmpty) parts.add('−${state.retires.length}');
    final role = state.roleCourant?.libelle ?? '';
    return 'Rôle « $role »${parts.isEmpty ? '' : ' · ${parts.join(' / ')}'}';
  }

  Widget _corps(BuildContext context, PermissionsState state) {
    if (state.fetchStatus == AppStatus.loading && state.donnees == null) {
      return Center(child: MyLoadingIndicator());
    }
    if (state.fetchStatus == AppStatus.error && state.donnees == null) {
      return Center(
        child: MyErrorWidget(
          error: state.error ?? "Une erreur s'est produite",
          action: AppStrings.tryAgain,
          actionCLick: () => context.read<PermissionsCubit>().charger(),
        ),
      );
    }
    if (state.roles.isEmpty || state.modules.isEmpty) {
      return _vide(context, "Aucun droit n'est proposé par le serveur.");
    }
    return TabBarView(
      children: [
        _ongletRoles(context, state),
        _ongletUtilisateurs(context, state),
      ],
    );
  }

  Widget _vide(BuildContext context, String texte,
      {IconData icone = Icons.shield_outlined}) {
    return RefreshIndicator(
      onRefresh: () => context.read<PermissionsCubit>().charger(),
      child: ListView(
        children: [
          const SizedBox(height: 90),
          Icon(icone, size: 54, color: Colors.grey.shade400),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Text(
              texte,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }

  // ============================== Par rôle ==============================

  Widget _ongletRoles(BuildContext context, PermissionsState state) {
    final role = state.roleCourant;
    final modifiable = role?.modifiableIci ?? false;
    final requete = normaliserRecherche(_requete);
    final enRecherche = requete.isNotEmpty;

    final cartes = <Widget>[];
    for (final m in state.modules) {
      final sous = filtrerSousModules(m, requete);
      if (sous.isEmpty) continue;
      cartes.add(_carteModuleRole(context, state, m, sous,
          modifiable: modifiable, enRecherche: enRecherche));
    }

    return Column(
      children: [
        _choixRole(context, state),
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
          child: Column(
            children: [
              ChampRechercheDroits(
                controller: _recherche,
                onChanged: (v) => setState(() => _requete = v),
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
        ),
        Divider(height: 1, color: Colors.grey.shade300),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => context.read<PermissionsCubit>().charger(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 26),
              children: [
                if (role != null && !modifiable) ...[
                  BandeauDroits(
                    icone: Icons.lock_outline_rounded,
                    texte: role.estAdministrateur
                        ? 'Administrateur : tous les droits, non modifiable.'
                        : 'Ce rôle ne peut pas être modifié.',
                  ),
                  const SizedBox(height: 10),
                ],
                if (role != null && modifiable) ...[
                  _resume(state),
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
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, size: 46, color: Colors.grey.shade400),
          const SizedBox(height: 10),
          Text(
            'Aucun droit ne correspond à la recherche.',
            style: TextStyle(fontSize: 13.5, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  Widget _carteModuleRole(
    BuildContext context,
    PermissionsState state,
    ModulePermissions m,
    List<SousModulePermissions> sous, {
    required bool modifiable,
    required bool enRecherche,
  }) {
    final cubit = context.read<PermissionsCubit>();
    final ouvert = enRecherche || _ouverts.contains(m.code);
    final coches = state.cochesParmi(m.codes);
    final enfants = <Widget>[];
    for (final s in sous) {
      final cle = '${m.code}/${s.code}';
      final sousOuvert = enRecherche || !_sousFermes.contains(cle);
      if (!m.sansSousModules) {
        enfants.add(EnTeteSousModule(
          sousModule: s,
          ouvert: sousOuvert,
          onOuvrir: () => setState(() {
            if (!_sousFermes.remove(cle)) _sousFermes.add(cle);
          }),
          compteur: CompteurDroits(
              n: state.cochesParmi(s.codes), total: s.codes.length, petit: true),
          action: modifiable
              ? CaseTout(
                  n: state.cochesParmi(s.codes),
                  total: s.codes.length,
                  onChanged: (actif) => cubit.basculerCodes(s.codes, actif),
                )
              : null,
        ));
      }
      if (sousOuvert || m.sansSousModules) {
        for (final p in s.permissions) {
          enfants.add(_ligneDroitRole(
            p,
            coche: state.estCoche(p.code),
            modifiable: modifiable,
            retrait: m.sansSousModules ? 14 : 30,
            onChanged: (v) => cubit.basculer(p.code, v),
          ));
        }
      }
    }
    return CarteModuleDroits(
      key: ValueKey('role-${m.code}'),
      module: m,
      ouvert: ouvert,
      onOuvrir: () => setState(() {
        if (!_ouverts.remove(m.code)) _ouverts.add(m.code);
      }),
      compteur: CompteurDroits(n: coches, total: m.codes.length),
      action: modifiable
          ? CaseTout(
              n: coches,
              total: m.codes.length,
              onChanged: (actif) => cubit.basculerCodes(m.codes, actif),
            )
          : const SizedBox(width: 6),
      enfants: enfants,
    );
  }

  Widget _ligneDroitRole(
    PermissionDroit p, {
    required bool coche,
    required bool modifiable,
    required double retrait,
    required ValueChanged<bool> onChanged,
  }) {
    return InkWell(
      onTap: modifiable ? () => onChanged(!coche) : null,
      child: Padding(
        padding: EdgeInsets.fromLTRB(retrait, 2, 6, 2),
        child: Row(
          children: [
            Expanded(
              child: Text(
                p.libelle,
                style: TextStyle(
                  fontSize: 13.5,
                  color: coche ? couleurTexteDroits : Colors.grey.shade700,
                ),
              ),
            ),
            const SizedBox(width: 6),
            PastilleAction(p.action),
            Transform.scale(
              scale: .82,
              child: Switch(
                value: coche,
                onChanged: modifiable ? onChanged : null,
                activeThumbColor: AppColors.primaryColor,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Les rôles en haut : libellé et nombre d'utilisateurs concernés.
  Widget _choixRole(BuildContext context, PermissionsState state) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 10),
      child: SizedBox(
        height: 58,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: state.roles.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final r = state.roles[i];
            final actif = r.nom == state.roleChoisi;
            final couleur =
                actif ? AppColors.primaryColor : Colors.grey.shade600;
            return InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => _choisirRole(context, state, r.nom),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: actif
                      ? AppColors.primaryColor.withValues(alpha: .10)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color:
                        actif ? AppColors.primaryColor : Colors.grey.shade300,
                    width: actif ? 1.4 : 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (r.estAdministrateur || !r.modifiable) ...[
                          Icon(Icons.lock_outline, size: 13, color: couleur),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          r.libelle,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight:
                                actif ? FontWeight.bold : FontWeight.w600,
                            color: actif
                                ? AppColors.primaryColor
                                : couleurTexteDroits,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: couleur.withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.person_rounded,
                                  size: 11, color: couleur),
                              const SizedBox(width: 2),
                              Text(
                                '${r.utilisateurs}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: couleur,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      r.estAdministrateur
                          ? 'Tous les droits'
                          : r.utilisateursLisible,
                      style:
                          TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Combien de droits sur combien, pour le rôle affiché.
  Widget _resume(PermissionsState state) {
    final total = state.donnees?.nombreDroits ?? 0;
    final n = state.selection.length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_user_outlined,
              size: 19, color: AppColors.primaryColor),
          const SizedBox(width: 9),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(
                  text: '$n',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(text: ' droit${n > 1 ? 's' : ''} sur $total'),
              ]),
              style: const TextStyle(fontSize: 13, color: couleurTexteDroits),
            ),
          ),
          if (state.modifie) const BadgeNonEnregistre(),
        ],
      ),
    );
  }

  // =========================== Par utilisateur ==========================

  Widget _ongletUtilisateurs(BuildContext context, PermissionsState state) {
    final requete = normaliserRecherche(_requeteUtilisateurs);
    final liste = state.utilisateurs.where((u) {
      if (requete.isEmpty) return true;
      return normaliserRecherche(u.nom).contains(requete) ||
          normaliserRecherche(u.rolesLisibles).contains(requete);
    }).toList();

    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: ChampRechercheDroits(
            controller: _rechercheUtilisateurs,
            indication: 'Rechercher un utilisateur ou un rôle…',
            onChanged: (v) => setState(() => _requeteUtilisateurs = v),
          ),
        ),
        Divider(height: 1, color: Colors.grey.shade300),
        Expanded(
          child: state.utilisateurs.isEmpty
              ? _vide(context, 'Aucun utilisateur à afficher.',
                  icone: Icons.people_outline_rounded)
              : RefreshIndicator(
                  onRefresh: () => context.read<PermissionsCubit>().charger(),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 26),
                    children: [
                      const BandeauDroits(
                        icone: Icons.info_outline_rounded,
                        texte: "Chaque utilisateur reçoit les droits de son "
                            "rôle. Ouvrez-le pour lui accorder ou lui retirer "
                            "des droits précis.",
                      ),
                      const SizedBox(height: 10),
                      if (liste.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 30),
                          child: Text(
                            'Aucun utilisateur ne correspond à la recherche.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 13.5, color: Colors.grey.shade700),
                          ),
                        ),
                      ...liste.map((u) => _CarteUtilisateur(
                            utilisateur: u,
                            onTap: () => _ouvrirUtilisateur(context, u),
                          )),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

/// Une ligne de la liste « Par utilisateur ».
class _CarteUtilisateur extends StatelessWidget {
  final UtilisateurPermissions utilisateur;
  final VoidCallback onTap;

  const _CarteUtilisateur({required this.utilisateur, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final u = utilisateur;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: u.verrouille
                    ? Colors.blueGrey.shade50
                    : AppColors.primaryColor.withValues(alpha: .12),
                child: Text(
                  u.initiales,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: u.verrouille
                        ? Colors.blueGrey.shade700
                        : AppColors.primaryColor,
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      u.nom,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: couleurTexteDroits,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      u.rolesLisibles,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              if (u.verrouille)
                _pastille(
                  icone: Icons.lock_rounded,
                  texte: 'Tous les droits',
                  couleur: Colors.blueGrey.shade600,
                )
              else if (u.personnalise)
                _pastille(
                  icone: Icons.tune_rounded,
                  texte: 'Personnalisé  +${u.accordes} / −${u.retires}',
                  couleur: Colors.orange.shade800,
                ),
              Icon(Icons.chevron_right_rounded, color: Colors.grey.shade500),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pastille({
    required IconData icone,
    required String texte,
    required Color couleur,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 12, color: couleur),
          const SizedBox(width: 3),
          Text(
            texte,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: couleur),
          ),
        ],
      ),
    );
  }
}
