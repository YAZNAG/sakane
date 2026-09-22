import 'package:flutter/material.dart';
import 'package:immobilier/components/ligne_commentaire.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/utils/show_toast.dart';
import 'package:immobilier/features/caisses/cubit/caisse_airbnb_cubit.dart';
import 'package:immobilier/features/caisses/ui/components/historique_par_jour.dart';
import 'package:immobilier/features/caisses/ui/components/motifs_caisse.dart';
import 'package:immobilier/features/caisses/ui/components/section_caisse.dart';
import 'package:immobilier/models/caisse.dart';
import 'package:immobilier/routes.dart';
import 'package:toastification/toastification.dart';

/// Le rose d'Airbnb : la caisse se reconnaît d'un coup d'œil.
const Color couleurCaisseAirbnb = Color(0xFFFF5A5F);

/// La carte « Caisse Airbnb » de l'écran des caisses.
class CarteCaisseAirbnb extends StatelessWidget {
  final CaisseAirbnb caisse;
  final VoidCallback onTap;

  const CarteCaisseAirbnb({super.key, required this.caisse, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: couleurCaisseAirbnb.withValues(alpha: .45)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: couleurCaisseAirbnb.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const FaIcon(FontAwesomeIcons.airbnb,
                    color: couleurCaisseAirbnb, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(caisse.nom,
                        style: const TextStyle(
                            fontSize: 14.5, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 3),
                    Text(
                      "Encaissé ${montantCaisseAirbnb(caisse.totalEncaisse)}"
                      " · transféré ${montantCaisseAirbnb(caisse.totalTransfere)}",
                      maxLines: 2,
                      style: TextStyle(
                          fontSize: 11.5, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                montantCaisseAirbnb(caisse.solde),
                style: styleMontantCaisse(
                  taille: 15,
                  couleur: caisse.solde > 0.005
                      ? couleurCaisseAirbnb
                      : couleurTexteDouxCaisse,
                ),
              ),
              const SizedBox(width: 2),
              Icon(Icons.chevron_right, size: 18, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}

/// Le détail de la caisse Airbnb : son solde, ses mouvements, et le
/// transfert vers une autre caisse.
class CaisseAirbnbPage extends StatelessWidget {
  const CaisseAirbnbPage({super.key});

  static Widget page() => BlocProvider(
        create: (_) => CaisseAirbnbCubit()..charger(),
        child: const CaisseAirbnbPage(),
      );

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CaisseAirbnbCubit, CaisseAirbnbState>(
      listenWhen: (a, b) => a.action != b.action,
      listener: (context, state) {
        if (state.action == AppStatus.success && state.message != null) {
          showToast(state.message!, context, second: 3);
        }
      },
      builder: (context, state) {
        final cubit = context.read<CaisseAirbnbCubit>();
        final caisse = state.caisse;

        Widget corps;
        if (caisse == null && state.chargement == AppStatus.error) {
          corps = RefreshIndicator(
            onRefresh: cubit.charger,
            child: ListView(
              children: [
                _Message(
                  icone: Icons.wifi_off,
                  titre: "Caisse Airbnb indisponible",
                  detail:
                      state.erreur ?? "Vérifiez la connexion, puis réessayez.",
                ),
              ],
            ),
          );
        } else if (caisse == null) {
          corps = const SqueletteCaisse(sections: 2);
        } else {
          corps = RefreshIndicator(
            onRefresh: cubit.charger,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
              children: [
                _EnTete(caisse: caisse),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: caisse.solde <= 0.005 ||
                            !peutTransfererCaisseAirbnb ||
                            state.action == AppStatus.loading
                        ? null
                        : () => _transferer(context, caisse),
                    icon: const Icon(Icons.move_up, size: 19),
                    label: const Text("Transférer"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: couleurCaisseAirbnb,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: couleurCaisseAirbnb.withValues(alpha: .1),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Icon(Icons.receipt_long_outlined,
                          size: 17, color: couleurCaisseAirbnb),
                    ),
                    const SizedBox(width: 9),
                    const Expanded(
                      child: Text("Historique",
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: couleurTexteCaisse)),
                    ),
                    Text(
                        "${caisse.mouvements.length} opération"
                        "${caisse.mouvements.length > 1 ? 's' : ''} "
                        "· 3 derniers mois",
                        style: const TextStyle(
                            fontSize: 11.5, color: couleurTexteDouxCaisse)),
                  ],
                ),
                const SizedBox(height: 8),
                if (caisse.mouvements.isEmpty)
                  const _Message(
                    icone: Icons.receipt_long_outlined,
                    titre: "Aucun mouvement",
                    detail: "Les séjours payés sur Airbnb et les transferts "
                        "apparaîtront ici.",
                  )
                else
                  HistoriqueParJour<MouvementCaisseAirbnb>(
                    elements: caisse.mouvements,
                    date: (m) => m.date,
                    estEntree: (m) => m.estEntree,
                    montant: (m) => m.montant,
                    ligne: (_, m) => _LigneMouvementAirbnb(
                        mouvement: m, nomCaisse: caisse.nom),
                  ),
              ],
            ),
          );
        }

        return Scaffold(
          backgroundColor: couleurFondCaisse,
          appBar: AppBar(
            title: const Text("Caisse Airbnb",
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.white)),
            centerTitle: true,
            elevation: 0,
            foregroundColor: Colors.white,
            backgroundColor: couleurCaisseAirbnb,
          ),
          body: corps,
        );
      },
    );
  }
}

// ── Le solde ────────────────────────────────────────────────────────

class _EnTete extends StatelessWidget {
  final CaisseAirbnb caisse;

  const _EnTete({required this.caisse});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color.lerp(couleurCaisseAirbnb, const Color(0xFF5A1820), .35)!,
            couleurCaisseAirbnb,
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
              FaIcon(FontAwesomeIcons.airbnb,
                  size: 18, color: Colors.white.withValues(alpha: .9)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  caisse.nom,
                  style: TextStyle(
                      fontSize: 13, color: Colors.white.withValues(alpha: .85)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            "Solde disponible",
            style: TextStyle(
                fontSize: 12, color: Colors.white.withValues(alpha: .75)),
          ),
          const SizedBox(height: 4),
          Text(
            montantCaisseAirbnb(caisse.solde),
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.bold,
              height: 1.05,
              fontFeatures: chiffresAlignesCaisse,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _Total(
                    libelle: "Total encaissé",
                    valeur: montantCaisseAirbnb(caisse.totalEncaisse)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Total(
                    libelle: "Total transféré",
                    valeur: montantCaisseAirbnb(caisse.totalTransfere)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Total extends StatelessWidget {
  final String libelle;
  final String valeur;

  const _Total({required this.libelle, required this.valeur});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .16),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(libelle,
              style: TextStyle(
                  fontSize: 11, color: Colors.white.withValues(alpha: .8))),
          const SizedBox(height: 2),
          Text(valeur,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: styleMontantCaisse(taille: 13.5, couleur: Colors.white)),
        ],
      ),
    );
  }
}

// ── Les mouvements ──────────────────────────────────────────────────

class _LigneMouvementAirbnb extends StatelessWidget {
  final MouvementCaisseAirbnb mouvement;

  final String nomCaisse;

  const _LigneMouvementAirbnb(
      {required this.mouvement, required this.nomCaisse});

  void _detail(BuildContext context) {
    final m = mouvement;
    final entree = m.estEntree;
    final booking = m.bookingId;

    afficherDetailOperation(
      context,
      titre: m.libelle.isEmpty ? (entree ? "Entrée" : "Sortie") : m.libelle,
      montant: "${entree ? '+' : '−'} ${montantCaisseAirbnb(m.montant)}",
      couleur: entree ? couleurEntreeCaisse : couleurSortieCaisse,
      icone: entree ? Icons.south_west : Icons.north_east,
      statut: entree ? "Entrée" : "Sortie",
      infos: [
        InfoDetail("Date", dateHeureCaisse(m.date), icone: Icons.schedule),
        InfoDetail("Par", m.par ?? "Automatique",
            icone: Icons.person_outline),
        InfoDetail("Caisse", nomCaisse,
            icone: Icons.account_balance_wallet_outlined),
        if (booking != null)
          InfoDetail("Réservation", "n° $booking",
              icone: Icons.event_available_outlined),
      ],
      commentaires: [CommentaireDetail("Commentaire", m.commentaire)],
      actions: [
        if (booking != null)
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              GoRouter.of(context).push(
                  Routes.detailReservation.replaceFirst(':id', '$booking'));
            },
            icon: const Icon(Icons.open_in_new, size: 17),
            label: const Text("Voir la réservation"),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final entree = mouvement.estEntree;
    final couleur = couleurSensCaisse(entree);
    final booking = mouvement.bookingId;

    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE2E8EC)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _detail(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: couleur.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                    booking != null
                        ? Icons.event_available_outlined
                        : (entree ? Icons.south_west : Icons.north_east),
                    size: 17,
                    color: couleur),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        mouvement.libelle.isEmpty
                            ? (entree ? "Entrée" : "Sortie")
                            : mouvement.libelle,
                        style: const TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(mouvement.date == null ? "—" : heureCaisse(mouvement.date!),
                        style: TextStyle(
                            fontSize: 11.5, color: Colors.grey.shade600)),
                    LigneCommentaire(mouvement.commentaire,
                        taille: 11.5,
                        marge: const EdgeInsets.only(top: 3, bottom: 1)),
                    if (mouvement.par != null)
                      Text("par ${mouvement.par}",
                          style: TextStyle(
                              fontSize: 11.5, color: Colors.grey.shade600)),
                    if (booking != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text("Réservation n° $booking",
                            style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: couleurCaisseAirbnb)),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                "${entree ? '+' : '−'} ${montantCaisseAirbnb(mouvement.montant)}",
                style: styleMontantCaisse(couleur: couleur),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icone;
  final String titre;
  final String detail;

  const _Message(
      {required this.icone, required this.titre, required this.detail});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 20),
      child: Column(
        children: [
          Icon(icone, size: 46, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(titre,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700)),
          const SizedBox(height: 6),
          Text(detail,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}

// ── Le transfert ────────────────────────────────────────────────────

Future<void> _transferer(BuildContext context, CaisseAirbnb caisse) async {
  if (caisse.destinations.isEmpty) {
    showToast("Aucune caisse n'est disponible pour recevoir le transfert.",
        context,
        type: ToastificationType.warning);
    return;
  }

  final cubit = context.read<CaisseAirbnbCubit>();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: _FeuilleTransfert(caisse: caisse),
    ),
  );
}

/// La même feuille, depuis un écran qui n'a pas le cubit de la caisse
/// Airbnb : il est créé le temps de la feuille, puis refermé.
///
/// Rend vrai lorsque le transfert a eu lieu : l'écran appelant sait
/// alors qu'il doit relire ses soldes.
Future<bool> ouvrirTransfertCaisseAirbnb(
    BuildContext context, CaisseAirbnb caisse) async {
  if (caisse.destinations.isEmpty) {
    showToast("Aucune caisse n'est disponible pour recevoir le transfert.",
        context,
        type: ToastificationType.warning);
    return false;
  }

  final cubit = CaisseAirbnbCubit();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: _FeuilleTransfert(caisse: caisse),
    ),
  );

  final fait = cubit.state.action == AppStatus.success;
  await cubit.close();
  return fait;
}

class _FeuilleTransfert extends StatefulWidget {
  final CaisseAirbnb caisse;

  const _FeuilleTransfert({required this.caisse});

  @override
  State<_FeuilleTransfert> createState() => _FeuilleTransfertState();
}

class _FeuilleTransfertState extends State<_FeuilleTransfert> {
  late final TextEditingController _montant;
  final _commentaire = TextEditingController();
  CaisseDestinataire? _vers;
  String? _erreur;
  bool _envoi = false;

  @override
  void initState() {
    super.initState();
    final solde = widget.caisse.solde;
    _montant = TextEditingController(
        text: solde.toStringAsFixed(2).replaceAll(RegExp(r"\.00$"), ""));
    // La caisse de l'agence est le cas courant : proposée d'emblée.
    _vers = widget.caisse.destinations.firstWhere((d) => d.principale,
        orElse: () => widget.caisse.destinations.first);
  }

  @override
  void dispose() {
    _montant.dispose();
    _commentaire.dispose();
    super.dispose();
  }

  Future<void> _valider() async {
    final montant =
        double.tryParse(_montant.text.trim().replaceAll(",", ".")) ?? 0;
    final solde = widget.caisse.solde;

    if (_vers == null) {
      setState(() => _erreur = "Choisissez la caisse qui reçoit.");
      return;
    }
    if (montant <= 0) {
      setState(() => _erreur = "Indiquez le montant à transférer.");
      return;
    }
    if (montant > solde + 0.005) {
      setState(() => _erreur =
          "La caisse Airbnb contient ${montantCaisseAirbnb(solde)}.");
      return;
    }

    setState(() {
      _erreur = null;
      _envoi = true;
    });
    final cubit = context.read<CaisseAirbnbCubit>();
    final commentaire = _commentaire.text.trim();
    final ok = await cubit.transferer(
      caisse: _vers!.id,
      montant: montant,
      commentaire: commentaire.isEmpty ? null : commentaire,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _envoi = false;
        _erreur = cubit.state.erreur ?? "Le transfert n'a pas abouti.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            18, 18, 18, 14 + MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  FaIcon(FontAwesomeIcons.airbnb,
                      color: couleurCaisseAirbnb, size: 20),
                  SizedBox(width: 9),
                  Text("Transférer depuis la caisse Airbnb",
                      style: TextStyle(
                          fontSize: 16.5, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                "Disponible : ${montantCaisseAirbnb(widget.caisse.solde)}. "
                "La somme sort de la caisse Airbnb et entre aussitôt dans "
                "la caisse choisie.",
                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<CaisseDestinataire>(
                initialValue: _vers,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: "Vers la caisse",
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: widget.caisse.destinations
                    .map((d) => DropdownMenuItem(
                          value: d,
                          child: Text(
                              d.principale ? "${d.nom} (principale)" : d.nom,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: _envoi ? null : (v) => setState(() => _vers = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _montant,
                enabled: !_envoi,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r"[0-9.,]")),
                ],
                decoration: const InputDecoration(
                  labelText: "Montant",
                  suffixText: "MAD",
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _commentaire,
                enabled: !_envoi,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: "Commentaire (facultatif)",
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              if (_erreur != null) ...[
                const SizedBox(height: 10),
                Text(_erreur!,
                    style: const TextStyle(
                        color: Color(0xFFB3261E), fontSize: 12.5)),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _envoi ? null : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13)),
                      child: const Text("Annuler"),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _envoi ? null : _valider,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: couleurCaisseAirbnb,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      child: _envoi
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text("Confirmer le transfert"),
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
}

// ── Mise en forme ───────────────────────────────────────────────────

String montantCaisseAirbnb(double m) {
  final entier = m.abs().truncate();
  final decimales = ((m.abs() - entier) * 100).round();
  final chiffres = entier.toString();

  final tampon = StringBuffer();
  for (int i = 0; i < chiffres.length; i++) {
    if (i > 0 && (chiffres.length - i) % 3 == 0) tampon.write(" ");
    tampon.write(chiffres[i]);
  }

  final signe = m < 0 ? "− " : "";
  final fraction =
      decimales == 0 ? "" : ",${decimales.toString().padLeft(2, '0')}";
  return "$signe$tampon$fraction MAD";
}
