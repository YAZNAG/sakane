import 'package:flutter/material.dart';
import 'package:immobilier/core/constants/app_colors.dart';

/// Ce que les deux écrans d'activité de l'équipe partagent : la charte,
/// les puces de période, la mise en forme des durées et des montants, et
/// les états d'attente, d'erreur et de vide.

// ── La charte ───────────────────────────────────────────────────────

const Color couleurTexteActivite = Color(0xFF17262E);
const Color couleurGrisActivite = Color(0xFF6B7B84);
const Color couleurBordureActivite = Color(0xFFE2E8EC);
const Color couleurVertActivite = Color(0xFF2E9E5B);
const Color couleurOrangeActivite = Color(0xFFE8710A);
const Color couleurRougeActivite = Color(0xFFE03E3E);

/// Le fond très pâle des en-têtes de section et des lignes.
const Color couleurFondActivite = Color(0xFFF8FAFB);

/// Les chiffres alignés en colonnes : un montant ne saute plus d'un
/// millimètre quand il change.
const List<FontFeature> chiffresActivite = [FontFeature.tabularFigures()];

/// La bordure et le fond d'une carte blanche de ces écrans.
BoxDecoration get carteActivite => BoxDecoration(
      color: Colors.white,
      border: Border.all(color: couleurBordureActivite),
      borderRadius: BorderRadius.circular(14),
    );

// ── Les périodes ────────────────────────────────────────────────────

/// Les puces de période du haut des deux écrans.
enum PeriodeActivite {
  aujourdhui("Aujourd'hui"),
  semaine('Cette semaine'),
  mois('Ce mois'),
  personnalisee('Période');

  const PeriodeActivite(this.libelle);

  final String libelle;
}

/// Les dates de début et de fin d'une période rapide, à la date du jour.
/// La période personnalisée garde les dates déjà choisies.
class BornesActivite {
  final DateTime du;
  final DateTime au;

  const BornesActivite(this.du, this.au);
}

BornesActivite bornesActivite(PeriodeActivite periode) {
  final maintenant = DateTime.now();
  final aujourdhui =
      DateTime(maintenant.year, maintenant.month, maintenant.day);
  switch (periode) {
    case PeriodeActivite.aujourdhui:
      return BornesActivite(aujourdhui, aujourdhui);
    case PeriodeActivite.semaine:
      // La semaine commence le lundi.
      final lundi = aujourdhui.subtract(Duration(days: aujourdhui.weekday - 1));
      return BornesActivite(lundi, aujourdhui);
    case PeriodeActivite.mois:
      return BornesActivite(
          DateTime(aujourdhui.year, aujourdhui.month, 1), aujourdhui);
    case PeriodeActivite.personnalisee:
      return BornesActivite(aujourdhui, aujourdhui);
  }
}

/// Le regroupement de la série du graphique.
enum GroupeActivite {
  jour('jour', 'Jour'),
  semaine('semaine', 'Semaine'),
  mois('mois', 'Mois');

  const GroupeActivite(this.code, this.libelle);

  /// Le code attendu par le serveur.
  final String code;
  final String libelle;

  static GroupeActivite depuis(String? code) => GroupeActivite.values
      .firstWhere((g) => g.code == code, orElse: () => GroupeActivite.jour);
}

// ── Les dates, en français ──────────────────────────────────────────

const List<String> _jours = [
  'lundi',
  'mardi',
  'mercredi',
  'jeudi',
  'vendredi',
  'samedi',
  'dimanche',
];

const List<String> _mois = [
  'janvier',
  'février',
  'mars',
  'avril',
  'mai',
  'juin',
  'juillet',
  'août',
  'septembre',
  'octobre',
  'novembre',
  'décembre',
];

const List<String> _moisCourts = [
  'janv.',
  'févr.',
  'mars',
  'avr.',
  'mai',
  'juin',
  'juil.',
  'août',
  'sept.',
  'oct.',
  'nov.',
  'déc.',
];

bool _memeJour(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _deux(int n) => n.toString().padLeft(2, '0');

/// « lundi 21 septembre », l'année en plus quand ce n'est pas celle-ci.
String dateLongueActivite(DateTime d) {
  final base = '${_jours[d.weekday - 1]} ${d.day} ${_mois[d.month - 1]}';
  return d.year == DateTime.now().year ? base : '$base ${d.year}';
}

/// « Aujourd'hui », « Hier », puis la date en toutes lettres.
String libelleJourActivite(DateTime? d) {
  if (d == null) return 'Sans date';
  final maintenant = DateTime.now();
  if (_memeJour(d, maintenant)) return "Aujourd'hui";
  if (_memeJour(d, maintenant.subtract(const Duration(days: 1)))) return 'Hier';
  return dateLongueActivite(d);
}

/// « 21/09/2026 ».
String dateCourteActivite(DateTime? d) =>
    d == null ? '—' : '${_deux(d.day)}/${_deux(d.month)}/${d.year}';

/// « 10:15 ».
String heureActivite(DateTime? d) =>
    d == null ? '—' : '${_deux(d.hour)}:${_deux(d.minute)}';

/// « Du 1 septembre au 23 septembre », tel qu'on le lit sous les puces.
String libellePeriodeActivite(DateTime du, DateTime au) {
  if (_memeJour(du, au)) {
    final texte = libelleJourActivite(du);
    return texte[0].toUpperCase() + texte.substring(1);
  }
  return 'Du ${dateCourteActivite(du)} au ${dateCourteActivite(au)}';
}

/// L'étiquette d'une tranche du graphique, selon le regroupement.
String libelleTrancheActivite(DateTime? debut, String brut, GroupeActivite g) {
  if (debut == null) return brut;
  switch (g) {
    case GroupeActivite.jour:
      return '${_deux(debut.day)}/${_deux(debut.month)}';
    case GroupeActivite.semaine:
      return 'sem. ${_deux(debut.day)}/${_deux(debut.month)}';
    case GroupeActivite.mois:
      return '${_moisCourts[debut.month - 1]} ${debut.year}';
  }
}

// ── Les durées et les montants ──────────────────────────────────────

/// « 50 min », « 3 h 20 », « 2 h ». Nul ou zéro donne un tiret.
String dureeActivite(int? minutes) {
  if (minutes == null || minutes <= 0) return '—';
  if (minutes < 60) return '$minutes min';
  final heures = minutes ~/ 60;
  final reste = minutes % 60;
  return reste == 0 ? '$heures h' : '$heures h ${_deux(reste)}';
}

/// « 1 250,50 MAD », le séparateur de milliers étant une espace.
String montantActivite(num? valeur) {
  final m = (valeur ?? 0).toDouble();
  final entier = m.abs().truncate();
  final decimales = ((m.abs() - entier) * 100).round();
  final chiffres = entier.toString();

  final tampon = StringBuffer();
  for (var i = 0; i < chiffres.length; i++) {
    if (i > 0 && (chiffres.length - i) % 3 == 0) tampon.write(' ');
    tampon.write(chiffres[i]);
  }

  final signe = m < 0 ? '− ' : '';
  final fraction =
      decimales == 0 ? '' : ',${decimales.toString().padLeft(2, '0')}';
  return '$signe$tampon$fraction MAD';
}

/// Accorde un mot au pluriel : « 3 appartements », « 1 appartement ».
/// [forme] sert aux pluriels irréguliers.
String pluriel(int n, String singulier, [String? forme]) =>
    n > 1 ? (forme ?? '${singulier}s') : singulier;

// ── Les briques d'interface ─────────────────────────────────────────

/// Une puce de filtre, comme dans les statistiques financières.
class PuceActivite extends StatelessWidget {
  final String libelle;
  final bool choisie;
  final IconData? icone;
  final VoidCallback onTap;

  const PuceActivite({
    super.key,
    required this.libelle,
    required this.choisie,
    required this.onTap,
    this.icone,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: choisie ? AppColors.primaryColor : const Color(0xFFF2F5F7),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: choisie ? AppColors.primaryColor : couleurBordureActivite,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icone != null) ...[
              Icon(icone,
                  size: 14, color: choisie ? Colors.white : couleurGrisActivite),
              const SizedBox(width: 5),
            ],
            Text(
              libelle,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: choisie ? Colors.white : couleurGrisActivite,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Les puces de période et le choix des dates de début et de fin.
class FiltrePeriodeActivite extends StatelessWidget {
  final PeriodeActivite periode;
  final DateTime du;
  final DateTime au;
  final ValueChanged<PeriodeActivite> onPeriode;
  final void Function(DateTime du, DateTime au) onDates;

  const FiltrePeriodeActivite({
    super.key,
    required this.periode,
    required this.du,
    required this.au,
    required this.onPeriode,
    required this.onDates,
  });

  Future<void> _choisirDates(BuildContext context) async {
    final aujourdhui = DateTime.now();
    var debut = du;
    var fin = au;
    if (fin.isBefore(debut)) {
      final t = debut;
      debut = fin;
      fin = t;
    }
    final limite = DateTime(aujourdhui.year + 1, 12, 31);
    final choix = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: limite,
      initialDateRange: DateTimeRange(
        start: debut.isAfter(limite) ? limite : debut,
        end: fin.isAfter(limite) ? limite : fin,
      ),
      helpText: 'Choisir une période',
      saveText: 'Valider',
      builder: (ctx, enfant) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(
            primary: AppColors.primaryColor,
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: couleurTexteActivite,
          ),
        ),
        child: enfant!,
      ),
    );
    if (choix == null) return;
    onDates(choix.start, choix.end);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final p in PeriodeActivite.values)
              PuceActivite(
                libelle: p.libelle,
                choisie: periode == p,
                icone: p == PeriodeActivite.personnalisee
                    ? Icons.event_outlined
                    : null,
                onTap: () {
                  if (p == PeriodeActivite.personnalisee) {
                    _choisirDates(context);
                  } else {
                    onPeriode(p);
                  }
                },
              ),
          ],
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _choisirDates(context),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                const Icon(Icons.date_range_outlined,
                    size: 16, color: couleurGrisActivite),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    libellePeriodeActivite(du, au),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: couleurGrisActivite,
                      fontFeatures: chiffresActivite,
                    ),
                  ),
                ),
                const Icon(Icons.edit_calendar_outlined,
                    size: 16, color: AppColors.primaryColor),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Une carte de total : un chiffre, son libellé, une icône teintée.
class CarteTotalActivite extends StatelessWidget {
  final String libelle;
  final String valeur;
  final String? detail;
  final IconData icone;
  final Color teinte;

  const CarteTotalActivite({
    super.key,
    required this.libelle,
    required this.valeur,
    required this.icone,
    required this.teinte,
    this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: carteActivite,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: teinte.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icone, size: 15, color: teinte),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  libelle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 10.5,
                      height: 1.15,
                      color: couleurGrisActivite),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            valeur,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: couleurTexteActivite,
              fontFeatures: chiffresActivite,
            ),
          ),
          if (detail != null && detail!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Text(
                detail!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 10.5,
                    color: couleurGrisActivite,
                    fontFeatures: chiffresActivite),
              ),
            ),
        ],
      ),
    );
  }
}

/// Un chiffre d'une rangée de chiffres : la valeur, puis son libellé.
class ChiffreActivite extends StatelessWidget {
  final String libelle;
  final String valeur;
  final String? detail;
  final Color teinte;

  const ChiffreActivite({
    super.key,
    required this.libelle,
    required this.valeur,
    required this.teinte,
    this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          valeur,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: teinte,
            fontFeatures: chiffresActivite,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          libelle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              fontSize: 9.5, height: 1.15, color: couleurGrisActivite),
        ),
        if (detail != null && detail!.isNotEmpty)
          Text(
            detail!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: couleurGrisActivite,
                fontFeatures: chiffresActivite),
          ),
      ],
    );
  }
}

/// Une pastille : une durée, un état (« En cours »), un petit nombre.
class PastilleActivite extends StatelessWidget {
  final String texte;
  final Color teinte;
  final IconData? icone;

  const PastilleActivite({
    super.key,
    required this.texte,
    required this.teinte,
    this.icone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: teinte.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icone != null) ...[
            Icon(icone, size: 11, color: teinte),
            const SizedBox(width: 4),
          ],
          Text(
            texte,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: teinte,
              fontFeatures: chiffresActivite,
            ),
          ),
        ],
      ),
    );
  }
}

/// Une section repliable : un titre, un sous-titre, un contenu.
class SectionRepliableActivite extends StatefulWidget {
  final String titre;
  final String sousTitre;
  final IconData icone;
  final bool ouverteAuDepart;
  final List<Widget> enfants;

  const SectionRepliableActivite({
    super.key,
    required this.titre,
    required this.sousTitre,
    required this.enfants,
    this.icone = Icons.calendar_today_outlined,
    this.ouverteAuDepart = false,
  });

  @override
  State<SectionRepliableActivite> createState() =>
      _SectionRepliableActiviteState();
}

class _SectionRepliableActiviteState extends State<SectionRepliableActivite> {
  late bool _ouverte = widget.ouverteAuDepart;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: couleurBordureActivite),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _ouverte = !_ouverte),
            child: Container(
              color: couleurFondActivite,
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
              child: Row(
                children: [
                  Icon(widget.icone, size: 15, color: couleurGrisActivite),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.titre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: couleurTexteActivite),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          widget.sousTitre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11,
                              color: couleurGrisActivite,
                              fontFeatures: chiffresActivite),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _ouverte ? .5 : 0,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeInOut,
                    child: const Icon(Icons.expand_more,
                        size: 22, color: couleurGrisActivite),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: _ouverte
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: widget.enfants,
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

/// Le squelette d'attente : des blocs gris qui annoncent la mise en page.
class SqueletteActivite extends StatelessWidget {
  /// Le nombre de cartes de la grille de totaux.
  final int totaux;

  /// Vrai quand l'écran montre un graphique sous les totaux.
  final bool graphique;
  final int lignes;

  const SqueletteActivite({
    super.key,
    this.totaux = 4,
    this.graphique = false,
    this.lignes = 4,
  });

  Widget _bloc({double? largeur, double hauteur = 14, double rayon = 8}) =>
      Container(
        width: largeur,
        height: hauteur,
        decoration: BoxDecoration(
          color: const Color(0xFFEDF1F4),
          borderRadius: BorderRadius.circular(rayon),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (totaux > 0)
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.1,
            children: [
              for (var i = 0; i < totaux; i++) _bloc(hauteur: 76, rayon: 14),
            ],
          ),
        if (graphique) ...[
          const SizedBox(height: 10),
          _bloc(hauteur: 210, rayon: 14),
        ],
        const SizedBox(height: 10),
        for (var i = 0; i < lignes; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _bloc(hauteur: 72, rayon: 14),
          ),
      ],
    );
  }
}

/// Une erreur discrète, avec « Réessayer » : l'écran reste lisible.
class ErreurActivite extends StatelessWidget {
  final String message;
  final VoidCallback onReessayer;

  const ErreurActivite(
      {super.key, required this.message, required this.onReessayer});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: couleurRougeActivite.withValues(alpha: .06),
        border: Border.all(color: couleurRougeActivite.withValues(alpha: .25)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline,
              size: 19, color: couleurRougeActivite),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.3,
                  color: couleurTexteActivite),
            ),
          ),
          const SizedBox(width: 6),
          TextButton(
            onPressed: onReessayer,
            style: TextButton.styleFrom(
              foregroundColor: couleurRougeActivite,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            child: const Text('Réessayer',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

/// Un état vide qui dit ce qui manque et quoi faire.
class VideActivite extends StatelessWidget {
  final IconData icone;
  final String titre;
  final String detail;

  const VideActivite({
    super.key,
    required this.icone,
    required this.titre,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 34),
      decoration: carteActivite,
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: AppColors.primaryColor.withValues(alpha: .08),
              shape: BoxShape.circle,
            ),
            child: Icon(icone, size: 27, color: AppColors.primaryColor),
          ),
          const SizedBox(height: 14),
          Text(
            titre,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: couleurTexteActivite),
          ),
          const SizedBox(height: 6),
          Text(
            detail,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 12.5, height: 1.4, color: couleurGrisActivite),
          ),
        ],
      ),
    );
  }
}
