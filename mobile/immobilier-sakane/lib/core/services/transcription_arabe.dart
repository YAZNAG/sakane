/// Écriture arabe d'un nom lu en lettres latines, comme au Maroc.
///
/// La lecture de l'arabe imprimé sur la CIN restait trop fragile. Le nom
/// en lettres latines, lui, est bien lu : on en déduit l'écriture arabe.
///
/// Trois sources, de la plus sûre à la plus approximative :
///  1. la mémoire de l'agence — l'écriture déjà enregistrée pour le même
///     nom chez d'autres clients (voir [proposer]) ;
///  2. le dictionnaire des prénoms et noms marocains courants ;
///  3. des règles de transcription, pour les noms absents du dictionnaire.
///
/// Tout se fait sur le téléphone, sans connexion : le nom du client n'est
/// envoyé à aucun service extérieur. Le résultat est une proposition, que
/// l'agent vérifie : certaines lettres arabes n'ont pas d'équivalent sûr
/// en lettres latines (س ou ص, ت ou ط, ه ou ح, ع).
class TranscriptionArabe {
  TranscriptionArabe._();

  /// L'écriture proposée pour [latin], ou null s'il n'y a rien à écrire.
  ///
  /// La mémoire de l'agence l'emporte quand le dictionnaire ignore le nom,
  /// ou quand elle est confirmée par au moins deux clients : une seule
  /// fiche mal saisie ne doit pas contredire le dictionnaire.
  static String? proposer(String? latin, {MemoireNom? memoire}) {
    final t = transcrire(latin);
    if (memoire != null && (t == null || !t.connu || memoire.fois >= 2)) {
      return memoire.arabe;
    }
    return t?.arabe;
  }

  /// La transcription de [latin], et si elle vient entièrement du
  /// dictionnaire ([Transcription.connu]).
  static Transcription? transcrire(String? latin) {
    final mots = _cle(latin ?? "").split(" ").where((m) => m.isNotEmpty).toList();
    if (mots.isEmpty) return null;

    _fusionner(mots);

    final sortie = <String>[];
    var connu = true;
    var i = 0;
    while (i < mots.length) {
      // Un nom composé du dictionnaire : FATIMA ZAHRA, EL IDRISSI…
      var trouve = false;
      for (var n = 3; n >= 2; n--) {
        if (i + n > mots.length) continue;
        final groupe = mots.sublist(i, i + n).join(" ");
        final ar = _dico[groupe];
        if (ar != null) {
          sortie.add(ar);
          i += n;
          trouve = true;
          break;
        }
      }
      if (trouve) continue;

      final mot = mots[i];
      final suivant = i + 1 < mots.length ? mots[i + 1] : null;

      // L'article détaché : EL AMRANI, ES SAIDI, ER RAMI…
      if (suivant != null && _estArticle(mot, suivant)) {
        final (ar, ok) = _mot(suivant);
        sortie.add("ال${_sansArticle(ar)}");
        connu &= ok;
        i += 2;
        continue;
      }

      final (ar, ok) = _mot(mot);
      sortie.add(ar);
      connu &= ok;
      i++;
    }

    final arabe = sortie.join(" ").replaceAll(RegExp(r"\s+"), " ").trim();
    if (arabe.isEmpty) return null;
    return Transcription(arabe, connu);
  }

  // ── Préparation ─────────────────────────────────────────────────────

  static const Map<String, String> _accents = {
    "À": "A", "Â": "A", "Ä": "A", "Á": "A",
    "É": "E", "È": "E", "Ê": "E", "Ë": "E",
    "Î": "I", "Ï": "I", "Í": "I",
    "Ô": "O", "Ö": "O", "Ó": "O",
    "Ù": "U", "Û": "U", "Ü": "U", "Ú": "U",
    "Ç": "C", "Ÿ": "Y",
  };

  /// Majuscules sans accents ; tiret, apostrophe et ponctuation deviennent
  /// des espaces.
  static String _cle(String latin) {
    final b = StringBuffer();
    for (final c in latin.toUpperCase().split("")) {
      final s = _accents[c] ?? c;
      b.write(RegExp(r"[A-Z]").hasMatch(s) ? s : " ");
    }
    return b.toString().replaceAll(RegExp(r"\s+"), " ").trim();
  }

  /// Recolle ce que la carte écrit parfois en deux mots :
  /// ABDEL AZIZ → ABDELAZIZ, NOUR EDDINE → NOUREDDINE.
  static void _fusionner(List<String> mots) {
    for (var i = 0; i < mots.length - 1; i++) {
      final m = mots[i], s = mots[i + 1];
      if ({"ABD", "ABDE", "ABDEL", "ABDOU", "ABDAL"}.contains(m) &&
          !_dico.containsKey("$m $s")) {
        mots[i] = m + s;
        mots.removeAt(i + 1);
      } else if ({"EDDINE", "EDINE", "DDINE", "DINE", "IDDINE"}.contains(s)) {
        mots[i] = "${m}EDDINE";
        mots.removeAt(i + 1);
      }
    }
  }

  static bool _estArticle(String mot, String suivant) {
    if (mot == "EL" || mot == "AL") return true;
    // L'article assimilé : ES SAIDI, ER RAMI, ECH CHARKI…
    const assimiles = {
      "ES": "S", "ER": "R", "ET": "T", "ED": "D", "EZ": "Z",
      "EN": "N", "ECH": "CH", "ESS": "S", "ERR": "R", "ETT": "T",
    };
    final c = assimiles[mot];
    return c != null && suivant.startsWith(c);
  }

  static String _sansArticle(String ar) =>
      ar.startsWith("ال") ? ar.substring(2) : ar;

  // ── Un mot ──────────────────────────────────────────────────────────

  /// L'écriture d'un mot, et s'il vient du dictionnaire.
  static (String, bool) _mot(String m) {
    final direct = _dico[m];
    if (direct != null) return (direct, true);

    // Abd + nom divin : ABDELKADER, ABDERRAHIM, ABDESSAMAD…
    if (m.startsWith("ABD") && m.length > 5) {
      for (final debut in ["ABDEL", "ABDAL", "ABDE", "ABDA", "ABD"]) {
        if (!m.startsWith(debut)) continue;
        var reste = m.substring(debut.length);
        // Consonne redoublée de l'article assimilé : ABDE-RRAHIM.
        if (reste.length > 2 && reste[0] == reste[1]) reste = reste.substring(1);
        if (reste.startsWith("CHCH")) reste = reste.substring(2);
        final divin = _divins[reste];
        if (divin != null) return ("عبد $divin", true);
      }
      if (m.startsWith("ABDEL") && m.length > 6) {
        final (ar, ok) = _mot(m.substring(5));
        return ("عبد ال${_sansArticle(ar)}", ok);
      }
    }

    // … + EDDINE : SALAHEDDINE → صلاح الدين.
    for (final fin in ["EDDINE", "EDINE", "IDDINE"]) {
      if (m.endsWith(fin) && m.length > fin.length + 2) {
        final (ar, ok) = _mot(m.substring(0, m.length - fin.length));
        return ("$ar الدين", ok);
      }
    }

    // L'article collé : ELALAMI, ESSAIDI, ECHCHARKI, ERRAMI…
    final colle = RegExp(r"^E(CHCH|SS|RR|TT|DD|ZZ|NN)").firstMatch(m);
    if (colle != null) {
      final reste = m.substring(colle.group(1)!.length ~/ 2 + 1);
      final (ar, ok) = _mot(reste);
      return ("ال${_sansArticle(ar)}", ok);
    }
    if (m.startsWith("EL") && m.length >= 6) {
      final (ar, ok) = _mot(m.substring(2));
      return ("ال${_sansArticle(ar)}", ok);
    }

    // Ben + nom : BENOMAR → بنعمر, BENAHMED → بن أحمد.
    if (m.startsWith("BEN") && m.length > 5) {
      final reste = m.substring(3);
      if (_dico.containsKey(reste)) {
        final ar = _dico[reste]!;
        final hamza = RegExp(r"^[أإآ]").hasMatch(ar);
        return (hamza ? "بن $ar" : "بن$ar", true);
      }
    }

    // Aït + nom collé : AITOUAHMAN → آيت واحمان.
    if (m.startsWith("AIT") && m.length > 5 && !"AEIOUY".contains(m[3])) {
      final (ar, ok) = _mot(m.substring(3));
      return ("آيت $ar", ok);
    }

    return (_regles(m), false);
  }

  // ── Règles ──────────────────────────────────────────────────────────

  static const String _voyelles = "AEIOUY";

  /// Transcription lettre à lettre, selon l'usage marocain des noms
  /// écrits en français. Approximative par nature : elle ne sert que pour
  /// les noms que le dictionnaire ignore.
  static String _regles(String m) {
    final b = StringBuffer();
    final n = m.length;
    var i = 0;

    bool consonne(int k) => k >= 0 && k < n && !_voyelles.contains(m[k]);

    // Longueur de la consonne qui commence en k : 2 pour CH, KH, GH…,
    // 1 pour une lettre seule, 0 pour une voyelle ou la fin du mot.
    int longueurConsonne(int k) {
      if (!consonne(k)) return 0;
      if (k + 1 < n && const {"CH", "KH", "GH", "TH", "PH", "DJ"}
          .contains(m.substring(k, k + 2))) {
        return 2;
      }
      return 1;
    }

    // Syllabe fermée : deux consonnes suivent dans le mot (KHARBOUCH,
    // LAMGHARI). La voyelle y est brève et ne s'écrit pas.
    bool fermee(int k) {
      final c1 = longueurConsonne(k + 1);
      return c1 > 0 && longueurConsonne(k + 1 + c1) > 0;
    }

    while (i < n) {
      final reste = m.substring(i);
      final debut = i == 0;

      // Consonne redoublée : une seule lettre arabe (la chadda ne
      // s'écrit pas dans les noms).
      if (i > 0 && m[i] == m[i - 1] && consonne(i)) {
        i++;
        continue;
      }

      if (reste.startsWith("TCH")) {
        b.write("تش");
        i += 3;
      } else if (reste.startsWith("CH")) {
        b.write("ش");
        i += 2;
      } else if (reste.startsWith("KH")) {
        b.write("خ");
        i += 2;
      } else if (reste.startsWith("GH")) {
        b.write("غ");
        i += 2;
      } else if (reste.startsWith("DJ")) {
        b.write("ج");
        i += 2;
      } else if (reste.startsWith("TH")) {
        b.write("ث");
        i += 2;
      } else if (reste.startsWith("PH")) {
        b.write("ف");
        i += 2;
      } else if (reste.startsWith("QU")) {
        b.write("ق");
        i += 2;
      } else if (reste.startsWith("GU") && n > i + 2 && "EI".contains(m[i + 2])) {
        b.write("ك");
        i += 2;
      } else if (reste.startsWith("OU")) {
        b.write(debut ? "أو" : "و");
        i += 2;
      } else if (reste.startsWith("AA")) {
        b.write("ع");
        i += 2;
      } else if (reste.startsWith("AI") || reste.startsWith("AY")) {
        b.write(debut ? "أي" : "اي");
        i += 2;
      } else if (reste.startsWith("EI") || reste.startsWith("EY")) {
        b.write("ي");
        i += 2;
      } else {
        final c = m[i];
        final fin = i == n - 1;
        switch (c) {
          case "A":
            if (debut) {
              b.write("أ");
            } else if (fin && consonne(i - 1)) {
              b.write("ة"); // FATIHA → فتيحة
            } else if (fermee(i)) {
              // Voyelle brève : non écrite (HAJJAMI → حجامي,
              // KHARBOUCH → خربوش).
            } else {
              b.write("ا");
            }
          case "E":
            if (debut) b.write("إ"); // ailleurs, voyelle brève : non écrite
          case "I":
            b.write(debut ? "إ" : "ي");
          case "O":
            b.write(debut ? "أ" : "و");
          case "U":
            b.write(debut ? "أو" : "و");
          case "Y":
            b.write("ي");
          case "C":
            b.write(n > i + 1 && "EIY".contains(m[i + 1]) ? "س" : "ك");
          case "G":
            b.write(n > i + 1 && "EI".contains(m[i + 1]) ? "ج" : "ك");
          case "H":
            b.write(fin ? "ه" : "ح");
          default:
            b.write(_lettres[c] ?? "");
        }
        i++;
      }
    }
    return b.toString();
  }

  static const Map<String, String> _lettres = {
    "B": "ب", "D": "د", "F": "ف", "J": "ج", "K": "ك", "L": "ل",
    "M": "م", "N": "ن", "P": "ب", "Q": "ق", "R": "ر", "S": "س",
    "T": "ت", "V": "ف", "W": "و", "X": "كس", "Z": "ز",
  };

  // ── Dictionnaire ────────────────────────────────────────────────────

  /// Les noms divins qui suivent « Abd » : ABDELKADER → عبد القادر.
  static const Map<String, String> _divins = {
    "ALLAH": "الله", "LLAH": "الله", "LAH": "الله", "LLA": "الله", "ELLAH": "الله",
    "KADER": "القادر", "KADIR": "القادر", "QADER": "القادر", "QADIR": "القادر",
    "RAHIM": "الرحيم", "RAHMANE": "الرحمان", "RAHMAN": "الرحمان",
    "AZIZ": "العزيز", "HAK": "الحق", "HAQ": "الحق", "HAKK": "الحق",
    "ILAH": "الإله", "ILLAH": "الإله", "ILAHE": "الإله",
    "JALIL": "الجليل", "KRIM": "الكريم", "KARIM": "الكريم",
    "LATIF": "اللطيف", "LATIFE": "اللطيف", "MAJID": "المجيد",
    "MALEK": "المالك", "MALIK": "المالك",
    "OUAHED": "الواحد", "WAHED": "الواحد", "OUAHID": "الواحد", "WAHID": "الواحد",
    "SAMAD": "الصمد", "SALAM": "السلام", "SLAM": "السلام", "SALEM": "السلام",
    "GHANI": "الغني", "HADI": "الهادي", "HAMID": "الحميد", "HAKIM": "الحكيم",
    "FATTAH": "الفتاح", "FETTAH": "الفتاح", "FATAH": "الفتاح",
    "MOUNAIM": "المنعم", "MONAIM": "المنعم", "MOUNIM": "المنعم", "MOUNEIM": "المنعم",
    "NOUR": "النور", "RAZAK": "الرزاق", "RAZZAK": "الرزاق", "RAZAQ": "الرزاق",
    "ALI": "العالي", "AALI": "العالي",
    "OUAHAB": "الوهاب", "WAHAB": "الوهاب", "OUAHHAB": "الوهاب",
    "BASSET": "الباسط", "BASSIT": "الباسط", "HAFID": "الحفيظ", "HAFIDE": "الحفيظ",
    "MOUMEN": "المومن", "MOUMIN": "المومن", "KHALEK": "الخالق", "KHALIK": "الخالق",
    "RAOUF": "الرؤوف", "JABBAR": "الجبار", "KABIR": "الكبير",
    "MOUTALIB": "المطلب", "MOUTTALIB": "المطلب",
    "NACER": "الناصر", "NASSER": "الناصر", "NASSAR": "الناصر",
    "AADIM": "العظيم", "ADIM": "العظيم", "AZIM": "العظيم", "ADIME": "العظيم",
    "MOUGHIT": "المغيث", "SATTAR": "الستار", "HALIM": "الحليم",
    "OUADOUD": "الودود", "WADOUD": "الودود", "HAY": "الحي", "HAI": "الحي",
    "KARIME": "الكريم", "MAJIDE": "المجيد", "HAMIDE": "الحميد",
  };

  /// Prénoms, noms de famille et particules, sous leurs graphies
  /// courantes sur les CIN marocaines.
  static final Map<String, String> _dico = {
    // Particules et titres
    "BEN": "بن", "BENT": "بنت", "OULD": "ولد", "AIT": "آيت", "AYT": "آيت",
    "BOU": "بو", "SIDI": "سيدي", "LALLA": "لالة", "MOULAY": "مولاي",
    "MOULAI": "مولاي", "HAJ": "الحاج", "HADJ": "الحاج", "LHAJ": "الحاج",
    "EL HAJ": "الحاج", "ABOU": "أبو", "ABOU BAKR": "أبو بكر",

    // Prénoms masculins
    "MOHAMED": "محمد", "MOHAMMED": "محمد", "MOHAMMAD": "محمد", "MOHAMAD": "محمد",
    "MOUHAMED": "محمد", "MUHAMMAD": "محمد", "MOHAMMADE": "محمد",
    "MHAMED": "امحمد", "MHAMMED": "امحمد",
    "AHMED": "أحمد", "AHMAD": "أحمد", "MAHMOUD": "محمود",
    "MUSTAPHA": "مصطفى", "MOUSTAPHA": "مصطفى", "MUSTAFA": "مصطفى",
    "MOSTAFA": "مصطفى", "MOSTAPHA": "مصطفى", "MOUSTAFA": "مصطفى",
    "YOUSSEF": "يوسف", "YOUSEF": "يوسف", "YOUSSOUF": "يوسف", "YOUSSUF": "يوسف",
    "YOUNES": "يونس", "YOUNESS": "يونس", "YOUNOUS": "يونس",
    "YASSINE": "ياسين", "YASINE": "ياسين", "YACINE": "ياسين", "YASSIN": "ياسين",
    "YASSIR": "ياسر", "YASSER": "ياسر", "YASIR": "ياسر",
    "ZAKARIA": "زكرياء", "ZAKARIAE": "زكرياء", "ZAKARYA": "زكرياء",
    "ZAKARIYA": "زكرياء", "ZAKARIAA": "زكرياء",
    "HAMZA": "حمزة", "HASSAN": "حسن", "HASAN": "حسن", "HASSANE": "حسن",
    "HOUSSAINE": "الحسين", "HOUSSINE": "الحسين", "HOUCINE": "الحسين",
    "HUSSEIN": "الحسين", "HOUSSEIN": "الحسين", "HOUSSAIN": "الحسين",
    "LAHCEN": "لحسن", "LAHSEN": "لحسن", "LHASSAN": "لحسن",
    "LHOUSSAINE": "لحسين", "LAHOUCINE": "لحسين", "LHOUSSINE": "لحسين",
    "LAHOUSSAINE": "لحسين",
    "OMAR": "عمر", "OUMAR": "عمر", "OTHMANE": "عثمان", "OTMANE": "عثمان",
    "OUTHMANE": "عثمان", "OTHMAN": "عثمان", "ALI": "علي",
    "ABDELLAH": "عبد الله", "ABDALLAH": "عبد الله", "ABDELLA": "عبد الله",
    "ABDELAH": "عبد الله", "ABDOU": "عبدو",
    "BRAHIM": "إبراهيم", "IBRAHIM": "إبراهيم", "IBRAHIME": "إبراهيم",
    "ISMAIL": "إسماعيل", "SMAIL": "إسماعيل", "ISMAEL": "إسماعيل", "ISMAIN": "إسماعيل",
    "DRISS": "إدريس", "IDRISS": "إدريس", "IDRIS": "إدريس",
    "ILYAS": "إلياس", "ILIAS": "إلياس", "ELIAS": "إلياس", "ILYASS": "إلياس",
    "ILIASS": "إلياس",
    "ANAS": "أنس", "ANASS": "أنس", "AMINE": "أمين", "AMIN": "أمين",
    "LAMINE": "الأمين", "AYOUB": "أيوب", "AYOUBE": "أيوب",
    "ADIL": "عادل", "ADEL": "عادل", "AZIZ": "عزيز",
    "AZZEDINE": "عز الدين", "AZEDDINE": "عز الدين", "AZZEDDINE": "عز الدين",
    "EZZEDINE": "عز الدين", "EZZEDDINE": "عز الدين", "IZZEDDINE": "عز الدين",
    "BADR": "بدر", "BADER": "بدر", "BADREDDINE": "بدر الدين",
    "BILAL": "بلال", "CHAKIB": "شكيب", "FOUAD": "فؤاد",
    "FAYCAL": "فيصل", "FAISSAL": "فيصل", "FAISAL": "فيصل", "FAYSSAL": "فيصل",
    "HAKIM": "حكيم", "HAMID": "حميد", "HICHAM": "هشام", "HISHAM": "هشام",
    "HATIM": "حاتم", "IMAD": "عماد", "IMADE": "عماد", "IMADEDDINE": "عماد الدين",
    "IMRANE": "عمران", "IMRAN": "عمران", "JAMAL": "جمال",
    "JAMALEDDINE": "جمال الدين", "JALAL": "جلال", "JALALEDDINE": "جلال الدين",
    "JAWAD": "جواد", "JAOUAD": "جواد", "KAMAL": "كمال", "KARIM": "كريم",
    "KHALID": "خالد", "KHALED": "خالد", "LARBI": "العربي",
    "MEHDI": "المهدي", "MAHDI": "المهدي", "MOURAD": "مراد",
    "MOUAD": "معاذ", "MOAD": "معاذ", "MOUAAD": "معاذ", "MOUADH": "معاذ",
    "MOHCINE": "محسن", "MOHSINE": "محسن", "MOHSIN": "محسن", "MOHSSINE": "محسن",
    "MOHSEN": "محسن", "MOUNIR": "منير", "NABIL": "نبيل", "NAJIB": "نجيب",
    "NOUREDDINE": "نور الدين", "NOUREDINE": "نور الدين", "NOUR": "نور",
    "OUSSAMA": "أسامة", "OUSAMA": "أسامة", "OSAMA": "أسامة",
    "RACHID": "رشيد", "RACHIDE": "رشيد", "REDA": "رضا", "RIDA": "رضا",
    "REDOUANE": "رضوان", "REDOUAN": "رضوان", "RIDOUANE": "رضوان",
    "RIDOUAN": "رضوان", "RADOUANE": "رضوان", "REDWANE": "رضوان", "RIDWANE": "رضوان",
    "SAID": "سعيد", "SAAID": "سعيد", "SAAD": "سعد", "SALAH": "صلاح",
    "SALAHEDDINE": "صلاح الدين", "SALIM": "سليم", "SELIM": "سليم",
    "SAMIR": "سمير", "SOUFIANE": "سفيان", "SOFIANE": "سفيان", "SOUFYANE": "سفيان",
    "SOULAIMANE": "سليمان", "SOULAYMANE": "سليمان", "SLIMANE": "سليمان",
    "SULAIMAN": "سليمان", "SOULEIMANE": "سليمان",
    "TAHA": "طه", "TARIK": "طارق", "TARIQ": "طارق",
    "TAOUFIK": "توفيق", "TAWFIK": "توفيق", "TOUFIK": "توفيق", "TAOUFIQ": "توفيق",
    "WALID": "وليد", "OUALID": "وليد", "YAHYA": "يحيى", "YAHIA": "يحيى",
    "ZOUHAIR": "زهير", "ZOUHIR": "زهير", "ZUHAIR": "زهير", "ZOUHEIR": "زهير",
    "ZAKI": "زكي", "ANOUAR": "أنور", "ANWAR": "أنور", "ACHRAF": "أشرف",
    "AMMAR": "عمار", "AYMANE": "أيمن", "AIMANE": "أيمن", "AYMAN": "أيمن",
    "BOUCHAIB": "بوشعيب", "BOUJEMAA": "بوجمعة", "BOUAZZA": "بوعزة",
    "BOUBKER": "بوبكر", "BOUBAKER": "بوبكر", "ABOUBAKR": "أبو بكر",
    "DAOUD": "داود", "DAWOUD": "داود", "FARID": "فريد",
    "HAMMOU": "حمو", "HAMOU": "حمو", "HOUSSAM": "حسام", "HOSSAM": "حسام",
    "JILALI": "الجيلالي", "KADDOUR": "قدور", "LAHBIB": "لحبيب", "HABIB": "حبيب",
    "MAROUANE": "مروان", "MARWANE": "مروان", "MARWAN": "مروان",
    "MBAREK": "امبارك", "MOUBARAK": "مبارك", "MILOUD": "ميلود",
    "MOUSSA": "موسى", "MOSSA": "موسى", "NACER": "ناصر", "NASSER": "ناصر",
    "NAOUFAL": "نوفل", "NAWFAL": "نوفل", "NOUFAL": "نوفل",
    "RAYANE": "ريان", "RAYAN": "ريان", "SAFOUANE": "صفوان", "SAFWANE": "صفوان",
    "SAMI": "سامي", "SELMANE": "سلمان", "SALMANE": "سلمان",
    "TAIB": "الطيب", "TAYEB": "الطيب", "WASSIM": "وسيم", "OUASSIM": "وسيم",
    "ZIAD": "زياد", "ADAM": "آدم", "AMIR": "أمير", "ANIS": "أنيس",
    "FAHD": "فهد", "FARES": "فارس", "HAROUN": "هارون", "ISSAM": "عصام",
    "JAAFAR": "جعفر", "JAFAR": "جعفر", "KHALIL": "خليل", "LOTFI": "لطفي",
    "MALIK": "مالك", "NAIM": "نعيم", "RABIE": "ربيع", "RABII": "ربيع",
    "RAMI": "رامي", "RIAD": "رياض", "RIYAD": "رياض", "SABER": "صابر",
    "SEDDIK": "الصديق", "SADDIK": "الصديق", "SOUHAIL": "سهيل", "SOHAIL": "سهيل",
    "TAHAR": "الطاهر", "YAKOUB": "يعقوب", "YAQOUB": "يعقوب",
    "ZAID": "زيد", "ZAYD": "زيد", "ZOUBIR": "الزبير", "ABBAS": "عباس",
    "AKRAM": "أكرم", "ALAE": "علاء", "ALAA": "علاء", "ALAEDDINE": "علاء الدين",
    "AMJAD": "أمجد", "CHAFIK": "شفيق", "GHALI": "غالي",
    "HAITAM": "هيثم", "HAYTAM": "هيثم", "HAITHAM": "هيثم",
    "KACEM": "قاسم", "KASSEM": "قاسم", "LOUKMANE": "لقمان", "LOQMANE": "لقمان",
    "MOKHTAR": "المختار", "MOKTAR": "المختار",
    "NOUAMANE": "نعمان", "NOUMANE": "نعمان", "NOAMANE": "نعمان",
    "OUAIL": "وائل", "WAIL": "وائل", "RACHAD": "رشاد",
    "CHAMSEDDINE": "شمس الدين", "KHEIREDDINE": "خير الدين",
    "SAIFEDDINE": "سيف الدين", "ZINEDDINE": "زين الدين", "TAJEDDINE": "تاج الدين",
    "NASREDDINE": "نصر الدين", "FAKHREDDINE": "فخر الدين",
    "ABDELHAK": "عبد الحق", "ABDERRAHMANE": "عبد الرحمان", "ABDERRAHIM": "عبد الرحيم",
    "HOUSSAINI": "الحسيني",

    // Prénoms féminins
    "FATIMA": "فاطمة", "FATMA": "فاطمة", "FATIMA ZAHRA": "فاطمة الزهراء",
    "FATIMAZAHRA": "فاطمة الزهراء", "FATIMA EZZAHRA": "فاطمة الزهراء",
    "FATIMAEZZAHRA": "فاطمة الزهراء", "FATIMEZZAHRA": "فاطمة الزهراء",
    "FATIMA ZOHRA": "فاطمة الزهراء", "FATIHA": "فتيحة",
    "KHADIJA": "خديجة", "KHADIJAH": "خديجة", "AICHA": "عائشة", "AISHA": "عائشة",
    "AYCHA": "عائشة", "MARIAM": "مريم", "MARYAM": "مريم", "MERYEM": "مريم",
    "MERIEM": "مريم", "MARIEM": "مريم", "MERYAM": "مريم",
    "ZINEB": "زينب", "ZAINAB": "زينب", "ZAYNAB": "زينب", "ZINAB": "زينب",
    "SALMA": "سلمى", "SARA": "سارة", "SARAH": "سارة", "HAJAR": "هاجر", "HAJER": "هاجر",
    "HANANE": "حنان", "HANAN": "حنان", "HIND": "هند", "HOUDA": "هدى", "HODA": "هدى",
    "IMANE": "إيمان", "IMAN": "إيمان", "IKRAM": "إكرام", "IKRAME": "إكرام",
    "KAWTAR": "كوثر", "KAOUTAR": "كوثر", "KAOUTHAR": "كوثر", "KAWTHAR": "كوثر",
    "LAILA": "ليلى", "LEILA": "ليلى", "LAYLA": "ليلى", "LATIFA": "لطيفة",
    "LOUBNA": "لبنى", "MALIKA": "مليكة", "NADIA": "نادية", "NAIMA": "نعيمة",
    "NAJAT": "نجاة", "NISRINE": "نسرين", "NESRINE": "نسرين",
    "NOURA": "نورة", "NORA": "نورة", "OUMAIMA": "أميمة", "OUMAYMA": "أميمة",
    "OMAIMA": "أميمة", "RACHIDA": "رشيدة", "SAIDA": "سعيدة", "SAMIRA": "سميرة",
    "SANAE": "سناء", "SANAA": "سناء", "SANA": "سناء", "SIHAM": "سهام", "SIHAME": "سهام",
    "SOUAD": "سعاد", "SOUKAINA": "سكينة", "SOUKAYNA": "سكينة", "SOKAINA": "سكينة",
    "WAFAE": "وفاء", "WAFAA": "وفاء", "WAFA": "وفاء",
    "YASMINE": "ياسمين", "YASMINA": "ياسمينة", "YASMIN": "ياسمين",
    "ZAHRA": "زهرة", "ZOHRA": "زهرة", "ASMAE": "أسماء", "ASMAA": "أسماء",
    "ASMA": "أسماء", "AMINA": "أمينة", "BOUCHRA": "بشرى", "BOCHRA": "بشرى",
    "CHAIMAE": "شيماء", "CHAIMAA": "شيماء", "CHAYMAE": "شيماء", "CHAIMA": "شيماء",
    "DOUNIA": "دنيا", "DONIA": "دنيا", "FADWA": "فدوى", "FADOUA": "فدوى",
    "GHIZLANE": "غزلان", "GHIZLAN": "غزلان", "HALIMA": "حليمة",
    "HASNAA": "حسناء", "HASNAE": "حسناء", "HASNA": "حسناء", "JAMILA": "جميلة",
    "KARIMA": "كريمة", "KHAWLA": "خولة", "KHAOULA": "خولة",
    "MOUNIA": "منية", "MOUNYA": "منية", "MOUNA": "منى", "MONA": "منى",
    "NAWAL": "نوال", "NAOUAL": "نوال", "RAJAE": "رجاء", "RAJAA": "رجاء",
    "RIM": "ريم", "RIME": "ريم", "SOFIA": "صوفيا", "WIDAD": "وداد", "OUIDAD": "وداد",
    "YOUSRA": "يسرى", "YOSRA": "يسرى", "ZAKIA": "زكية", "AHLAM": "أحلام",
    "BAHIJA": "بهيجة", "BASMA": "بسمة", "FARAH": "فرح", "HABIBA": "حبيبة",
    "HAYAT": "حياة", "HIBA": "هبة", "IBTISSAM": "ابتسام", "IBTISAM": "ابتسام",
    "ILHAM": "إلهام", "ELHAM": "إلهام", "INSAF": "إنصاف",
    "JIHANE": "جيهان", "JIHAN": "جيهان", "KENZA": "كنزة",
    "LAMIAE": "لمياء", "LAMIAA": "لمياء", "LAMIA": "لمياء", "MAJDA": "ماجدة",
    "MANAL": "منال", "MARWA": "مروة", "MAROUA": "مروة", "NADA": "ندى",
    "NOUHAILA": "نهيلة", "NOUHAYLA": "نهيلة", "RANIA": "رانية", "RIHAB": "رحاب",
    "SALWA": "سلوى", "SALOUA": "سلوى", "SOUMIA": "سمية", "SOUMAYA": "سمية",
    "SOUMAIA": "سمية", "TOURIA": "ثريا", "TORIA": "ثريا", "THOURAYA": "ثريا",
    "WISSAL": "وصال", "WISAL": "وصال", "YAMINA": "يمينة", "ZHOR": "زهور",
    "AWATIF": "عواطف", "FAIZA": "فايزة", "MINA": "مينة",
    "RKIA": "رقية", "RQIA": "رقية", "ROKAYA": "رقية", "ROKIA": "رقية",
    "ITTO": "إطو", "MALAK": "ملاك", "AYA": "آية", "DOHA": "ضحى",
    "ASSIA": "آسية", "ASIA": "آسية", "AMAL": "أمل", "NAJWA": "نجوى", "NAJOUA": "نجوى",
    "HAFSA": "حفصة", "SAFAA": "صفاء", "SAFAE": "صفاء", "SOUHAILA": "سهيلة",
    "OUIAM": "وئام", "WIAM": "وئام", "WIJDANE": "وجدان", "NOUHA": "نهى",
    "ZINEBE": "زينب", "MERIAM": "مريم", "HAFIDA": "حفيظة", "LATIFAA": "لطيفة",
    "MOUNIRA": "منيرة", "NABILA": "نبيلة", "NAZHA": "نزهة", "RABIA": "ربيعة",
    "SAADIA": "سعدية", "SAFIA": "صفية", "ZOULIKHA": "زليخة", "FOUZIA": "فوزية",
    "KHADOUJ": "خدوج", "FADILA": "فضيلة", "KHAIRA": "خيرة", "MAMA": "ماما",
    "HNIA": "هنية", "HADDA": "حادة", "TAMOU": "تامو",

    // Noms de famille
    "ALAOUI": "العلوي", "LALAOUI": "العلوي", "IDRISSI": "الإدريسي",
    "DRISSI": "الإدريسي", "BENNANI": "بناني", "TAZI": "التازي", "FASSI": "الفاسي",
    "BERRADA": "برادة", "CHRAIBI": "الشرايبي", "SQALLI": "السقلي",
    "SKALLI": "السقلي", "KETTANI": "الكتاني", "LAHLOU": "لحلو",
    "BENJELLOUN": "بنجلون", "GUESSOUS": "كسوس", "SEBTI": "السبتي",
    "OUAZZANI": "الوزاني", "OUAZANI": "الوزاني", "AMRANI": "العمراني",
    "LAMRANI": "العمراني", "MANSOURI": "المنصوري", "HASSANI": "الحسني",
    "BOUZIDI": "البوزيدي", "ZIANI": "الزياني", "FILALI": "الفيلالي",
    "SAIDI": "السعيدي", "NACIRI": "الناصري", "NASSIRI": "الناصري",
    "BAKKALI": "البقالي", "KABBAJ": "القباج", "BENSAID": "بنسعيد",
    "BENALI": "بنعلي", "BENMOUSSA": "بنموسى", "BENKIRANE": "بنكيران",
    "BENCHEKROUN": "بنشقرون", "BENABDELLAH": "بنعبد الله", "BELHAJ": "بلحاج",
    "MOUSSAOUI": "الموساوي", "SOUSSI": "السوسي", "MARRAKCHI": "المراكشي",
    "ZEMMOURI": "الزموري", "DOUKKALI": "الدكالي", "CHAOUI": "الشاوي",
    "GHARBI": "الغربي", "CHERKAOUI": "الشرقاوي", "CHARKAOUI": "الشرقاوي",
    "KADIRI": "القادري", "TAHIRI": "الطاهري", "RIFI": "الريفي", "RIFFI": "الريفي",
    "JAMAI": "الجامعي", "OUALI": "الوالي", "NAJI": "الناجي", "HAJJI": "الحجي",
    "SLAOUI": "السلاوي", "HAMDAOUI": "الحمداوي", "OUHADDOU": "أوحدو",
    "AKHANNOUCH": "أخنوش", "OUAHBI": "وهبي", "RAHALI": "الرحالي",
    "KHATIB": "الخطيب", "KHATTABI": "الخطابي", "HAMMOUCHI": "الحموشي",
    "ZNIBER": "زنيبر", "LAZRAK": "الأزرق", "AZZOUZI": "العزوزي",
    "OUMOUSSA": "أوموسى", "BENHIMA": "بنهيمة", "BENCHEIKH": "بنشيخ",
    "BENOMAR": "بنعمر", "BENAISSA": "بنعيسى", "BENBRAHIM": "بنبراهيم",
    "BENTALEB": "بنطالب", "BENYAHIA": "بنيحيى", "DAHBI": "الذهبي",
    "DAOUDI": "الداودي", "GHAZI": "الغازي", "HAMIDI": "الحميدي", "JABRI": "الجابري",
    "KARIMI": "الكريمي", "KHALIDI": "الخالدي", "MOKHTARI": "المختاري",
    "NAIMI": "النعيمي", "OMARI": "العمري", "OUMARI": "العمري", "RACHIDI": "الرشيدي",
    "SABRI": "الصبري", "SALHI": "الصالحي", "SEDDIKI": "الصديقي",
    "SLIMANI": "السليماني", "TOUNSI": "التونسي", "YOUSFI": "اليوسفي",
    "ZAHIRI": "الظاهري", "AZIZI": "العزيزي", "BAKRI": "البكري",
    "BOUKHARI": "البخاري", "FARISSI": "الفارسي", "HAJOUI": "الحجوي",
    "HILALI": "الهلالي", "JAZOULI": "الجزولي", "KHALFI": "الخلفي",
    "MEKNASSI": "المكناسي", "NAJMI": "النجمي", "OUDGHIRI": "الودغيري",
    "SAHRAOUI": "الصحراوي", "TOUZANI": "التوزاني", "ZERHOUNI": "الزرهوني",
    "AMMARI": "العماري", "ABBADI": "العبادي", "BENNIS": "بنيس", "BENSOUDA": "بنسودة",
    "BOUAYAD": "بوعياد", "CHAMI": "الشامي", "GUEDIRA": "كديرة", "IRAQI": "العراقي",
    "JOUAHRI": "الجواهري", "LAHBABI": "الحبابي", "MEKOUAR": "مكوار",
    "SEFRIOUI": "الصفريوي", "HOUSNI": "الحسني", "AMGHAR": "أمغار",
    "OUFKIR": "أوفقير", "BOUABID": "بوعبيد", "YOUSSOUFI": "اليوسفي",
    "MOUTAWAKIL": "المتوكل", "BERRAHOU": "براهو", "MAHFOUD": "محفوظ",
    "BOUHLAL": "بوهلال", "AMAR": "عمار", "AZOUGAGH": "أزوغاغ",
    "ELOUAFI": "الوافي", "OUAFI": "الوافي", "HAMRI": "الحمري", "BAHI": "الباهي",
    "SENHAJI": "الصنهاجي", "SANHAJI": "الصنهاجي", "TOUIMI": "التويمي",
    "LAKHDAR": "لخضر", "BOUCHTA": "بوشتى", "BOUSSAID": "بوسعيد",
    "ANNASSIRI": "الناصري", "HARTI": "الحارثي", "SAADI": "السعدي",
    "TIJANI": "التيجاني", "DOUIRI": "الدويري", "ALAMI": "العلمي",
    "LALAMI": "العلمي", "BERRADI": "البرادي", "CHAKIR": "شاكر", "HAJJAJ": "الحجاج",
    "BAKOUR": "باكور", "NOUINI": "النويني", "MOUMNI": "المومني",
    "ZAHRAOUI": "الزهراوي", "ZAOUI": "الزاوي", "KANDOUSSI": "القندوسي",
    "AFILAL": "أفيلال", "OUZZANI": "الوزاني", "BARAKA": "بركة",
    "CHARKI": "الشرقي", "GHARBAOUI": "الغرباوي", "FASSIHI": "الفصيحي",
  };
}

/// Le résultat d'une transcription.
class Transcription {
  final String arabe;

  /// Vrai si chaque mot vient du dictionnaire : aucune règle approximative.
  final bool connu;

  const Transcription(this.arabe, this.connu);
}

/// L'écriture arabe déjà enregistrée par l'agence pour un nom, et le
/// nombre de clients qui la portent.
class MemoireNom {
  final String arabe;
  final int fois;

  const MemoireNom(this.arabe, this.fois);

  static MemoireNom? depuisJson(dynamic json) {
    if (json is! Map) return null;
    final arabe = json["arabe"];
    if (arabe is! String || arabe.trim().isEmpty) return null;
    return MemoireNom(arabe.trim(), (json["fois"] as num?)?.toInt() ?? 1);
  }
}
