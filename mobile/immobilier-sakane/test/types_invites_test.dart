import 'package:flutter_test/flutter_test.dart';
import 'package:immobilier/core/constants/types_invites.dart';

/// La base stocke des codes anglais : ce sont eux qui doivent partir au
/// serveur, quoi qu'affiche l'ecran.
void main() {
  group("types d'invites", () {
    test("les codes restent ceux que la base attend", () {
      expect(TypeInvite.codes,
          ["Males", "Females", "Family", "Professional visitors"]);
    });

    test("le libelle porte le francais puis l'arabe", () {
      expect(TypeInvite.libelleDe("Males"), "Hommes (\u0631\u062C\u0627\u0644)");
      expect(TypeInvite.libelleDe("Females"), "Femmes (\u0646\u0633\u0627\u0621)");
      expect(TypeInvite.libelleDe("Family"), "Famille (\u0639\u0627\u0626\u0644\u0629)");
      expect(TypeInvite.libelleDe("Professional visitors"),
          "Visiteurs professionnels (\u0632\u0648\u0627\u0631 \u0645\u0647\u0646\u064A\u0648\u0646)");
    });

    test("un code inconnu se rend tel quel plutot que de disparaitre", () {
      expect(TypeInvite.libelleDe("Autre chose"), "Autre chose");
    });

    test("l'absence de code ne produit pas le mot null", () {
      expect(TypeInvite.libelleDe(null), "");
      expect(TypeInvite.libelleDe(""), "");
    });
  });
}
