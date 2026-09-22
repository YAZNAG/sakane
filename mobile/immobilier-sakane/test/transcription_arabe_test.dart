import 'package:flutter_test/flutter_test.dart';
import 'package:immobilier/core/services/transcription_arabe.dart';

/// Le nom lu en lettres latines sur la CIN donne sa proposition en arabe,
/// comme on l'écrit au Maroc.
void main() {
  String? ar(String latin) => TranscriptionArabe.transcrire(latin)?.arabe;

  group("dictionnaire", () {
    test("prénoms courants, sous leurs graphies de CIN", () {
      expect(ar("YOUSSEF"), "يوسف");
      expect(ar("Mohammed"), "محمد");
      expect(ar("KHADIJA"), "خديجة");
      expect(ar("Meryem"), "مريم");
      expect(ar("Zakariae"), "زكرياء");
    });

    test("noms composés, en un ou plusieurs mots", () {
      expect(ar("FATIMA ZAHRA"), "فاطمة الزهراء");
      expect(ar("Fatima-Ezzahra"), "فاطمة الزهراء");
      expect(ar("NOUR EDDINE"), "نور الدين");
      expect(ar("Mohamed Amine"), "محمد أمين");
    });

    test("Abd suivi d'un nom divin", () {
      expect(ar("ABDELKADER"), "عبد القادر");
      expect(ar("ABDERRAHIM"), "عبد الرحيم");
      expect(ar("ABDESSAMAD"), "عبد الصمد");
      expect(ar("ABDEL AZIZ"), "عبد العزيز");
    });
  });

  group("particules", () {
    test("l'article, détaché, collé ou assimilé", () {
      expect(ar("EL IDRISSI"), "الإدريسي");
      expect(ar("ELIDRISSI"), "الإدريسي");
      expect(ar("ES SAIDI"), "السعيدي");
      expect(ar("ESSAIDI"), "السعيدي");
      expect(ar("EL AMRANI"), "العمراني");
    });

    test("Ben, Aït, Ould", () {
      expect(ar("BENOMAR"), "بنعمر");
      expect(ar("BEN OMAR"), "بن عمر");
      expect(ar("AIT ALI"), "آيت علي");
      expect(ar("OULD AHMED"), "ولد أحمد");
    });
  });

  group("règles, pour les noms absents du dictionnaire", () {
    test("les lettres doubles du français", () {
      expect(ar("KHARBOUCH"), "خربوش");
      expect(ar("OUMGHAR"), "أومغار");
    });

    test("ne produisent que des lettres arabes", () {
      for (final nom in ["ZEROUAL", "BELKHAYAT", "CHOUIREF", "QUASIMODO"]) {
        final t = TranscriptionArabe.transcrire(nom)!;
        expect(t.connu, isFalse);
        expect(RegExp(r"^[ء-ي ]+$").hasMatch(t.arabe), isTrue,
            reason: "$nom → ${t.arabe}");
      }
    });
  });

  group("mémoire de l'agence", () {
    test("l'emporte quand le dictionnaire ignore le nom", () {
      expect(
        TranscriptionArabe.proposer("ZEROUAL",
            memoire: const MemoireNom("زروال", 1)),
        "زروال",
      );
    });

    test("une seule fiche ne contredit pas le dictionnaire", () {
      expect(
        TranscriptionArabe.proposer("YOUSSEF",
            memoire: const MemoireNom("يوسوف", 1)),
        "يوسف",
      );
    });

    test("confirmée par deux clients, elle l'emporte", () {
      expect(
        TranscriptionArabe.proposer("HOUSSAINE",
            memoire: const MemoireNom("حسين", 2)),
        "حسين",
      );
    });
  });

  test("rien à écrire : rien de proposé", () {
    expect(TranscriptionArabe.transcrire(""), isNull);
    expect(TranscriptionArabe.transcrire(null), isNull);
    expect(TranscriptionArabe.transcrire("  - ' "), isNull);
    expect(TranscriptionArabe.proposer(null), isNull);
  });
}
