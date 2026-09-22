import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

/// L'historique d'une caisse, regroupé par jour.
///
/// Chaque journée forme une section repliable : son en-tête donne la
/// date, le nombre d'opérations et ce qui est entré et sorti ce jour-là.
/// Seule la plus récente est ouverte d'emblée ; les autres attendent
/// qu'on les demande.

const couleurEntreeCaisse = Color(0xFF2F6B4F);
const couleurSortieCaisse = Color(0xFFA8542B);

// ── Les dates, en français ──────────────────────────────────────────

const _jours = [
  "lundi",
  "mardi",
  "mercredi",
  "jeudi",
  "vendredi",
  "samedi",
  "dimanche",
];

const _mois = [
  "janvier",
  "février",
  "mars",
  "avril",
  "mai",
  "juin",
  "juillet",
  "août",
  "septembre",
  "octobre",
  "novembre",
  "décembre",
];

bool _memeJour(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// « lundi 21 septembre », avec l'année quand ce n'est pas celle en cours.
String dateLongueCaisse(DateTime d) {
  final base = "${_jours[d.weekday - 1]} ${d.day} ${_mois[d.month - 1]}";
  return d.year == DateTime.now().year ? base : "$base ${d.year}";
}

/// « Aujourd'hui », « Hier », puis la date en toutes lettres.
String libelleJourCaisse(DateTime? d) {
  if (d == null) return "Sans date";
  final maintenant = DateTime.now();
  if (_memeJour(d, maintenant)) return "Aujourd'hui";
  if (_memeJour(d, maintenant.subtract(const Duration(days: 1)))) {
    return "Hier";
  }
  final texte = dateLongueCaisse(d);
  return texte[0].toUpperCase() + texte.substring(1);
}

String heureCaisse(DateTime d) =>
    "${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}";

/// « Lundi 21 septembre à 14:05 », pour une feuille de détail.
String dateHeureCaisse(DateTime? d) {
  if (d == null) return "—";
  return "${libelleJourCaisse(d)} à ${heureCaisse(d)}";
}

/// « 1 250,50 MAD », le séparateur de milliers étant une espace.
String montantCaisseTexte(double m) {
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

// ── Le regroupement ─────────────────────────────────────────────────

/// Les éléments d'une même journée, dans l'ordre où ils sont arrivés.
class GroupeJour<T> {
  /// Le jour, à minuit ; nul pour les éléments sans date.
  final DateTime? jour;
  final List<T> elements;

  GroupeJour(this.jour, this.elements);

  String get cle => jour == null
      ? "sans-date"
      : "${jour!.year}-${jour!.month}-${jour!.day}";
}

/// Regroupe par jour, du plus récent au plus ancien ; les éléments sans
/// date viennent en dernier. L'ordre à l'intérieur d'un jour est gardé.
List<GroupeJour<T>> grouperParJour<T>(
    Iterable<T> elements, DateTime? Function(T) date) {
  final parCle = <String, GroupeJour<T>>{};
  for (final e in elements) {
    final d = date(e);
    final jour = d == null ? null : DateTime(d.year, d.month, d.day);
    final groupe = GroupeJour<T>(jour, []);
    parCle.putIfAbsent(groupe.cle, () => groupe).elements.add(e);
  }

  final groupes = parCle.values.toList();
  groupes.sort((a, b) {
    if (a.jour == null && b.jour == null) return 0;
    if (a.jour == null) return 1;
    if (b.jour == null) return -1;
    return b.jour!.compareTo(a.jour!);
  });
  return groupes;
}

// ── La section repliable ────────────────────────────────────────────

/// Une journée d'historique, qui s'ouvre et se ferme d'un toucher.
class SectionJourRepliable extends StatefulWidget {
  final DateTime? jour;
  final int nombre;

  /// « opération », « transfert »… accordé au pluriel au besoin.
  final String unite;

  /// Totaux du jour ; une valeur nulle ou nulle en montant n'est pas
  /// affichée.
  final double? totalEntrees;
  final double? totalSorties;

  /// Un total sans sens (des transferts, par exemple).
  final double? totalNeutre;

  final bool initialementOuverte;
  final List<Widget> children;

  const SectionJourRepliable({
    super.key,
    required this.jour,
    required this.nombre,
    required this.children,
    this.unite = "opération",
    this.totalEntrees,
    this.totalSorties,
    this.totalNeutre,
    this.initialementOuverte = false,
  });

  @override
  State<SectionJourRepliable> createState() => _SectionJourRepliableState();
}

class _SectionJourRepliableState extends State<SectionJourRepliable> {
  late bool _ouverte = widget.initialementOuverte;

  @override
  Widget build(BuildContext context) {
    final entrees = widget.totalEntrees ?? 0;
    final sorties = widget.totalSorties ?? 0;
    final neutre = widget.totalNeutre ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFB),
        border: Border.all(color: const Color(0xFFE2E8EC)),
        borderRadius: BorderRadius.circular(11),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _ouverte = !_ouverte),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_outlined,
                      size: 15, color: Colors.grey.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          libelleJourCaisse(widget.jour),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF17262E)),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          "${widget.nombre} ${widget.unite}"
                          "${widget.nombre > 1 ? 's' : ''}",
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (entrees > 0.005)
                        Text("+ ${montantCaisseTexte(entrees)}",
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: couleurEntreeCaisse)),
                      if (sorties > 0.005)
                        Text("− ${montantCaisseTexte(sorties)}",
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: couleurSortieCaisse)),
                      if (neutre > 0.005)
                        Text(montantCaisseTexte(neutre),
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade800)),
                    ],
                  ),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: _ouverte ? .5 : 0,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeInOut,
                    child: Icon(Icons.expand_more,
                        size: 22, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: _ouverte
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: widget.children,
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

/// Une liste regroupée par jour, prête à l'emploi : la journée la plus
/// récente ouverte, les autres repliées.
class HistoriqueParJour<T> extends StatelessWidget {
  final List<T> elements;
  final DateTime? Function(T) date;
  final Widget Function(BuildContext, T) ligne;

  /// Vrai pour une entrée, faux pour une sortie. Nul : pas de sens, le
  /// total du jour est alors neutre.
  final bool Function(T)? estEntree;
  final double Function(T)? montant;
  final String unite;

  /// Ouvre toutes les journées : utile quand chaque ligne attend une
  /// action.
  final bool toutOuvrir;

  const HistoriqueParJour({
    super.key,
    required this.elements,
    required this.date,
    required this.ligne,
    this.estEntree,
    this.montant,
    this.unite = "opération",
    this.toutOuvrir = false,
  });

  @override
  Widget build(BuildContext context) {
    final groupes = grouperParJour(elements, date);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < groupes.length; i++)
          _section(context, groupes[i], i == 0 || toutOuvrir),
      ],
    );
  }

  Widget _section(BuildContext context, GroupeJour<T> g, bool ouverte) {
    double? entrees, sorties, neutre;
    final m = montant;
    if (m != null) {
      final sens = estEntree;
      if (sens == null) {
        neutre = g.elements.fold<double>(0, (t, e) => t + m(e));
      } else {
        entrees = 0;
        sorties = 0;
        for (final e in g.elements) {
          if (sens(e)) {
            entrees = entrees! + m(e);
          } else {
            sorties = sorties! + m(e);
          }
        }
      }
    }

    return SectionJourRepliable(
      key: ValueKey("jour-${g.cle}"),
      jour: g.jour,
      nombre: g.elements.length,
      unite: unite,
      totalEntrees: entrees,
      totalSorties: sorties,
      totalNeutre: neutre,
      initialementOuverte: ouverte,
      children: [for (final e in g.elements) ligne(context, e)],
    );
  }
}

// ── La feuille de détail ────────────────────────────────────────────

/// Une ligne « libellé : valeur » d'une feuille de détail.
class InfoDetail {
  final String libelle;
  final String valeur;
  final IconData? icone;

  const InfoDetail(this.libelle, this.valeur, {this.icone});
}

/// Un commentaire affiché en entier dans la feuille de détail.
class CommentaireDetail {
  final String titre;
  final String? texte;

  const CommentaireDetail(this.titre, this.texte);
}

/// Ouvre le détail d'une opération par le bas de l'écran.
Future<void> afficherDetailOperation(
  BuildContext context, {
  required String titre,
  String? montant,
  Color? couleur,
  IconData? icone,
  String? statut,
  Color? couleurStatut,
  List<InfoDetail> infos = const [],
  List<CommentaireDetail> commentaires = const [],
  List<Widget> actions = const [],
}) {
  final c = couleur ?? Colors.grey.shade800;

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (feuille) => ConstrainedBox(
      constraints: BoxConstraints(
          maxHeight: MediaQuery.of(feuille).size.height * .85),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (icone != null) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: c.withValues(alpha: .1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icone, size: 20, color: c),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titre,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      if (statut != null) ...[
                        const SizedBox(height: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 3),
                          decoration: BoxDecoration(
                            color: (couleurStatut ?? c).withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(statut,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: couleurStatut ?? c)),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (montant != null) ...[
              const SizedBox(height: 14),
              Text(montant,
                  style: TextStyle(
                      fontSize: 26, fontWeight: FontWeight.bold, color: c)),
            ],
            if (infos.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              for (final info in infos)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(info.icone ?? Icons.info_outline,
                          size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 110,
                        child: Text(info.libelle,
                            style: TextStyle(
                                fontSize: 12.5, color: Colors.grey.shade600)),
                      ),
                      Expanded(
                        child: Text(info.valeur,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
            ],
            for (final cm in commentaires)
              if (cm.texte != null && cm.texte!.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(cm.titre,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700)),
                const SizedBox(height: 5),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F6F8),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: SelectableText(
                    cm.texte!.trim(),
                    textDirection:
                        intl.Bidi.detectRtlDirectionality(cm.texte!.trim())
                            ? TextDirection.rtl
                            : TextDirection.ltr,
                    style: const TextStyle(fontSize: 13.5, height: 1.4),
                  ),
                ),
              ],
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 16),
              for (final a in actions)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SizedBox(width: double.infinity, child: a),
                ),
            ],
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(feuille).pop(),
                child: const Text("Fermer"),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Rend un motif serveur (« encaissement_solde ») lisible.
String motifLisible(String motif) {
  final t = motif.replaceAll("_", " ").trim();
  if (t.isEmpty) return t;
  return t[0].toUpperCase() + t.substring(1);
}
