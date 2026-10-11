/// L'engagement de l'équipe de réservation sur une période.
///
/// Vient de « GET /activite/agents?du=&au=&groupe=jour|semaine|mois » :
/// les totaux de la période, le détail de chaque agent, et la série par
/// tranche qui alimente le graphique de comparaison.

library;

int _entier(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.round();
  return int.tryParse('${v ?? ''}'.trim()) ?? 0;
}

int? _entierOuNul(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.round();
  final texte = '$v'.trim();
  if (texte.isEmpty) return null;
  return int.tryParse(texte);
}

double _decimal(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse('${v ?? ''}'.trim().replaceAll(',', '.')) ?? 0;
}

DateTime? _date(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  final texte = '$v'.trim();
  if (texte.isEmpty) return null;
  return DateTime.tryParse(texte);
}

/// Les totaux de la période, tous agents confondus.
class TotauxActivite {
  final int reservations;
  final int biensLoues;
  final int clesRemises;
  final int clesRecuperees;
  final int nettoyages;

  const TotauxActivite({
    this.reservations = 0,
    this.biensLoues = 0,
    this.clesRemises = 0,
    this.clesRecuperees = 0,
    this.nettoyages = 0,
  });

  factory TotauxActivite.fromJson(Map<String, dynamic> json) => TotauxActivite(
        reservations: _entier(json['reservations']),
        biensLoues: _entier(json['biensLoues']),
        clesRemises: _entier(json['clesRemises']),
        clesRecuperees: _entier(json['clesRecuperees']),
        nettoyages: _entier(json['nettoyages']),
      );
}

/// Ce qu'un agent a fait sur la période.
class AgentActivite {
  final int id;
  final String nom;
  final List<String> roles;
  final int reservations;
  final int biensLoues;

  /// Le montant total encaissé des réservations qu'il a créées.
  final double montant;
  final int clesRemises;
  final int clesRecuperees;
  final int nettoyages;

  /// Le temps passé à nettoyer ; nul quand le serveur ne le compte pas.
  final int? minutesNettoyage;

  /// Le travail de terrain : les clés remises et récupérées.
  final int terrain;

  const AgentActivite({
    required this.id,
    required this.nom,
    this.roles = const [],
    this.reservations = 0,
    this.biensLoues = 0,
    this.montant = 0,
    this.clesRemises = 0,
    this.clesRecuperees = 0,
    this.nettoyages = 0,
    this.minutesNettoyage,
    this.terrain = 0,
  });

  factory AgentActivite.fromJson(Map<String, dynamic> json) {
    final roles = json['roles'];
    return AgentActivite(
      id: _entier(json['id']),
      nom: (json['nom'] ?? '').toString().trim(),
      roles: roles is List
          ? roles.map((r) => '$r'.trim()).where((r) => r.isNotEmpty).toList()
          : const [],
      reservations: _entier(json['reservations']),
      biensLoues: _entier(json['biensLoues']),
      montant: _decimal(json['montant']),
      clesRemises: _entier(json['clesRemises']),
      clesRecuperees: _entier(json['clesRecuperees']),
      nettoyages: _entier(json['nettoyages']),
      minutesNettoyage: _entierOuNul(json['minutesNettoyage']),
      terrain: _entier(json['terrain']),
    );
  }

  /// Ce qui classe les agents du plus actif au moins actif : tout ce
  /// qu'ils ont fait, sans distinction de nature.
  int get total =>
      reservations + biensLoues + clesRemises + clesRecuperees + nettoyages;

  /// Les deux premières lettres du nom, pour le cercle teinté.
  String get initiales {
    final mots =
        nom.split(RegExp(r'\s+')).where((m) => m.trim().isNotEmpty).toList();
    if (mots.isEmpty) return '?';
    if (mots.length == 1) {
      final seul = mots.first;
      return (seul.length == 1 ? seul : seul.substring(0, 2)).toUpperCase();
    }
    return '${mots.first[0]}${mots[1][0]}'.toUpperCase();
  }

  /// Les rôles tels qu'on les lit sous le nom.
  String get rolesTexte => roles.join(' · ');
}

/// Ce qu'un agent a fait sur une seule tranche.
class ActiviteParAgent {
  final int reservations;
  final int terrain;

  const ActiviteParAgent({this.reservations = 0, this.terrain = 0});

  factory ActiviteParAgent.fromJson(Map<String, dynamic> json) =>
      ActiviteParAgent(
        reservations: _entier(json['reservations']),
        terrain: _entier(json['terrain']),
      );

  bool get vide => reservations == 0 && terrain == 0;
}

/// Une tranche de la série : un jour, une semaine ou un mois.
class TrancheActivite {
  /// La tranche telle que le serveur la nomme (« 2026-09-23 »).
  final String tranche;
  final int reservations;
  final int terrain;

  /// Le détail par agent, rangé par identifiant d'agent.
  final Map<int, ActiviteParAgent> parAgent;

  const TrancheActivite({
    required this.tranche,
    this.reservations = 0,
    this.terrain = 0,
    this.parAgent = const {},
  });

  factory TrancheActivite.fromJson(Map<String, dynamic> json) {
    final brut = json['parAgent'];
    final parAgent = <int, ActiviteParAgent>{};
    if (brut is Map) {
      brut.forEach((cle, valeur) {
        final id = _entierOuNul(cle);
        if (id == null || valeur is! Map) return;
        parAgent[id] =
            ActiviteParAgent.fromJson(Map<String, dynamic>.from(valeur));
      });
    }
    return TrancheActivite(
      tranche: (json['tranche'] ?? '').toString().trim(),
      reservations: _entier(json['reservations']),
      terrain: _entier(json['terrain']),
      parAgent: parAgent,
    );
  }

  /// Le début de la tranche, quand le serveur l'a datée.
  DateTime? get debut => _date(tranche.length == 7 ? '$tranche-01' : tranche);
}

class ActiviteAgents {
  final DateTime? du;
  final DateTime? au;

  /// La largeur d'une tranche : « jour », « semaine » ou « mois ».
  final String groupe;
  final TotauxActivite totaux;
  final List<AgentActivite> agents;
  final List<TrancheActivite> serie;

  const ActiviteAgents({
    this.du,
    this.au,
    this.groupe = 'jour',
    this.totaux = const TotauxActivite(),
    this.agents = const [],
    this.serie = const [],
  });

  /// Lit la réponse du serveur, que le corps soit sous « data » ou non.
  factory ActiviteAgents.fromJson(dynamic brut) {
    dynamic corps = brut;
    if (corps is Map && corps['data'] != null) corps = corps['data'];
    if (corps is! Map) return const ActiviteAgents();
    final json = Map<String, dynamic>.from(corps);

    final totaux = json['totaux'];
    final agents = json['agents'];
    final serie = json['serie'];

    final liste = agents is List
        ? agents
            .whereType<Map>()
            .map((a) => AgentActivite.fromJson(Map<String, dynamic>.from(a)))
            .toList()
        : <AgentActivite>[];
    // Du plus actif au moins actif ; à égalité, par montant encaissé.
    liste.sort((a, b) {
      final parTotal = b.total.compareTo(a.total);
      if (parTotal != 0) return parTotal;
      return b.montant.compareTo(a.montant);
    });

    return ActiviteAgents(
      du: _date(json['du']),
      au: _date(json['au']),
      groupe: (json['groupe'] ?? 'jour').toString().trim().isEmpty
          ? 'jour'
          : json['groupe'].toString().trim(),
      totaux: totaux is Map
          ? TotauxActivite.fromJson(Map<String, dynamic>.from(totaux))
          : const TotauxActivite(),
      agents: liste,
      serie: serie is List
          ? serie
              .whereType<Map>()
              .map((t) =>
                  TrancheActivite.fromJson(Map<String, dynamic>.from(t)))
              .toList()
          : const [],
    );
  }

  bool get vide => agents.isEmpty && serie.isEmpty;

  /// Le total des minutes de nettoyage, quand le serveur les compte.
  int? get minutesNettoyage {
    var total = 0;
    var connu = false;
    for (final a in agents) {
      final m = a.minutesNettoyage;
      if (m == null) continue;
      connu = true;
      total += m;
    }
    return connu ? total : null;
  }
}
