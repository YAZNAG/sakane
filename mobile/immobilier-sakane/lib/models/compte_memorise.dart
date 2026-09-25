import 'dart:ui';

/// Un compte deja utilise sur cet appareil.
///
/// L'application retient qui s'est connecte pour proposer son visage a
/// l'ouverture plutot qu'un formulaire vide. Rien de secret n'est garde
/// ici : ni mot de passe, ni jeton de session. Seulement de quoi
/// reconnaitre la personne et lui dire bonjour.
class CompteMemorise {
  /// Ce que l'utilisateur a saisi pour entrer : une adresse e-mail ou un
  /// numero de telephone. Le serveur accepte les deux, donc l'application
  /// garde la saisie telle quelle et ne devine rien.
  final String identifiant;

  final int? managerId;
  final String? prenom;
  final String? nom;
  final String? email;
  final String? role;

  /// La couleur de l'avatar, choisie une fois a la premiere connexion et
  /// jamais recalculee : le meme compte garde la meme pastille, meme si
  /// son nom change.
  final int couleurAvatar;

  final DateTime derniereConnexion;

  const CompteMemorise({
    required this.identifiant,
    required this.couleurAvatar,
    required this.derniereConnexion,
    this.managerId,
    this.prenom,
    this.nom,
    this.email,
    this.role,
  });

  /// La cle de comparaison. « Ahmed@Godar.ma » et « ahmed@godar.ma »
  /// sont le meme compte : deux entrees ne doivent pas apparaitre.
  String get cle => identifiant.trim().toLowerCase();

  /// « Ahmed Bennani », ou l'identifiant si le serveur n'a pas donne de nom.
  String get nomComplet {
    final morceaux = <String>[];
    if ((prenom ?? '').trim().isNotEmpty) morceaux.add(prenom!.trim());
    if ((nom ?? '').trim().isNotEmpty) morceaux.add(nom!.trim());
    if (morceaux.isEmpty) return identifiant;
    return morceaux.join(' ');
  }

  /// Le prenom pour le « Bienvenue ». A defaut, ce qui precede l'arobase :
  /// mieux vaut « Bienvenue ahmed » que « Bienvenue ahmed@godar.ma ».
  String get prenomAffiche {
    final p = (prenom ?? '').trim();
    if (p.isNotEmpty) return _capitale(p);
    final avant = identifiant.split('@').first.trim();
    return avant.isEmpty ? identifiant : _capitale(avant);
  }

  /// Une ou deux lettres pour la pastille.
  String get initiales {
    final p = (prenom ?? '').trim();
    final n = (nom ?? '').trim();
    if (p.isNotEmpty && n.isNotEmpty) {
      return '${p[0]}${n[0]}'.toUpperCase();
    }
    final source = p.isNotEmpty ? p : identifiant.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    if (source.isEmpty) return '?';
    if (source.length == 1) return source.toUpperCase();
    return source.substring(0, 2).toUpperCase();
  }

  Color get couleur => Color(couleurAvatar);

  /// « Aujourd'hui a 14:05 », « Hier a 09:12 », « le 12/09/2026 ».
  ///
  /// Les noms de jours et les mots sont ecrits ici plutot que confies a
  /// une locale : l'application n'embarque pas les donnees de langue et
  /// afficherait de l'anglais.
  String get derniereConnexionLisible {
    final maintenant = DateTime.now();
    final aujourdhui = DateTime(maintenant.year, maintenant.month, maintenant.day);
    final jour = DateTime(
      derniereConnexion.year,
      derniereConnexion.month,
      derniereConnexion.day,
    );
    final heure = '${derniereConnexion.hour.toString().padLeft(2, '0')}:'
        '${derniereConnexion.minute.toString().padLeft(2, '0')}';
    final ecart = aujourdhui.difference(jour).inDays;
    if (ecart == 0) return "Aujourd'hui à $heure";
    if (ecart == 1) return "Hier à $heure";
    final j = derniereConnexion.day.toString().padLeft(2, '0');
    final m = derniereConnexion.month.toString().padLeft(2, '0');
    return "le $j/$m/${derniereConnexion.year}";
  }

  Map<String, dynamic> toJson() => {
        'identifiant': identifiant,
        'managerId': managerId,
        'prenom': prenom,
        'nom': nom,
        'email': email,
        'role': role,
        'couleurAvatar': couleurAvatar,
        'derniereConnexion': derniereConnexion.toIso8601String(),
      };

  /// Une entree illisible ne doit pas faire perdre les autres comptes :
  /// les champs absents prennent une valeur de repli.
  factory CompteMemorise.fromJson(Map<String, dynamic> json) {
    final identifiant = (json['identifiant'] ?? '').toString();
    return CompteMemorise(
      identifiant: identifiant,
      managerId: json['managerId'] is int ? json['managerId'] as int : null,
      prenom: json['prenom']?.toString(),
      nom: json['nom']?.toString(),
      email: json['email']?.toString(),
      role: json['role']?.toString(),
      couleurAvatar: json['couleurAvatar'] is int
          ? json['couleurAvatar'] as int
          : couleurPour(identifiant),
      derniereConnexion:
          DateTime.tryParse(json['derniereConnexion']?.toString() ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  CompteMemorise copyWith({
    String? identifiant,
    int? managerId,
    String? prenom,
    String? nom,
    String? email,
    String? role,
    int? couleurAvatar,
    DateTime? derniereConnexion,
  }) {
    return CompteMemorise(
      identifiant: identifiant ?? this.identifiant,
      managerId: managerId ?? this.managerId,
      prenom: prenom ?? this.prenom,
      nom: nom ?? this.nom,
      email: email ?? this.email,
      role: role ?? this.role,
      couleurAvatar: couleurAvatar ?? this.couleurAvatar,
      derniereConnexion: derniereConnexion ?? this.derniereConnexion,
    );
  }

  /// Des teintes assez sombres pour que les initiales blanches restent
  /// lisibles dessus.
  static const List<int> palette = [
    0xFF1F7A5E,
    0xFF1D6FB8,
    0xFF7B4DBC,
    0xFFB5451B,
    0xFFBE185D,
    0xFF00695C,
    0xFF5D4037,
    0xFF3F51B5,
  ];

  /// La couleur d'un compte decoule de son identifiant : le meme compte
  /// retrouve la meme pastille sur un autre appareil.
  static int couleurPour(String graine) {
    final normalisee = graine.trim().toLowerCase();
    if (normalisee.isEmpty) return palette.first;
    var somme = 0;
    for (final unite in normalisee.codeUnits) {
      somme = (somme + unite) % 100000;
    }
    return palette[somme % palette.length];
  }

  static String _capitale(String valeur) =>
      '${valeur[0].toUpperCase()}${valeur.substring(1)}';
}
