/// Statut du bien aujourd'hui, calcule par le serveur (champ
/// `statutJour`) : desactive, occupe, occupe_airbnb, nettoyage,
/// a_nettoyer ou disponible.
///
/// A ne pas confondre avec `etat` (etat du bien : « Bon état »…).
class StatutJour {
  static const String desactive = 'desactive';
  static const String occupe = 'occupe';
  static const String occupeAirbnb = 'occupe_airbnb';
  static const String nettoyage = 'nettoyage';
  static const String aNettoyer = 'a_nettoyer';
  static const String disponible = 'disponible';

  final String code;
  final String libelle;

  /// Precision facultative : « Jusqu'au 22/09/2026 »…
  final String? detail;

  const StatutJour({required this.code, required this.libelle, this.detail});

  bool get estDesactive => code == desactive;

  /// Occupe via Airbnb : code dedie ou libelle « Occupé (Airbnb) ».
  bool get estAirbnb =>
      code == occupeAirbnb || (code == occupe && libelle.toLowerCase().contains('airbnb'));

  /// Lecture tolerante : null si le champ est absent ou illisible.
  static StatutJour? depuis(dynamic json) {
    if (json is! Map) return null;
    final code = (json['code'] ?? '').toString().trim();
    final libelle = (json['libelle'] ?? '').toString().trim();
    if (code.isEmpty && libelle.isEmpty) return null;
    final detail = json['detail']?.toString().trim();
    return StatutJour(
      code: code,
      libelle: libelle.isNotEmpty ? libelle : code,
      detail: (detail ?? '').isEmpty ? null : detail,
    );
  }
}
