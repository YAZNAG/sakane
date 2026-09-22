import 'dart:convert';
import 'dart:io';

import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/core/services/shared_pref_service.dart';
import 'package:immobilier/models/address.dart';
import 'package:immobilier/models/category.dart';
import 'package:immobilier/models/city.dart';
import 'package:immobilier/models/dossier.dart';
import 'package:immobilier/models/etat.dart';
import 'package:immobilier/models/feature.dart';
import 'package:immobilier/models/location.dart';
import 'package:immobilier/models/owner.dart';
import 'package:immobilier/models/realestate.dart';
import 'package:immobilier/models/region.dart';
import 'package:immobilier/models/secteur.dart';
import 'package:immobilier/models/type_transaction.dart';
import 'package:immobilier/models/vente.dart';
import 'package:path_provider/path_provider.dart';

// Brouillons de l'ajout d'un bien. Ils restent sur ce telephone : la saisie
// dans les preferences, les photos copiees dans le dossier de l'application.

Map<String, dynamic>? _objet(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : null;

int? _entier(dynamic v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}');

String? _texte(dynamic v) {
  final t = v?.toString();
  return (t == null || t.isEmpty) ? null : t;
}

class BrouillonBien {
  final String id;
  final DateTime modifieLe;

  /// Etape ou reprendre : mandat, signature, base, location, details, features, images.
  final String etape;

  /// Le mandat choisi (vente) ; on le relit sur le serveur a la reprise.
  final int? mandatId;
  final String? mandatProprietaire;
  final bool mandatSigne;

  /// L'agent a choisi de continuer sans mandat.
  final bool sansMandat;

  /// La saisie du bien, voir [Brouillons.champsDuBien].
  final Map<String, dynamic> bien;

  /// Photos copiees dans le dossier de l'application.
  final List<String> images;

  const BrouillonBien({
    required this.id,
    required this.modifieLe,
    this.etape = 'base',
    this.mandatId,
    this.mandatProprietaire,
    this.mandatSigne = false,
    this.sansMandat = false,
    this.bien = const {},
    this.images = const [],
  });

  String get titre {
    final t = _texte(bien['title'])?.trim();
    if (t != null && t.isNotEmpty) return t;
    if ((mandatProprietaire ?? '').isNotEmpty) return 'Bien de $mandatProprietaire';
    return 'Bien sans titre';
  }

  String? get typeTransaction => _texte(_objet(bien['typeTransaction'])?['value']);

  int? get dossierId => _entier(_objet(bien['dossier'])?['id']);

  String? get dossierNom => _texte(_objet(bien['dossier'])?['nom']);

  double? get prix => (bien['price'] as num?)?.toDouble();

  /// Les photos encore presentes sur le telephone.
  List<File> get fichiers => images.map(File.new).where((f) => f.existsSync()).toList();

  Map<String, dynamic> toJson() => {
        'id': id,
        'modifieLe': modifieLe.toIso8601String(),
        'etape': etape,
        'mandatId': mandatId,
        'mandatProprietaire': mandatProprietaire,
        'mandatSigne': mandatSigne,
        'sansMandat': sansMandat,
        'bien': bien,
        'images': images,
      };

  factory BrouillonBien.fromJson(Map<String, dynamic> json) => BrouillonBien(
        id: json['id'].toString(),
        modifieLe: DateTime.tryParse('${json['modifieLe']}') ?? DateTime.now(),
        etape: _texte(json['etape']) ?? 'base',
        mandatId: _entier(json['mandatId']),
        mandatProprietaire: _texte(json['mandatProprietaire']),
        mandatSigne: json['mandatSigne'] == true,
        sansMandat: json['sansMandat'] == true,
        bien: _objet(json['bien']) ?? const {},
        images: ((json['images'] as List?) ?? const []).map((e) => e.toString()).toList(),
      );

  /// Mandat minimal, en attendant sa relecture sur le serveur.
  MandatVente? get mandat => mandatId == null
      ? null
      : MandatVente(id: mandatId!, proprietaireNom: mandatProprietaire ?? '', signe: mandatSigne);
}

class Brouillons {
  static const String _cle = 'brouillons_biens';

  static SharedPrefService get _prefs => Dependencies.get<SharedPrefService>();

  /// Du plus recent au plus ancien.
  static List<BrouillonBien> tous() {
    try {
      final brut = _prefs.getValue<String>(_cle, '');
      if (brut.isEmpty) return [];
      final liste = (jsonDecode(brut) as List)
          .whereType<Map>()
          .map((e) => BrouillonBien.fromJson(Map<String, dynamic>.from(e)))
          .toList()
        ..sort((a, b) => b.modifieLe.compareTo(a.modifieLe));
      return liste;
    } catch (_) {
      return [];
    }
  }

  /// [type] : famille (selle…) ; [dossierId] : null garde tous les dossiers.
  static List<BrouillonBien> filtrer({String? type, int? dossierId}) => tous()
      .where((b) => type == null || b.typeTransaction == type)
      .where((b) => dossierId == null || b.dossierId == dossierId)
      .toList();

  static BrouillonBien? lire(String id) {
    for (final b in tous()) {
      if (b.id == id) return b;
    }
    return null;
  }

  static void _ecrire(List<BrouillonBien> liste) {
    _prefs.putValue(_cle, jsonEncode(liste.map((b) => b.toJson()).toList()));
  }

  static Future<Directory> _dossierImages(String id) async {
    final racine = await getApplicationDocumentsDirectory();
    final dir = Directory('${racine.path}${Platform.pathSeparator}brouillons_biens${Platform.pathSeparator}$id');
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
  }

  /// Cree ou remplace un brouillon. Les photos choisies sont copiees : le
  /// cache du selecteur d'images peut etre vide par le systeme.
  static Future<BrouillonBien> enregistrer({
    String? id,
    required Realestate bien,
    required String etape,
    MandatVente? mandat,
    bool sansMandat = false,
  }) async {
    final cle = id ?? DateTime.now().millisecondsSinceEpoch.toString();
    final dir = await _dossierImages(cle);
    final images = <String>[];
    var n = 0;
    for (final f in bien.files ?? const <File>[]) {
      if (!f.existsSync()) continue;
      if (f.parent.path == dir.path) {
        images.add(f.path);
        continue;
      }
      final nom = f.uri.pathSegments.isEmpty ? 'photo.jpg' : f.uri.pathSegments.last;
      final copie = await f.copy('${dir.path}${Platform.pathSeparator}${DateTime.now().millisecondsSinceEpoch}_${n++}_$nom');
      images.add(copie.path);
    }
    // Les photos retirees de la saisie quittent aussi le telephone.
    for (final e in dir.listSync()) {
      if (e is File && !images.contains(e.path)) {
        try {
          e.deleteSync();
        } catch (_) {}
      }
    }

    final brouillon = BrouillonBien(
      id: cle,
      modifieLe: DateTime.now(),
      etape: etape,
      mandatId: mandat?.id,
      mandatProprietaire: mandat?.proprietaireNom,
      mandatSigne: mandat?.signe ?? false,
      sansMandat: sansMandat,
      bien: champsDuBien(bien),
      images: images,
    );
    final liste = tous()..removeWhere((b) => b.id == cle);
    _ecrire([brouillon, ...liste]);
    return brouillon;
  }

  static Future<void> supprimer(String id) async {
    _ecrire(tous()..removeWhere((b) => b.id == id));
    try {
      final dir = await _dossierImages(id);
      if (dir.existsSync()) await dir.delete(recursive: true);
    } catch (_) {}
  }

  /// La saisie, references comprises (id et libelle) : elle se relit sans le serveur.
  static Map<String, dynamic> champsDuBien(Realestate r) => {
        'title': r.title,
        'description': r.description,
        'price': r.price,
        'surface': r.surface,
        'tour360Url': r.tour360Url,
        'dateConstruction': r.dateConstruction?.toIso8601String(),
        'nbEtages': r.nbEtages,
        'nbRooms': r.nbRooms,
        'etage': r.etage,
        'nbBathroom': r.nbBathroom,
        if (r.category != null) 'category': r.category!.toJson(),
        if (r.etat != null) 'etat': r.etat!.toJson(),
        if (r.typeTransaction != null) 'typeTransaction': r.typeTransaction!.toJson(),
        if (r.owner != null) 'owner': {'id': r.owner!.id, 'name': r.owner!.name, 'tel': r.owner!.tel},
        if (r.address?.region != null) 'region': {'id': r.address!.region!.id, 'name': r.address!.region!.name},
        if (r.address?.city != null) 'city': {'id': r.address!.city!.id, 'name': r.address!.city!.name},
        'address': r.address?.address,
        'latitude': r.location?.latitude,
        'longitude': r.location?.longitude,
        if (r.secteur != null) 'secteur': r.secteur!.toJson(),
        if (r.dossier != null) 'dossier': {'id': r.dossier!.id, 'nom': r.dossier!.nom},
        'features': (r.features ?? const <Feature>[]).map((f) => f.id).whereType<int>().toList(),
      };

  /// Rebatit la saisie ; les references sont reprises dans les listes chargees,
  /// pour que les listes deroulantes les reconnaissent.
  static Realestate versBien(
    BrouillonBien b, {
    List<Category>? categories,
    List<Etat>? etats,
    List<TypeTransaction>? types,
    List<Region>? regions,
    List<Owner>? owners,
    List<Secteur>? secteurs,
    List<Dossier>? dossiers,
    List<Feature>? features,
  }) {
    final j = b.bien;
    T? parmi<T>(List<T>? liste, bool Function(T) test, T? Function() sinon) {
      for (final e in liste ?? <T>[]) {
        if (test(e)) return e;
      }
      return sinon();
    }

    final category = _objet(j['category']);
    final etat = _objet(j['etat']);
    final type = _objet(j['typeTransaction']);
    final owner = _objet(j['owner']);
    final region = _objet(j['region']);
    final city = _objet(j['city']);
    final secteur = _objet(j['secteur']);
    final dossier = _objet(j['dossier']);
    final idsFeatures = ((j['features'] as List?) ?? const []).map(_entier).whereType<int>().toSet();
    final lat = j['latitude'] as num?;
    final lng = j['longitude'] as num?;

    final regionChoisie = region == null
        ? null
        : parmi<Region>(regions, (r) => r.id == _entier(region['id']),
            () => Region(id: _entier(region['id']), name: _texte(region['name'])));

    return Realestate(
      title: _texte(j['title']),
      description: _texte(j['description']),
      price: j['price'] as num?,
      surface: j['surface'] as num?,
      tour360Url: _texte(j['tour360Url']),
      dateConstruction: DateTime.tryParse('${j['dateConstruction'] ?? ''}'),
      nbEtages: _entier(j['nbEtages']),
      nbRooms: _entier(j['nbRooms']),
      etage: _entier(j['etage']),
      nbBathroom: _entier(j['nbBathroom']),
      category: category == null
          ? null
          : parmi<Category>(categories, (c) => c.value == category['value'], () => Category.fromJson(category)),
      etat: etat == null ? null : parmi<Etat>(etats, (e) => e.code == etat['code'], () => Etat.fromJson(etat)),
      typeTransaction: type == null
          ? null
          : parmi<TypeTransaction>(types, (t) => t.value == type['value'], () => TypeTransaction.fromJson(type)),
      owner: owner == null
          ? null
          : parmi<Owner>(owners, (o) => o.id == _entier(owner['id']),
              () => Owner(id: _entier(owner['id']), name: _texte(owner['name']), tel: _texte(owner['tel']))),
      address: Address(
        address: _texte(j['address']),
        region: regionChoisie,
        city: city == null ? null : City(id: _entier(city['id']), name: _texte(city['name'])),
      ),
      location: lat == null || lng == null ? null : Location(latitude: lat, longitude: lng),
      secteur: secteur == null
          ? null
          : parmi<Secteur>(secteurs, (s) => s.id == _entier(secteur['id']), () => Secteur.fromJson(secteur)),
      dossier: dossier == null
          ? null
          : parmi<Dossier>(dossiers, (d) => d.id == _entier(dossier['id']),
              () => Dossier(id: _entier(dossier['id']), nom: _texte(dossier['nom']))),
      features: (features ?? const <Feature>[]).where((f) => idsFeatures.contains(f.id)).toList(),
      files: b.fichiers,
    );
  }
}
