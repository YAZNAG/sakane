// Le résumé de l'accueil, tel que le serveur le rend :
// `GET /accueil/resume`.
//
// Rien n'est calculé ici : les montants et les nombres viennent du
// serveur, qui seul connaît l'état des caisses et des réservations.
// Chaque champ tolère son absence — une ancienne réponse, ou un compte
// sans caisse, ne doit jamais empêcher l'accueil de s'afficher.

class UtilisateurResume {
  final String prenom;
  final String nom;
  final List<String> roles;

  const UtilisateurResume({
    this.prenom = '',
    this.nom = '',
    this.roles = const [],
  });

  factory UtilisateurResume.fromJson(Map<String, dynamic> json) {
    return UtilisateurResume(
      prenom: _texte(json['prenom']),
      nom: _texte(json['nom']),
      roles: (json['roles'] as List?)?.map((r) => r.toString()).toList() ?? const [],
    );
  }
}

/// La caisse de l'utilisateur. Nulle lorsqu'il n'en a pas.
class CaisseResume {
  final int id;
  final String nom;
  final String type;

  /// Le numéro de la caisse en cours ; nul si aucune n'est ouverte.
  final int? numero;
  final bool ouverte;

  /// Ce que l'agent doit avoir sur lui.
  final double solde;
  final double encaisse;
  final double sorties;
  final double aRemettre;

  const CaisseResume({
    this.id = 0,
    this.nom = 'Ma caisse',
    this.type = 'agent',
    this.numero,
    this.ouverte = false,
    this.solde = 0,
    this.encaisse = 0,
    this.sorties = 0,
    this.aRemettre = 0,
  });

  factory CaisseResume.fromJson(Map<String, dynamic> json) {
    return CaisseResume(
      id: _entier(json['id']) ?? 0,
      nom: _texte(json['nom'], defaut: 'Ma caisse'),
      type: _texte(json['type'], defaut: 'agent'),
      numero: _entier(json['numero']),
      ouverte: _booleen(json['ouverte']),
      solde: _nombre(json['solde']),
      encaisse: _nombre(json['encaisse']),
      sorties: _nombre(json['sorties']),
      aRemettre: _nombre(json['aRemettre']),
    );
  }
}

/// Les compteurs du jour.
class AujourdhuiResume {
  final int arrivees;
  final int departs;
  final int aNettoyer;
  final int impayes;

  const AujourdhuiResume({
    this.arrivees = 0,
    this.departs = 0,
    this.aNettoyer = 0,
    this.impayes = 0,
  });

  factory AujourdhuiResume.fromJson(Map<String, dynamic> json) {
    return AujourdhuiResume(
      arrivees: _entier(json['arrivees']) ?? 0,
      departs: _entier(json['departs']) ?? 0,
      aNettoyer: _entier(json['aNettoyer']) ?? 0,
      impayes: _entier(json['impayes']) ?? 0,
    );
  }
}

class ResumeAccueil {
  final UtilisateurResume utilisateur;

  /// Le nom de l'agence, affiché sous la salutation. Vide : rien n'est
  /// affiché à sa place.
  final String agence;

  /// La date du serveur, qui fait foi pour « aujourd'hui ».
  final DateTime? date;

  final CaisseResume? caisse;
  final AujourdhuiResume aujourdhui;

  const ResumeAccueil({
    this.utilisateur = const UtilisateurResume(),
    this.agence = '',
    this.date,
    this.caisse,
    this.aujourdhui = const AujourdhuiResume(),
  });

  /// Lit `{data: {...}}` ou directement le contenu.
  static ResumeAccueil depuis(dynamic brut) {
    dynamic corps = brut;
    if (corps is Map && corps['data'] is Map) corps = corps['data'];
    if (corps is! Map) return const ResumeAccueil();
    final json = Map<String, dynamic>.from(corps);

    final caisse = json['caisse'];
    return ResumeAccueil(
      utilisateur: json['utilisateur'] is Map
          ? UtilisateurResume.fromJson(
              Map<String, dynamic>.from(json['utilisateur'] as Map))
          : const UtilisateurResume(),
      agence: _texte(json['agence']),
      date: DateTime.tryParse(_texte(json['date']))?.toLocal(),
      caisse: caisse is Map
          ? CaisseResume.fromJson(Map<String, dynamic>.from(caisse))
          : null,
      aujourdhui: json['aujourdhui'] is Map
          ? AujourdhuiResume.fromJson(
              Map<String, dynamic>.from(json['aujourdhui'] as Map))
          : const AujourdhuiResume(),
    );
  }
}

String _texte(dynamic v, {String defaut = ''}) {
  final t = v?.toString().trim();
  return t == null || t.isEmpty ? defaut : t;
}

double _nombre(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse(v?.toString() ?? '') ?? 0;
}

int? _entier(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '');
}

bool _booleen(dynamic v) => v == true || v == 1 || v == '1' || v == 'true';
