import 'package:flutter_test/flutter_test.dart';
import 'package:immobilier/features/immobilier/detail_immobilier/ui/components/partage_bien.dart';
import 'package:immobilier/models/address.dart';
import 'package:immobilier/models/category.dart';
import 'package:immobilier/models/city.dart';
import 'package:immobilier/models/feature.dart';
import 'package:immobilier/models/location.dart';
import 'package:immobilier/models/realestate.dart';
import 'package:immobilier/models/secteur.dart';

/// La fiche partagee ne porte que cinq choses : les photos, le titre,
/// la description, la ville et le quartier, la position sur la carte.
/// Tout le reste doit rester en dehors.
void main() {
  Realestate bienComplet() => Realestate(
        id: 1,
        title: "Appartement Founty",
        description: "Vue mer, proche plage.",
        surface: 120,
        price: 4500,
        nbRooms: 3,
        nbBathroom: 2,
        etage: 4,
        nbEtages: 6,
        category: Category(name: "Appartement"),
        secteur: Secteur(id: 2, name: "HAY FOUNTY"),
        address: Address(address: "12 rue Al Massira", city: City(name: "Agadir")),
        features: [Feature(name: "Wifi"), Feature(name: "Climatisation")],
        location: Location(latitude: 30.4202, longitude: -9.5982),
      );

  group("texte de partage", () {
    test("porte le titre et la description", () {
      final texte = PartageBien.construireTexte(bienComplet());

      expect(texte, contains("Appartement Founty"));
      expect(texte, contains("Vue mer, proche plage."));
    });

    test("porte la ville, le quartier et la carte", () {
      final texte = PartageBien.construireTexte(bienComplet());

      expect(texte, contains("Agadir - HAY FOUNTY"));
      expect(texte, contains("https://maps.google.com/?q=30.4202,-9.5982"));
    });

    test("ne porte rien d'autre", () {
      final texte = PartageBien.construireTexte(bienComplet());

      expect(texte, isNot(contains("Caractéristiques")));
      expect(texte, isNot(contains("Équipements")));
      expect(texte, isNot(contains("Chambres")));
      expect(texte, isNot(contains("Wifi")));
      expect(texte, isNot(contains("Surface")));
      expect(texte.toLowerCase(), isNot(contains("catégorie")));
      expect(texte.toLowerCase(), isNot(contains("transaction")));
      expect(texte.toLowerCase(), isNot(contains("construction")));
      // L'adresse exacte se donne apres reservation, pas dans l'annonce.
      expect(texte, isNot(contains("12 rue Al Massira")));
    });

    test("ne laisse jamais passer le prix", () {
      final texte = PartageBien.construireTexte(bienComplet());

      expect(texte.toLowerCase(), isNot(contains("prix")));
      expect(texte, isNot(contains("4500")));
      expect(texte, isNot(contains("4 500")));
      expect(texte.toUpperCase(), isNot(contains("MAD")));
      expect(texte.toLowerCase(), isNot(contains("dirham")));
    });

    test("ne divulgue pas les coordonnees du proprietaire", () {
      final texte = PartageBien.construireTexte(bienComplet());

      expect(texte.toLowerCase(), isNot(contains("propriétaire")));
      expect(texte.toLowerCase(), isNot(contains("proprietaire")));
    });

    test("sans coordonnees, aucun lien de carte n'est invente", () {
      final texte = PartageBien.construireTexte(
          Realestate(id: 4, title: "Studio", address: Address(city: City(name: "Agadir"))));

      expect(texte, contains("Agadir"));
      expect(texte, isNot(contains("maps.google")));
    });

    test("des coordonnees a zero ne pointent pas au large de l'Afrique", () {
      final texte = PartageBien.construireTexte(Realestate(
          id: 5, title: "Studio", location: Location(latitude: 0, longitude: 0)));

      expect(texte, isNot(contains("maps.google")));
    });

    test("tient dans une legende WhatsApp, description raccourcie au besoin", () {
      final bavard = bienComplet()..description = "Lorem ipsum " * 400;
      final texte = PartageBien.construireTexte(bavard);

      expect(texte.length, lessThanOrEqualTo(1024));
      // La coupe ne doit pas emporter le reste de la fiche.
      expect(texte, contains("Appartement Founty"));
      expect(texte, contains("Agadir - HAY FOUNTY"));
      expect(texte, contains("maps.google"));
      expect(texte, contains("…"));
    });

    test("une fiche courte n'est pas tronquee", () {
      final texte = PartageBien.construireTexte(bienComplet());

      expect(texte, contains("Vue mer, proche plage."));
      expect(texte, isNot(contains("…")));
    });

    test("reste lisible quand presque tout manque", () {
      final texte = PartageBien.construireTexte(Realestate(id: 9));

      expect(texte, "*Bien immobilier*");
      expect(texte, isNot(contains("null")));
    });

    test("omet les rubriques vides plutot que de les afficher vides", () {
      final texte =
          PartageBien.construireTexte(Realestate(id: 3, title: "Studio"));

      expect(texte, "*Studio*");
      expect(texte, isNot(contains("📍")));
      expect(texte, isNot(contains("🗺")));
    });
  });
}
