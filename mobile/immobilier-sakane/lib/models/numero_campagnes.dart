/// Numero WhatsApp utilise par les campagnes : une session Wasender
/// dediee, ou a defaut le numero principal de l'agence.
///
/// Les cles ne sont jamais recues en entier : le serveur ne renvoie
/// que leur version masquee ("abcd…wxyz").
class NumeroCampagnes {
  final bool dedie;

  /// Cle masquee de la session dediee.
  final String? cle;
  final String? numero;
  final String? nom;

  /// Cle masquee du numero principal.
  final String? principal;

  const NumeroCampagnes({
    this.dedie = false,
    this.cle,
    this.numero,
    this.nom,
    this.principal,
  });

  factory NumeroCampagnes.fromJson(Map<String, dynamic> json) {
    String? texte(dynamic v) {
      final s = v?.toString().trim();
      return s == null || s.isEmpty ? null : s;
    }

    return NumeroCampagnes(
      dedie: json['dedie'] == true || json['dedie'] == 1,
      cle: texte(json['cle']),
      numero: texte(json['numero']),
      nom: texte(json['nom']),
      principal: texte(json['principal']),
    );
  }

  /// "+2126…" ; vide si le serveur ne connait pas encore le numero.
  String get numeroLisible {
    if (numero == null) return '';
    return numero!.startsWith('+') ? numero! : '+${numero!}';
  }

  /// Phrase affichee dans la fiche.
  String get description {
    if (dedie) {
      final morceaux = [
        if (numeroLisible.isNotEmpty) numeroLisible,
        if (nom != null) '($nom)',
      ].join(' ');
      return 'Numéro dédié : ${morceaux.isEmpty ? 'session Wasender' : morceaux}'
          '${cle != null ? ' · clé $cle' : ''}';
    }
    return 'Les campagnes partent du numéro principal'
        '${principal != null ? ' (clé $principal)' : ''}';
  }

  /// Libelle court pour la pastille de la liste.
  String get libelleCourt {
    if (!dedie) return 'Numéro principal';
    return numeroLisible.isNotEmpty ? 'Numéro dédié $numeroLisible' : 'Numéro dédié';
  }
}
