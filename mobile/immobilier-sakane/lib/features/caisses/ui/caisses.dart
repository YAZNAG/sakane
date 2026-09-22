import 'package:immobilier/routes.dart';
import 'package:immobilier/core/utils/droits.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:immobilier/components/ligne_commentaire.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/utils/show_toast.dart';
import 'package:immobilier/features/caisses/cubit/caisse_cubit.dart';
import 'package:immobilier/models/caisse.dart';
import 'package:toastification/toastification.dart';
import 'package:immobilier/features/caisses/ui/historique_caisse.dart';
import 'package:immobilier/features/caisses/cubit/caisse_airbnb_cubit.dart';
import 'package:immobilier/features/caisses/ui/caisse_airbnb.dart';
import 'package:immobilier/features/caisses/ui/components/historique_par_jour.dart';
import 'package:immobilier/features/caisses/ui/components/ligne_mouvement_caisse.dart';
import 'package:immobilier/features/caisses/ui/components/motifs_caisse.dart';
import 'package:immobilier/features/caisses/ui/components/section_caisse.dart';

/// La caisse : ce que l'agent détient, ce qu'il remet à l'agence.
///
/// L'écran est fait de blocs qu'on ouvre et qu'on ferme : le solde et
/// ses boutons, les caisses des collègues, les transferts, le journal.
/// Tout ouvert, l'écran serait un mur ; chaque en-tête dit donc ce que
/// son bloc contient — un nombre, un total — pour qu'on sache s'il vaut
/// la peine de l'ouvrir.
class CaissesPage extends StatefulWidget {
  const CaissesPage({super.key});

  static Widget page() => BlocProvider(
        create: (_) => CaisseCubit()..charger(),
        child: const CaissesPage(),
      );

  @override
  State<CaissesPage> createState() => _CaissesPageState();
}

class _CaissesPageState extends State<CaissesPage> {
  /// Les sections que l'on a ouvertes ou fermées à la main.
  ///
  /// Tenu par l'écran, non par les sections : un rechargement de la
  /// liste ne referme donc pas ce que l'on venait d'ouvrir.
  final _ouvertes = <String, bool>{};

  bool _estOuverte(String cle, bool defaut) => _ouvertes[cle] ?? defaut;

  void _basculer(String cle, bool defaut) =>
      setState(() => _ouvertes[cle] = !_estOuverte(cle, defaut));

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CaisseCubit, CaisseState>(
      listenWhen: (a, b) => a.action != b.action,
      listener: (context, state) {
        if (state.action == AppStatus.success && state.message != null) {
          showToast(state.message!, context, second: 3);
        } else if (state.action == AppStatus.error) {
          showToast("Opération refusée", context,
              description: state.erreur ?? "Réessayez.",
              type: ToastificationType.error,
              second: 5);
        }
      },
      builder: (context, state) {
        final cubit = context.read<CaisseCubit>();

        Widget corps;
        if (state.maCaisse == null &&
            state.chargement == AppStatus.loading) {
          corps = const SqueletteCaisse();
        } else if (state.maCaisse == null &&
            state.chargement == AppStatus.error) {
          corps = RefreshIndicator(
            onRefresh: cubit.charger,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
              children: [
                Icon(Icons.wifi_off, size: 46, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                const Text("Caisse indisponible",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: couleurTexteCaisse)),
                const SizedBox(height: 6),
                Text(
                  state.erreur ?? "Vérifiez la connexion, puis réessayez.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 13, color: couleurTexteDouxCaisse),
                ),
              ],
            ),
          );
        } else {
          corps = RefreshIndicator(
            onRefresh: cubit.charger,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
              children: _sections(context, state, cubit),
            ),
          );
        }

        return Scaffold(
          backgroundColor: couleurFondCaisse,
          appBar: AppBar(
            title: const Text("Caisse",
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.white)),
            centerTitle: true,
            elevation: 0,
            foregroundColor: Colors.white,
            backgroundColor: AppColors.primaryColor,
            actions: [
              if (peut(AppPermission.viewCashboxHistory))
                IconButton(
                  tooltip: "Journal de caisse",
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => HistoriqueCaissePage.page(
                          nomCaisse: state.maCaisse?.nom),
                    ),
                  ),
                  icon: const Icon(Icons.history, color: Colors.white),
                ),
            ],
          ),
          body: corps,
        );
      },
    );
  }

  // ── Les blocs de l'écran ──────────────────────────────────────────

  List<Widget> _sections(
      BuildContext context, CaisseState state, CaisseCubit cubit) {
    final maCaisse = state.maCaisse;
    final sections = <Widget>[];

    // ── Ma caisse : le solde, puis ce qu'on peut en faire ──
    if (maCaisse != null) {
      sections.add(SectionCaisse(
        icone: Icons.account_balance_wallet_outlined,
        titre: "Ma caisse",
        compteur: !maCaisse.ouverte
            ? "Aucune caisse ouverte"
            : (maCaisse.numero == null
                ? maCaisse.nom
                : "${maCaisse.nom} — caisse n° ${maCaisse.numero}"),
        total: montantCaisseTexte(maCaisse.solde),
        couleurTotal: maCaisse.solde < 0 ? couleurAlerteCaisse : null,
        ouverte: _estOuverte(_cleMaCaisse, true),
        onBascule: () => _basculer(_cleMaCaisse, true),
        enfant: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _CarteSolde(caisse: maCaisse),
            const SizedBox(height: 12),
            _Actions(caisse: maCaisse),
          ],
        ),
      ));
    }

    // ── Toutes les caisses : réservé à qui suit celles des autres ──
    if (peut(AppPermission.viewAllCashboxes) && state.caisses.isNotEmpty) {
      final total = state.caisses.fold<double>(0, (t, c) => t + c.solde);
      sections.add(SectionCaisse(
        icone: Icons.account_balance_outlined,
        titre: "Toutes les caisses",
        compteur: "${state.caisses.length} caisse"
            "${state.caisses.length > 1 ? 's' : ''}",
        total: montantCaisseTexte(total),
        ouverte: _estOuverte(_cleToutes, false),
        onBascule: () => _basculer(_cleToutes, false),
        enfant: _ToutesLesCaisses(caisses: state.caisses),
      ));
    }

    // ── À confirmer : chacun de ces transferts attend une action ──
    final aConfirmer = maCaisse?.aConfirmer ?? const <TransfertAConfirmer>[];
    if (aConfirmer.isNotEmpty) {
      final total = aConfirmer.fold<double>(0, (t, x) => t + x.montantDeclare);
      sections.add(SectionCaisse(
        icone: Icons.mark_email_unread_outlined,
        teinte: couleurAttenteCaisse,
        titre: "À confirmer",
        compteur: "${aConfirmer.length} transfert"
            "${aConfirmer.length > 1 ? 's' : ''} reçu"
            "${aConfirmer.length > 1 ? 's' : ''}",
        total: montantCaisseTexte(total),
        couleurTotal: couleurAttenteCaisse,
        ouverte: _estOuverte(_cleAConfirmer, true),
        onBascule: () => _basculer(_cleAConfirmer, true),
        // Regroupés par jour, mais tous ouverts : chacun attend une
        // confirmation.
        enfant: HistoriqueParJour<TransfertAConfirmer>(
          elements: aConfirmer,
          date: (t) => t.declareLe,
          montant: (t) => t.montantDeclare,
          unite: "transfert",
          toutOuvrir: true,
          ligne: (_, t) =>
              _CarteAConfirmer(transfert: t, destinataire: maCaisse!.nom),
        ),
      ));
    }

    // ── Mes transferts : ce que j'ai envoyé, confirmé ou non ──
    final remises = maCaisse?.remises ?? const <RemiseCaisse>[];
    if (remises.isNotEmpty) {
      final attente = remises.where((r) => r.enAttente).toList();
      final totalAttente =
          attente.fold<double>(0, (t, r) => t + r.montantDeclare);
      sections.add(SectionCaisse(
        icone: Icons.move_up,
        titre: "Mes transferts",
        compteur: attente.isEmpty
            ? "${remises.length} transfert"
                "${remises.length > 1 ? 's' : ''} — aucun en attente"
            : "${attente.length} en attente sur ${remises.length}",
        total: attente.isEmpty ? null : montantCaisseTexte(totalAttente),
        couleurTotal: couleurAttenteCaisse,
        ouverte: _estOuverte(_cleTransferts, false),
        onBascule: () => _basculer(_cleTransferts, false),
        enfant: HistoriqueParJour<RemiseCaisse>(
          elements: remises.take(12).toList(),
          date: (r) => r.declareLe ?? r.confirmeLe,
          montant: (r) => r.montantDeclare,
          unite: "transfert",
          ligne: (_, r) =>
              _LigneRemise(remise: r, expediteur: maCaisse!.nom),
        ),
      ));
    }

    // ── La caisse Airbnb reçoit seule les séjours payés sur Airbnb ──
    final airbnb = state.caisseAirbnb;
    if (airbnb != null && estAdminCaisseAirbnb) {
      sections.add(SectionCaisse(
        icone: Icons.holiday_village_outlined,
        teinte: couleurCaisseAirbnb,
        titre: "Caisse Airbnb",
        compteur: "Séjours payés sur Airbnb",
        total: montantCaisseTexte(airbnb.solde),
        couleurTotal:
            airbnb.solde > 0.005 ? couleurCaisseAirbnb : null,
        ouverte: _estOuverte(_cleAirbnb, true),
        onBascule: () => _basculer(_cleAirbnb, true),
        enfant: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CarteCaisseAirbnb(
              caisse: airbnb,
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => CaisseAirbnbPage.page()),
                );
                // Un transfert a pu remplir une autre caisse.
                await cubit.charger();
              },
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: airbnb.solde <= 0.005 || !peutTransfererCaisseAirbnb
                  ? null
                  : () async {
                      final fait =
                          await ouvrirTransfertCaisseAirbnb(context, airbnb);
                      if (fait) await cubit.charger();
                    },
              icon: const Icon(Icons.move_up, size: 18),
              label: const Text("Transférer"),
              style: ElevatedButton.styleFrom(
                backgroundColor: couleurCaisseAirbnb,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ],
        ),
      ));
    }

    // ── Historique : les opérations de la caisse en cours ──
    final journal = _journalDeLaCaisse(state);
    final operations = journal.operations;
    if (maCaisse != null || operations.isNotEmpty) {
      final duJour = operations
          .where((m) => m.effectueLe != null && _estAujourdhui(m.effectueLe!))
          .length;

      sections.add(SectionCaisse(
        icone: Icons.receipt_long_outlined,
        titre: "Historique",
        compteur: operations.isEmpty
            ? "Aucune opération"
            : (duJour > 0
                ? "$duJour aujourd'hui — ${operations.length} dans cette caisse"
                : "${operations.length} opération"
                    "${operations.length > 1 ? 's' : ''} dans cette caisse"),
        ouverte: _estOuverte(_cleHistorique, false),
        onBascule: () => _basculer(_cleHistorique, false),
        enfant: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (operations.isEmpty)
              VideSectionCaisse(
                maCaisse?.ouverte == true
                    ? "Vos encaissements, apports et dépenses apparaîtront ici."
                    : "Ouvrez une caisse pour commencer à enregistrer vos "
                        "opérations.",
                icone: Icons.receipt_long_outlined,
              )
            else
              JournalParJourCaisse(
                mouvements: operations,
                nomCaisse: _nomComplet(maCaisse),
                solde: journal.solde,
              ),
            if (peut(AppPermission.viewCashboxHistory)) ...[
              const SizedBox(height: 4),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        HistoriqueCaissePage.page(nomCaisse: maCaisse?.nom),
                  ),
                ),
                icon: const Icon(Icons.history, size: 18),
                label: const Text("Voir tout l'historique"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryColor,
                  side: BorderSide(
                      color: AppColors.primaryColor.withValues(alpha: .5)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ],
          ],
        ),
      ));
    }

    return sections;
  }
}

const _cleMaCaisse = "ma-caisse";
const _cleToutes = "toutes-les-caisses";
const _cleAConfirmer = "a-confirmer";
const _cleTransferts = "mes-transferts";
const _cleAirbnb = "caisse-airbnb";
const _cleHistorique = "historique";

/// Les opérations de la caisse en cours, et le solde qui suit la plus
/// récente d'entre elles.
///
/// `/caisses/ma-caisse` porte le journal de la caisse ouverte : c'est là
/// que le serveur renvoie les apports et les saisies libres. Il est donc
/// la source première — l'écran ne l'affichait pas, et les apports
/// restaient invisibles. La caisse ouverte de `/caisses/sessions` la
/// complète : les deux listes se recouvrent, les doublons sont écartés
/// par leur identifiant. Faute de caisse ouverte, la dernière close
/// prend le relais, avec son propre solde.
({List<MouvementCaisse> operations, double? solde}) _journalDeLaCaisse(
    CaisseState state) {
  final vus = <int>{};
  final liste = <MouvementCaisse>[];

  void ajouter(Iterable<MouvementCaisse> source) {
    for (final m in source) {
      if (m.id != 0 && !vus.add(m.id)) continue;
      liste.add(m);
    }
  }

  ajouter(state.maCaisse?.mouvements ?? const []);

  final ouvertes = state.sessions.where((s) => s.ouverte).toList();
  if (ouvertes.isNotEmpty) {
    ajouter(ouvertes.first.mouvements);
  } else if (liste.isEmpty && state.sessions.isNotEmpty) {
    // Plus aucune caisse ouverte : le journal montré est celui de la
    // dernière, et les soldes se reconstituent depuis le sien.
    final derniere = state.sessions.first;
    ajouter(derniere.mouvements);
    return (
      operations: mouvementsTriesCaisse(liste),
      solde: derniere.solde,
    );
  }

  return (
    operations: mouvementsTriesCaisse(liste),
    solde: state.maCaisse?.solde,
  );
}

/// « Ali — caisse n° 4 », pour la fiche de détail d'une opération.
String _nomComplet(MaCaisse? caisse) {
  if (caisse == null) return "Ma caisse";
  return caisse.numero == null
      ? caisse.nom
      : "${caisse.nom} — caisse n° ${caisse.numero}";
}

bool _estAujourdhui(DateTime d) {
  final maintenant = DateTime.now();
  return d.year == maintenant.year &&
      d.month == maintenant.month &&
      d.day == maintenant.day;
}

// ── Le solde ────────────────────────────────────────────────────────

class _CarteSolde extends StatelessWidget {
  final MaCaisse caisse;

  const _CarteSolde({required this.caisse});

  @override
  Widget build(BuildContext context) {
    final negatif = caisse.solde < 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color.lerp(AppColors.primaryColor, const Color(0xFF0B2233), .42)!,
            AppColors.primaryColor,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_wallet_outlined,
                  size: 19, color: Colors.white.withValues(alpha: .85)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  caisse.numero == null
                      ? caisse.nom
                      : "${caisse.nom} — caisse n° ${caisse.numero}",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: .85)),
                ),
              ),
              if (!caisse.ouverte)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .16),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text("Aucune caisse ouverte",
                      style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            "Ce que vous devez avoir sur vous",
            style: TextStyle(
                fontSize: 12, color: Colors.white.withValues(alpha: .75)),
          ),
          const SizedBox(height: 4),
          Text(
            _montant(caisse.solde),
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.bold,
              height: 1.05,
              fontFeatures: chiffresAlignesCaisse,
              color: negatif ? const Color(0xFFFFC46B) : Colors.white,
            ),
          ),
          if (negatif) ...[
            const SizedBox(height: 8),
            Text(
              "Solde négatif : vous avez avancé de l'argent, ou un écart "
              "reste à régulariser.",
              style: TextStyle(
                  fontSize: 11.5,
                  height: 1.35,
                  color: Colors.white.withValues(alpha: .85)),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Les actions ─────────────────────────────────────────────────────

class _Actions extends StatelessWidget {
  final MaCaisse caisse;

  const _Actions({required this.caisse});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CaisseCubit>();

    if (!caisse.ouverte) {
      return ElevatedButton.icon(
        onPressed: () => _ouvrirNouvelleCaisse(context, caisse),
        icon: const Icon(Icons.play_circle_outline, size: 19),
        label: Text(caisse.aReporter > 0.005
            ? "Ouvrir une nouvelle caisse"
            : "Ouvrir ma caisse"),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      );
    }

    return _grilleActions([
      if (peutUn(const [AppPermission.cashIn, AppPermission.freeCashMovement]))
        _BoutonAction(
          icone: Icons.south_west,
          texte: "Encaisser",
          couleur: couleurEntreeCaisse,
          onTap: () => _demanderMontant(
            context,
            titre: "Encaisser",
            aide: "De l'argent reçu d'un client : le solde d'une "
                "réservation, par exemple.",
            libelleAction: "Encaisser",
            avecCommentaire: true,
            onValide: cubit.encaisserSolde,
          ),
        ),
      if (peutUn(const [
        AppPermission.cashContribution,
        AppPermission.freeCashMovement
      ]))
        _BoutonAction(
          icone: Icons.savings_outlined,
          texte: "Apport",
          couleur: couleurEntreeCaisse,
          plein: false,
          onTap: () => _demanderMontant(
            context,
            titre: "Apport",
            aide: "De l'argent que vous ajoutez vous-même à la caisse.",
            libelleAction: "Ajouter",
            avecCommentaire: true,
            onValide: cubit.ajouterApport,
          ),
        ),
      // Une dépense est une charge : elle se saisit là où les charges se
      // saisissent, avec son bien et son document.
      if (peut(AppPermission.cashExpense) && peut(AppPermission.createCharge))
        _BoutonAction(
          icone: Icons.north_east,
          texte: "Dépense",
          couleur: couleurSortieCaisse,
          onTap: () => GoRouter.of(context).push(Routes.addCharge),
        ),
      if (peut(AppPermission.cashTransfer))
        _BoutonAction(
          icone: Icons.move_up,
          texte: "Transférer",
          couleur: AppColors.primaryColor,
          // Une caisse vide n'a rien à transférer : le bouton reste, la
          // situation le suspend.
          onTap: caisse.solde <= 0 ? null : () => _transferer(context, caisse),
        ),
      if (peut(AppPermission.closeCashbox))
        _BoutonAction(
          icone: Icons.fact_check_outlined,
          texte: "Clôturer",
          couleur: couleurEntreeCaisse,
          plein: false,
          // Une caisse ne se clôture qu'une fois vide : tant qu'elle
          // contient quelque chose, on explique au lieu d'ouvrir la
          // saisie pour rien.
          onTap: caisse.solde.abs() > 0.005
              ? () => _remettreAvantCloture(context, caisse.solde)
              : () => _demanderMontant(
                    context,
                    titre: "Clôturer la caisse",
                    aide: "Votre caisse est vide : tout a été remis. "
                        "Saisissez ce qu'il vous reste réellement en "
                        "main, normalement 0.",
                    libelleAction: "Clôturer",
                    valeurInitiale: 0,
                    minimum: 0,
                    avecCommentaire: true,
                    onValide: cubit.cloturer,
                  ),
        ),
    ]);
  }
}

/// Les boutons de la caisse, deux par ligne.
///
/// Un bouton dont le droit manque n'est pas grisé : il n'est pas
/// construit du tout. Les colonnes gardent leur largeur quel que soit
/// le nombre de boutons, pour qu'un bouton ne change pas de taille d'un
/// compte à l'autre.
Widget _grilleActions(List<Widget> boutons) {
  final lignes = <Widget>[];
  for (int i = 0; i < boutons.length; i += 2) {
    lignes.add(Padding(
      padding: EdgeInsets.only(top: i == 0 ? 0 : 10),
      child: Row(
        children: [
          Expanded(child: boutons[i]),
          const SizedBox(width: 10),
          Expanded(
            child: i + 1 < boutons.length
                ? boutons[i + 1]
                : const SizedBox.shrink(),
          ),
        ],
      ),
    ));
  }

  return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch, children: lignes);
}

/// Un bouton d'action de la caisse : plein pour ce qui déplace de
/// l'argent, cerné pour ce qui l'accompagne.
class _BoutonAction extends StatelessWidget {
  final IconData icone;
  final String texte;
  final Color couleur;
  final bool plein;

  /// Nul lorsque la situation suspend l'action.
  final VoidCallback? onTap;

  const _BoutonAction({
    required this.icone,
    required this.texte,
    required this.couleur,
    required this.onTap,
    this.plein = true,
  });

  @override
  Widget build(BuildContext context) {
    if (plein) {
      return ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icone, size: 18),
        label: Text(texte),
        style: ElevatedButton.styleFrom(
          backgroundColor: couleur,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 13),
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icone, size: 18),
      label: Text(texte),
      style: OutlinedButton.styleFrom(
        foregroundColor: couleur,
        side: BorderSide(color: couleur.withValues(alpha: .55)),
        padding: const EdgeInsets.symmetric(vertical: 13),
      ),
    );
  }
}

// ── Toutes les caisses, vues par le gerant ──────────────────────────

/// Les caisses de tous les collaborateurs, en lecture seule.
///
/// Un toucher ouvre l'historique de la caisse : ses caisses
/// successives et ses clôtures. Rien, ici, ne modifie la caisse d'un
/// autre.
class _ToutesLesCaisses extends StatelessWidget {
  final List<SoldeCaisse> caisses;

  const _ToutesLesCaisses({required this.caisses});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final c in caisses)
          _LigneCaisse(
            caisse: c,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    HistoriqueCaissePage.page(caisseId: c.id, nomCaisse: c.nom),
              ),
            ),
          ),
      ],
    );
  }
}

/// La caisse d'un collègue : son titulaire, son état, son solde.
class _LigneCaisse extends StatelessWidget {
  final SoldeCaisse caisse;
  final VoidCallback onTap;

  const _LigneCaisse({required this.caisse, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = caisse;
    final negatif = c.solde < -0.005;
    final teinte =
        c.estAgence ? AppColors.primaryColor : couleurTexteDouxCaisse;

    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
            color: negatif
                ? couleurAlerteCaisse.withValues(alpha: .4)
                : couleurBordureCaisse),
        borderRadius: BorderRadius.circular(10),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(11, 10, 8, 10),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: teinte.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  c.estAgence
                      ? Icons.account_balance_outlined
                      : Icons.person_outline,
                  size: 17,
                  color: teinte,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.nom,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            c.estAgence ? FontWeight.bold : FontWeight.w600,
                        color: couleurTexteCaisse,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "${c.estAgence ? "Caisse de l'agence" : "Caisse d'agent"}"
                      " — ${c.ouverte ? 'ouverte' : 'fermée'}",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: c.ouverte
                            ? couleurEntreeCaisse
                            : couleurTexteDouxCaisse,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    montantCaisseTexte(c.solde),
                    style: styleMontantCaisse(
                      couleur: negatif
                          ? couleurAlerteCaisse
                          : (c.solde > 0.005
                              ? couleurTexteCaisse
                              : couleurTexteDouxCaisse),
                    ),
                  ),
                  if (negatif) ...[
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 1),
                      decoration: BoxDecoration(
                        color: couleurAlerteCaisse.withValues(alpha: .1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text("négatif",
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: couleurAlerteCaisse)),
                    ),
                  ],
                ],
              ),
              Icon(Icons.chevron_right, size: 18, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Transférer des espèces ──────────────────────────────────────────

/// Demande à qui envoyer, combien, et la photo qui en atteste.
Future<void> _transferer(BuildContext context, MaCaisse caisse) async {
  final cubit = context.read<CaisseCubit>();
  final destinataires = cubit.state.destinataires;

  if (destinataires.isEmpty) {
    showToast("Aucune autre caisse n'est disponible pour le moment.", context,
        type: ToastificationType.warning);
    return;
  }

  await showDialog<void>(
    context: context,
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: _ATransfererDialogue(caisse: caisse, destinataires: destinataires),
    ),
  );
}

class _ATransfererDialogue extends StatefulWidget {
  final MaCaisse caisse;
  final List<CaisseDestinataire> destinataires;

  const _ATransfererDialogue({required this.caisse, required this.destinataires});

  @override
  State<_ATransfererDialogue> createState() => _ATransfererDialogueState();
}

class _ATransfererDialogueState extends State<_ATransfererDialogue> {
  final _montantSaisi = TextEditingController();

  /// Ce qui reste transférable : le solde, moins les transferts déjà
  /// annoncés qui attendent une confirmation.
  double get _disponible {
    final promis = widget.caisse.remises
        .where((r) => r.enAttente)
        .fold<double>(0, (t, r) => t + r.montantDeclare);

    final reste = widget.caisse.solde - promis;
    return reste > 0 ? reste : 0;
  }
  final _commentaire = TextEditingController();
  CaisseDestinataire? _vers;
  File? _piece;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    // La caisse de l'agence est le cas courant : elle est proposée
    // d'emblée quand elle figure dans la liste.
    _vers = widget.destinataires.firstWhere((d) => d.principale,
        orElse: () => widget.destinataires.first);
  }

  @override
  void dispose() {
    _montantSaisi.dispose();
    _commentaire.dispose();
    super.dispose();
  }

  Future<void> _choisirPhoto() async {
    final photo = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (photo != null) setState(() => _piece = File(photo.path));
  }

  Future<void> _choisirDansGalerie() async {
    final photo = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (photo != null) setState(() => _piece = File(photo.path));
  }

  void _valider() {
    final montant = double.tryParse(_montantSaisi.text.replaceAll(",", ".")) ?? 0;

    if (_vers == null) {
      setState(() => _erreur = "Choisissez la caisse qui reçoit.");
      return;
    }
    if (montant <= 0) {
      setState(() => _erreur = "Indiquez le montant à transférer.");
      return;
    }
    if (montant > _disponible + 0.005) {
      setState(() => _erreur = _disponible < widget.caisse.solde - 0.005
          ? "Vous disposez de ${_montant(_disponible)} : le reste est déjà "
              "annoncé et attend confirmation."
          : "Votre caisse contient ${_montant(widget.caisse.solde)}.");
      return;
    }

    Navigator.of(context).pop();
    context.read<CaisseCubit>().declarerRemise(
          montant,
          _commentaire.text.trim().isEmpty ? null : _commentaire.text.trim(),
          caisse: _vers!.id,
          piece: _piece,
        );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: const Text("Transférer des espèces", style: TextStyle(fontSize: 17)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "La somme reste dans votre caisse jusqu'à la confirmation du "
              "destinataire. Elle en sortira à ce moment-là, et entrera "
              "dans la sienne.",
              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<CaisseDestinataire>(
              value: _vers,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: "À qui",
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: widget.destinataires
                  .map((d) => DropdownMenuItem(
                        value: d,
                        child: Text(d.nom,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _vers = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _montantSaisi,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: InputDecoration(
                labelText: "Montant",
                suffixText: "MAD",
                helperText: "Disponible : ${_montant(_disponible)}",
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _commentaire,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: "Commentaire (facultatif)",
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            // La photo : un reçu, une enveloppe comptée. Le destinataire
            // la voit avant de confirmer.
            if (_piece != null)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: Image.file(_piece!, height: 110, fit: BoxFit.cover),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _choisirPhoto,
                    icon: const Icon(Icons.photo_camera_outlined, size: 17),
                    label: Text(_piece == null ? "Photo" : "Reprendre",
                        style: const TextStyle(fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _choisirDansGalerie,
                    icon: const Icon(Icons.photo_library_outlined, size: 17),
                    label: const Text("Galerie", style: TextStyle(fontSize: 13)),
                  ),
                ),
              ],
            ),
            if (_erreur != null) ...[
              const SizedBox(height: 10),
              Text(_erreur!,
                  style: const TextStyle(color: Color(0xFFB3261E), fontSize: 12.5)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text("Annuler"),
        ),
        ElevatedButton(
          onPressed: _valider,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryColor,
            foregroundColor: Colors.white,
          ),
          child: const Text("Transférer"),
        ),
      ],
    );
  }
}

// ── Les transferts reçus, à confirmer ───────────────────────────────

/// Un transfert qu'on vous a envoyé : son détail, sa photo, et le
/// montant que vous avez réellement compté.
class _CarteAConfirmer extends StatelessWidget {
  final TransfertAConfirmer transfert;

  /// La caisse qui reçoit : la sienne.
  final String destinataire;

  const _CarteAConfirmer({required this.transfert, required this.destinataire});

  void _detail(BuildContext context) {
    afficherDetailOperation(
      context,
      titre: "Transfert reçu",
      montant: montantCaisseTexte(transfert.montantDeclare),
      couleur: couleurAttenteCaisse,
      icone: Icons.move_to_inbox_outlined,
      statut: "En attente de votre confirmation",
      couleurStatut: couleurAttenteCaisse,
      infos: [
        InfoDetail("Expéditeur", transfert.caisse,
            icone: Icons.outbox_outlined),
        if (transfert.par != null)
          InfoDetail("Envoyé par", transfert.par!,
              icone: Icons.person_outline),
        InfoDetail("Destinataire", destinataire,
            icone: Icons.move_to_inbox_outlined),
        InfoDetail("Envoyé le", dateHeureCaisse(transfert.declareLe),
            icone: Icons.schedule),
      ],
      commentaires: [
        CommentaireDetail(
            "Commentaire de l'expéditeur", transfert.commentaire),
      ],
      actions: [
        if (transfert.piece != null)
          OutlinedButton.icon(
            onPressed: () => _voirPiece(context, transfert.piece!),
            icon: const Icon(Icons.image_outlined, size: 17),
            label: const Text("Voir la photo"),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Un toucher hors des boutons ouvre le détail complet.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _detail(context),
      child: _carte(context),
    );
  }

  Widget _carte(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E7),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: couleurAttenteCaisse.withValues(alpha: .4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.move_to_inbox_outlined,
                  size: 18, color: couleurAttenteCaisse),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "De ${transfert.caisse}",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              Text(
                _montant(transfert.montantDeclare),
                style: styleMontantCaisse(
                    taille: 15, couleur: couleurAttenteCaisse),
              ),
            ],
          ),
          if (transfert.declareLe != null) ...[
            const SizedBox(height: 4),
            Text(
              "Envoyé le ${transfert.declareLe!.day.toString().padLeft(2, '0')}/${transfert.declareLe!.month.toString().padLeft(2, '0')} à ${transfert.declareLe!.hour.toString().padLeft(2, '0')}:${transfert.declareLe!.minute.toString().padLeft(2, '0')}",
              style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
            ),
          ],
          LigneCommentaire(transfert.commentaire,
              taille: 12.5,
              couleur: Colors.grey.shade800,
              marge: const EdgeInsets.only(top: 6)),
          const SizedBox(height: 10),
          Row(
            children: [
              if (transfert.piece != null)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _voirPiece(context, transfert.piece!),
                    icon: const Icon(Icons.image_outlined, size: 17),
                    label: const Text("Voir la photo", style: TextStyle(fontSize: 13)),
                  ),
                ),
              if (transfert.piece != null) const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: !peut(AppPermission.confirmCashTransfer)
                      ? null
                      : () => _confirmer(context, transfert),
                  icon: const Icon(Icons.check, size: 17),
                  label: const Text("Confirmer", style: TextStyle(fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: couleurEntreeCaisse,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// La photo jointe, en grand.
void _voirPiece(BuildContext context, String url) {
  showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      insetPadding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InteractiveViewer(
            child: Image.network(
              url,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Padding(
                padding: EdgeInsets.all(24),
                child: Text("La photo n'a pas pu être chargée."),
              ),
              loadingBuilder: (_, enfant, progres) => progres == null
                  ? enfant
                  : const Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(),
                    ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Fermer"),
          ),
        ],
      ),
    ),
  );
}

/// Le destinataire compte ce qu'il a reçu : c'est ce montant qui entre.
void _confirmer(BuildContext context, TransfertAConfirmer transfert) {
  final cubit = context.read<CaisseCubit>();
  final montant = TextEditingController(
      text: transfert.montantDeclare.toStringAsFixed(2));
  final commentaire = TextEditingController();

  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: const Text("Confirmer le transfert", style: TextStyle(fontSize: 17)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "${transfert.caisse} vous a envoyé "
            "${_montant(transfert.montantDeclare)}. Comptez les espèces "
            "et indiquez ce que vous avez reçu : c'est ce montant qui entre "
            "dans votre caisse.",
            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: montant,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: "Montant reçu",
              suffixText: "MAD",
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: commentaire,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: "Commentaire (facultatif)",
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text("Annuler"),
        ),
        ElevatedButton(
          onPressed: () {
            final recu = double.tryParse(montant.text.replaceAll(",", ".")) ?? 0;
            Navigator.of(ctx).pop();
            cubit.confirmerRemise(
              transfert.id,
              recu,
              commentaire.text.trim().isEmpty ? null : commentaire.text.trim(),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2F6B4F),
            foregroundColor: Colors.white,
          ),
          child: const Text("Confirmer"),
        ),
      ],
    ),
  );
}

// ── Lignes ──────────────────────────────────────────────────────────

class _LigneRemise extends StatelessWidget {
  final RemiseCaisse remise;

  /// La caisse qui envoie : la sienne.
  final String expediteur;

  const _LigneRemise({required this.remise, required this.expediteur});

  String get _statut => remise.enAttente
      ? "En attente de confirmation"
      : (remise.ecart.abs() < 0.01 ? "Confirmée" : "Confirmée avec écart");

  void _detail(BuildContext context, Color couleurStatut) {
    final ecart = remise.ecart;
    afficherDetailOperation(
      context,
      titre: "Transfert envoyé",
      montant: "− ${montantCaisseTexte(remise.montantDeclare)}",
      couleur: couleurSortieCaisse,
      icone: Icons.north_east,
      statut: _statut,
      couleurStatut: couleurStatut,
      infos: [
        InfoDetail("Expéditeur", expediteur, icone: Icons.outbox_outlined),
        InfoDetail("Destinataire", remise.destination ?? "—",
            icone: Icons.move_to_inbox_outlined),
        InfoDetail("Envoyé le", dateHeureCaisse(remise.declareLe),
            icone: Icons.schedule),
        if (!remise.enAttente)
          InfoDetail("Confirmé le", dateHeureCaisse(remise.confirmeLe),
              icone: Icons.check_circle_outline),
        if (remise.confirmePar != null)
          InfoDetail("Confirmé par", remise.confirmePar!,
              icone: Icons.person_outline),
        if (remise.montantRecu != null)
          InfoDetail("Montant reçu", montantCaisseTexte(remise.montantRecu!),
              icone: Icons.payments_outlined),
        if (ecart.abs() >= 0.01)
          InfoDetail("Écart",
              "${ecart > 0 ? '+' : '−'} ${montantCaisseTexte(ecart.abs())}",
              icone: Icons.error_outline),
      ],
      commentaires: [
        CommentaireDetail("Commentaire de l'expéditeur", remise.commentaire),
        CommentaireDetail(
            "Commentaire de réception", remise.commentaireReception),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final ecart = remise.ecart;
    final couleurStatut = remise.enAttente
        ? couleurAttenteCaisse
        : (ecart.abs() >= 0.01 ? couleurAlerteCaisse : couleurEntreeCaisse);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _detail(context, couleurStatut),
      child: _ligne(context, ecart, couleurStatut),
    );
  }

  Widget _ligne(BuildContext context, double ecart, Color couleurStatut) {
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE2E8EC)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _statut,
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: couleurStatut),
                ),
                const SizedBox(height: 2),
                if (remise.destination?.isNotEmpty == true) ...[
                  Text(
                    "Vers ${remise.destination}",
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  _quand(remise.confirmeLe ?? remise.declareLe),
                  style:
                      TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                ),
                LigneCommentaire(remise.commentaire, taille: 11.5),
                if (LigneCommentaire.aContenu(remise.commentaireReception))
                  LigneCommentaire("Réception : ${remise.commentaireReception}",
                      taille: 11.5),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_montant(remise.montantDeclare),
                  style: styleMontantCaisse(couleur: couleurTexteCaisse)),
              if (ecart.abs() >= 0.01)
                Text(
                  "écart ${ecart > 0 ? '+' : '−'} ${_montant(ecart.abs())}",
                  style: styleMontantCaisse(
                      taille: 11.5,
                      poids: FontWeight.w600,
                      couleur: couleurAlerteCaisse),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Clôture : la caisse doit d'abord etre vide ──────────────────────

/// Explique pourquoi la clôture est refusée, plutôt que de laisser
/// l'agent saisir un montant pour se voir opposer une erreur ensuite.
Future<void> _remettreAvantCloture(BuildContext context, double solde) {
  return showDialog(
    context: context,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: const Text("Remettez d'abord votre caisse",
          style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Votre caisse contient encore ${_montant(solde)}.",
            style: TextStyle(fontSize: 13.5, color: Colors.grey.shade900),
          ),
          const SizedBox(height: 9),
          Text(
            "Une caisse ne se clôture qu'une fois vide. Transférez d'abord "
            "votre solde vers la caisse principale, puis revenez la clôturer.",
            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
          ),
        ],
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryColor,
            foregroundColor: Colors.white,
          ),
          child: const Text("J'ai compris"),
        ),
      ],
    ),
  );
}

// ── Ouverture d'une caisse ──────────────────────────────────────────

/// Ouvre la caisse suivante : en reportant ce qu'il restait, ou avec un
/// fond saisi.
///
/// Le report est proposé en premier parce que c'est le cas courant :
/// l'agent garde sur lui ce qu'il n'a pas remis.
Future<void> _ouvrirNouvelleCaisse(
    BuildContext context, MaCaisse caisse) async {
  final cubit = context.read<CaisseCubit>();

  // Rien à reporter : la première caisse se saisit directement.
  if (caisse.aReporter <= 0.005) {
    await _demanderMontant(
      context,
      titre: "Ouvrir ma caisse",
      aide: "Le montant que vous avez sur vous en commençant. "
          "Mettez 0 si vous partez de rien.",
      libelleAction: "Ouvrir",
      minimum: 0,
      onValide: (m, _) => cubit.ouvrir(montant: m),
    );
    return;
  }

  final choix = await showModalBottomSheet<String>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (feuille) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Ouvrir une nouvelle caisse",
                    style: TextStyle(
                        fontSize: 16.5, fontWeight: FontWeight.bold)),
                const SizedBox(height: 5),
                Text(
                  "Votre dernière clôture s'est arrêtée à "
                  "${_montant(caisse.aReporter)}.",
                  style:
                      TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
          const Divider(height: 14),
          ListTile(
            leading: Icon(Icons.move_down, color: AppColors.primaryColor),
            title: const Text("Reporter ce montant"),
            subtitle: Text(
              "La nouvelle caisse démarre à ${_montant(caisse.aReporter)}",
              style: const TextStyle(fontSize: 12),
            ),
            onTap: () => Navigator.of(feuille).pop("reporter"),
          ),
          ListTile(
            leading: Icon(Icons.edit_outlined, color: Colors.grey.shade700),
            title: const Text("Saisir un autre montant"),
            subtitle: const Text(
              "Si vous avez remis une partie ou tout à l'agence",
              style: TextStyle(fontSize: 12),
            ),
            onTap: () => Navigator.of(feuille).pop("saisir"),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );

  if (choix == "reporter") {
    cubit.ouvrir(reporter: true);
  } else if (choix == "saisir" && context.mounted) {
    await _demanderMontant(
      context,
      titre: "Fond de la nouvelle caisse",
      aide: "Le montant avec lequel vous démarrez cette caisse.",
      libelleAction: "Ouvrir",
      minimum: 0,
      onValide: (m, _) => cubit.ouvrir(montant: m),
    );
  }
}

// ── Saisie d'un montant ─────────────────────────────────────────────

Future<void> _demanderMontant(
  BuildContext context, {
  required String titre,
  required String aide,
  required String libelleAction,
  required void Function(double, String?) onValide,
  double? valeurInitiale,
  double? minimum,
  double? maximum,
  bool avecCommentaire = false,
}) async {
  final montant = TextEditingController(
      text: valeurInitiale == null
          ? ""
          : valeurInitiale.toStringAsFixed(2).replaceAll(RegExp(r"\.00$"), ""));
  final commentaire = TextEditingController();
  final cle = GlobalKey<FormState>();

  final valide = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(titre, style: const TextStyle(fontSize: 18)),
      content: Form(
        key: cle,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(aide,
                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700)),
            const SizedBox(height: 14),
            TextFormField(
              controller: montant,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r"[0-9.,]")),
              ],
              decoration: const InputDecoration(
                labelText: "Montant (MAD)",
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                final m = _lire(v);
                if (m == null) return "Saisissez un montant";
                if (minimum != null && m < minimum) {
                  return "Le montant ne peut pas être inférieur à $minimum";
                }
                if (minimum == null && m <= 0) {
                  return "Le montant doit être supérieur à zéro";
                }
                if (maximum != null && m > maximum + 0.001) {
                  return "Vous ne pouvez pas dépasser ${_montant(maximum)}";
                }
                return null;
              },
            ),
            if (avecCommentaire) ...[
              const SizedBox(height: 10),
              TextFormField(
                controller: commentaire,
                decoration: const InputDecoration(
                  labelText: "Commentaire (facultatif)",
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text("Annuler")),
        ElevatedButton(
          onPressed: () {
            if (cle.currentState?.validate() == true) {
              Navigator.of(ctx).pop(true);
            }
          },
          style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              foregroundColor: Colors.white),
          child: Text(libelleAction),
        ),
      ],
    ),
  );

  final m = _lire(montant.text);
  if (valide == true && m != null) {
    onValide(m, commentaire.text.trim().isEmpty ? null : commentaire.text.trim());
  }
}

/// Accepte la virgule comme le point : on saisit « 1250,50 » au Maroc.
double? _lire(String? texte) {
  if (texte == null || texte.trim().isEmpty) return null;
  return double.tryParse(texte.trim().replaceAll(",", "."));
}

String _montant(double m) {
  final entier = m.abs().truncate();
  final decimales = ((m.abs() - entier) * 100).round();
  final chiffres = entier.toString();

  // Séparateur de milliers par espace, comme sur les contrats.
  final tampon = StringBuffer();
  for (int i = 0; i < chiffres.length; i++) {
    if (i > 0 && (chiffres.length - i) % 3 == 0) tampon.write(" ");
    tampon.write(chiffres[i]);
  }

  final signe = m < 0 ? "− " : "";
  final fraction = decimales == 0 ? "" : ",${decimales.toString().padLeft(2, '0')}";
  return "$signe$tampon$fraction MAD";
}

String _quand(DateTime? d) {
  if (d == null) return "—";
  final maintenant = DateTime.now();
  final memeJour =
      d.year == maintenant.year && d.month == maintenant.month && d.day == maintenant.day;
  final heure =
      "${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}";

  if (memeJour) return "Aujourd'hui à $heure";
  return "${d.day.toString().padLeft(2, '0')}/"
      "${d.month.toString().padLeft(2, '0')}/${d.year} à $heure";
}
