import 'dart:io';

import 'package:dio/dio.dart';
import 'package:immobilier/core/extensions/extension_on_date.dart';
import 'package:immobilier/models/booking.dart';
import 'package:immobilier/models/reserved_date.dart';
import 'package:immobilier/models/status.dart';
import 'package:immobilier/models/statut_jour.dart';

import 'address.dart';
import 'location.dart';
import 'category.dart';
import 'type_transaction.dart';
import 'etat.dart';
import 'feature.dart';
import 'owner.dart';
import 'media.dart';
import 'package:immobilier/models/secteur.dart';
import 'package:immobilier/models/dossier.dart';

class Realestate {
  int? id;
  String? title;
  String? description;
  num? surface;
  num? price;
  DateTime? dateConstruction;
  int? nbEtages;
  int? nbRooms;
  int? etage;
  int? nbBathroom;
  num? rate;
  num? rateCount;
  String? tour360Url;
  Address? address;
  Secteur? secteur;
  Dossier? dossier;
  Location? location;
  Category? category;
  TypeTransaction? typeTransaction;
  Etat? etat;
  List<Feature>? features;
  Owner? owner;
  List<Media>? media;
  List<int>? trashImages;
  List<File>? files;
  Status? status;
  List<ReservedDate>? reservedDates;
  bool? hasTodayBooking;
  Booking? booking;
  DateTime? nextCheckin;

  Realestate({
    this.id,
    this.title,
    this.description,
    this.surface,
    this.price,
    this.dateConstruction,
    this.nbEtages,
    this.nbRooms,
    this.etage,
    this.nbBathroom,
    this.rate,
    this.rateCount,
    this.tour360Url,
    this.address,
    this.secteur,
    this.dossier,
    this.location,
    this.category,
    this.typeTransaction,
    this.etat,
    this.features,
    this.owner,
    this.media,
    this.trashImages,
    this.files,
    this.status,
    this.reservedDates,
    this.hasTodayBooking,
    this.booking,
    this.nextCheckin
  });

  @override
  String toString() {
    return 'Realestate{category: $category, typeTransaction: $typeTransaction, etat: $etat, owner: $owner}';
  }

  // ---- Suivi du nettoyage ----
  String? cleaningStatus;
  DateTime? cleaningStartedAt;
  DateTime? cleaningFinishedAt;
  int? cleaningMinutes;
  String? cleanedByName;

  DateTime? checkoutAt;

  /// Date de desactivation du bien (null quand le bien est actif).
  DateTime? desactiveLe;

  /// « AG-0001 » : la reference lisible du bien, ecrite par le serveur.
  /// Absente des anciennes reponses : la fiche se replie alors sur l'id.
  String? reference;

  /// Vrai quand le bien est relie a une annonce Airbnb.
  bool airbnbRelie = false;

  bool get estDesactive => desactiveLe != null;

  /// Statut du jour calcule par le serveur (disponible, occupe…).
  /// Rien a voir avec [etat] (« Bon état »…).
  StatutJour? statutJour;

  /// « AG-0001 », ou le numero du bien quand la reference manque.
  String get referenceLisible {
    final ref = reference?.trim() ?? '';
    if (ref.isNotEmpty) return ref;
    return id == null ? '' : '$id';
  }

  /// Le menage n'a pas encore commence : l'appartement attend.
  bool get aNettoyer => cleaningStatus == 'to_clean';

  /// Le menage est en cours.
  bool get enNettoyage => cleaningStatus == 'cleaning';

  /// Temps ecoule depuis le depart du client, tant que le menage n'a pas commence.
  String? get attenteDepuisDepart {
    if (!aNettoyer || checkoutAt == null) return null;
    return _formaterMinutes(DateTime.now().difference(checkoutAt!).inMinutes);
  }

  /// Duree du dernier nettoyage termine : "45 min" ou "1 h 20".
  String? get dureeNettoyage => _formaterMinutes(cleaningMinutes);

  /// Duree ecoulee depuis le debut du nettoyage en cours.
  String? get dureeEnCours {
    if (!enNettoyage || cleaningStartedAt == null) return null;
    return _formaterMinutes(DateTime.now().difference(cleaningStartedAt!).inMinutes);
  }

  String? _formaterMinutes(int? m) {
    if (m == null || m <= 0) return null;
    if (m < 60) return '$m min';
    final h = m ~/ 60;
    final r = m % 60;
    return r == 0 ? '$h h' : '$h h $r';
  }

  factory Realestate.fromJson(Map<String, dynamic> json) {
    return Realestate(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      surface: json['surface'],
      price: json['price'],
      dateConstruction: json['dateConstruction']!=null?DateTime.parse(json['dateConstruction']):null,
      nbEtages: json['nbEtages'],
      nbRooms: json['nbRooms'],
      etage: json['etage'],
      nbBathroom: json['nbBathroom'],
      rate: json['rate'],
      rateCount: json['rateCount'],
      tour360Url: json['tour360Url'],
      hasTodayBooking: json["hasTodayBookings"],
      booking: json["booking"]!=null?Booking.fromJson(json["booking"]):null,
      address: json['address'] != null
          ? Address.fromJson(json['address'])
          : null,
      secteur: json['secteur'] != null
          ? Secteur.fromJson(json['secteur'])
          : null,
      dossier: json['dossier'] != null
          ? Dossier.fromJson(json['dossier'])
          : null,
      location: json['location'] != null
          ? Location.fromJson(json['location'])
          : null,
      category: json['category'] != null
          ? Category.fromJson(json['category'])
          : null,
      typeTransaction: json['typeTransaction'] != null
          ? TypeTransaction.fromJson(json['typeTransaction'])
          : null,
      etat: json['etat'] != null ? Etat.fromJson(json['etat']) : null,
      features: json['features'] != null
          ? (json['features'] as List).map((e) => Feature.fromJson(e)).toList()
          : null,
      owner: json['owner'] != null ? Owner.fromJson(json['owner']) : null,
      media: json['media'] != null
          ? (json['media'] as List).map((e) => Media.fromJson(e)).toList()
          : null,
      status: json['status']!=null?Status.fromJson(json["status"]):null,
        reservedDates: json["reservedDates"]!=null
            ?(json["reservedDates"] as List).map((e)=>ReservedDate.fromJson(e)).toList()
            :null,
      nextCheckin: json["nextCheckin"]!=null? DateTime.parse(json["nextCheckin"]):null
    )
      ..desactiveLe = json['desactiveLe'] is String
          ? DateTime.tryParse(json['desactiveLe'])
          : null
      ..statutJour = StatutJour.depuis(json['statutJour'])
      ..reference = json['reference'] is String &&
              (json['reference'] as String).trim().isNotEmpty
          ? (json['reference'] as String).trim()
          : null
      // Le serveur peut l'ecrire a plat ou dans le bloc « airbnb ».
      ..airbnbRelie = json['airbnbRelie'] == true ||
          (json['airbnb'] is Map && (json['airbnb'] as Map)['relie'] == true)
      ..cleaningStatus = json['cleaningStatus']
      ..checkoutAt = json['checkoutAt'] != null
          ? DateTime.tryParse(json['checkoutAt'])
          : null
      ..cleaningStartedAt = json['cleaningStartedAt'] != null
          ? DateTime.tryParse(json['cleaningStartedAt'])
          : null
      ..cleaningFinishedAt = json['cleaningFinishedAt'] != null
          ? DateTime.tryParse(json['cleaningFinishedAt'])
          : null
      ..cleaningMinutes = json['cleaningMinutes']
      ..cleanedByName = json['cleanedBy'] != null
          ? json['cleanedBy']['name']
          : null;
  }

  Future<List<MultipartFile>> convertFiles()async{
    List<MultipartFile> mpfs=[];
    for(File f in files??[]){
      final m=await MultipartFile.fromFile(f.path,filename:f.path.split("/").last);
      mpfs.add(m);
    }
    return mpfs;
  }

  Future<Map<String, dynamic>> toJson()async{
    List<MultipartFile> mpfls=await convertFiles();
    return {
      'id': id,
      'title': title,
      'description': description,
      'surface': surface,
      'price': price,
      'dateConstruction': dateConstruction?.formattedDateEn,
      'nbEtages': nbEtages,
      'nbRooms': nbRooms,
      'etage': etage,
      "tour360Url":tour360Url,
      'nbBathrooms': nbBathroom,
      'city': address?.city?.id,
      'address': address?.address,
      'secteur': secteur?.id,
      'dossier': dossier?.id,
      'latitude': location?.latitude,
      'longitude': location?.longitude,
      'category': category?.value,
      'typeTransaction': typeTransaction?.value,
      'etat': etat?.code,
      'features[]': (features??[]).map((e) => e.id).toList(),
      'owner': owner?.id,
      'images[]':mpfls,
      'trashImages[]':trashImages??[]
    };
  }

  Realestate copyWith({
    int? id,
    String? title,
    String? description,
    num? surface,
    num? price,
    DateTime? dateConstruction,
    int? nbEtages,
    int? nbRooms,
    int? etage,
    int? nbBathroom,
    num? rate,
    num? rateCount,
    String? tour360Url,
    Address? address,
    Secteur? secteur,
    Dossier? dossier,
    Location? location,
    Category? category,
    TypeTransaction? typeTransaction,
    Etat? etat,
    List<Feature>? features,
    Owner? owner,
    List<Media>? media,
    List<int>? trashImages,
    List<File>? files,
    List<ReservedDate>? reservedDates,
    Status? status
  }) {
    return Realestate(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      surface: surface ?? this.surface,
      price: price ?? this.price,
      dateConstruction: dateConstruction ?? this.dateConstruction,
      nbEtages: nbEtages ?? this.nbEtages,
      nbRooms: nbRooms ?? this.nbRooms,
      etage: etage ?? this.etage,
      nbBathroom: nbBathroom ?? this.nbBathroom,
      rate: rate ?? this.rate,
      rateCount: rateCount ?? this.rateCount,
      tour360Url: tour360Url ?? this.tour360Url,
      address: address ?? this.address,
      secteur: secteur ?? this.secteur,
      dossier: dossier ?? this.dossier,
      location: location ?? this.location,
      category: category ?? this.category,
      typeTransaction: typeTransaction ?? this.typeTransaction,
      etat: etat ?? this.etat,
      features: features ?? this.features,
      owner: owner ?? this.owner,
      media: media ?? this.media,
      trashImages: trashImages??this.trashImages,
      files: files??this.files,
      reservedDates: reservedDates ?? this.reservedDates,
      status: status ?? this.status
    )
      ..statutJour = statutJour
      ..reference = reference
      ..airbnbRelie = airbnbRelie
      ..desactiveLe = desactiveLe;
  }
}
