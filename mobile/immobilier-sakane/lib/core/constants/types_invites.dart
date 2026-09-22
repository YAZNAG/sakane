/// Types d'invites d'une reservation.
///
/// La base attend des codes anglais - c'est un enum SQL, on ne le
/// touche pas. Ce que l'agent lit, en revanche, doit lui parler : le
/// francais, puis l'arabe entre parentheses.
class TypeInvite {
  final String code;
  final String francais;
  final String arabe;

  const TypeInvite(this.code, this.francais, this.arabe);

  /// « Hommes (\u0631\u062C\u0627\u0644) »
  String get libelle => "$francais ($arabe)";

  static const List<TypeInvite> tous = [
    TypeInvite("Males", "Hommes", "\u0631\u062C\u0627\u0644"),
    TypeInvite("Females", "Femmes", "\u0646\u0633\u0627\u0621"),
    TypeInvite("Family", "Famille", "\u0639\u0627\u0626\u0644\u0629"),
    TypeInvite("Professional visitors", "Visiteurs professionnels",
        "\u0632\u0648\u0627\u0631 \u0645\u0647\u0646\u064A\u0648\u0646"),
  ];

  /// Les codes, dans l'ordre d'affichage.
  static List<String> get codes => tous.map((t) => t.code).toList();

  /// Le libelle d'un code ; un code inconnu se rend tel quel plutot
  /// que de disparaitre.
  static String libelleDe(String? code) {
    if (code == null || code.isEmpty) return "";
    for (final t in tous) {
      if (t.code == code) return t.libelle;
    }
    return code;
  }
}
