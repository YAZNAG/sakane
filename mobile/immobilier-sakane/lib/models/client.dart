import 'dart:io';

import 'package:dio/dio.dart';
import 'package:immobilier/models/booking.dart';
import 'package:immobilier/models/media.dart';

class Client {
  int? id;
  String? firstName;
  String? lastName;

  /// Nom et prenom en arabe, tels qu'ils figurent sur la CIN.
  /// Facultatifs : la lecture arabe n'aboutit pas toujours.
  String? firstNameAr;
  String? lastNameAr;
  String? email;
  String? identityNumber;

  /// Nationalité saisie librement (ex. Marocain, Français).
  String? nationalite;
  double? rate;
  int? nbRates;
  String? type;
  bool? isEmailVerified;
  String? profile;
  List<File>? documents;
  String? countryCode;
  String? tel;
  bool acceptePromotions;
  List<Media>? docs;
  List<Booking>? bookings;
  List<String>? documentsProvided;

  /// Liste noire : le client ne peut plus réserver.
  ListeNoire? listeNoire;

  Client({
    this.id,
    this.firstName,
    this.lastName,
    this.firstNameAr,
    this.lastNameAr,
    this.identityNumber,
    this.nationalite,
    this.rate,
    this.nbRates,
    this.type,
    this.isEmailVerified,
    this.profile,
    this.documents,
    this.email,
    this.tel,
    this.acceptePromotions = true,
    this.docs,
    this.bookings,
    this.documentsProvided,
    this.countryCode,
    this.listeNoire,
  });

  factory Client.fromJson(Map<String, dynamic> json) {
    return Client(
      id: json['id'],
      firstName: json['firstName'],
      lastName: json['lastName'],
      firstNameAr: json['firstNameAr'],
      lastNameAr: json['lastNameAr'],
      identityNumber: json['identityNumber'],
      nationalite: json['nationalite']?.toString(),
      rate: (json['rate'] as num?)?.toDouble(),
      nbRates: json['nbRates'],
      type: json['type'],
      isEmailVerified: json['isEmailVerified'],
      profile: json['profile'],
      email: json['email'],
      tel: json["tel"],
      acceptePromotions: json['acceptePromotions'] ?? true,
      documentsProvided: (json["documentsProvided"] as List?)?.map((e)=>e.toString()).toList() ,
      docs: (json["documents"] as List?)?.map((e)=>Media.fromJson(e)).toList(),
      bookings: (json["bookings"] as List?)?.map((e)=>Booking.fromJson(e)).toList(),
      countryCode: json["countryCode"],
      listeNoire: json["listeNoire"] is Map
          ? ListeNoire.fromJson(Map<String, dynamic>.from(json["listeNoire"] as Map))
          : null,
    );
  }

  /// Copie du client ; [effacerListeNoire] retire la liste noire.
  Client copyWith({ListeNoire? listeNoire, bool effacerListeNoire = false}) {
    return Client(
      id: id,
      firstName: firstName,
      lastName: lastName,
      firstNameAr: firstNameAr,
      lastNameAr: lastNameAr,
      identityNumber: identityNumber,
      nationalite: nationalite,
      rate: rate,
      nbRates: nbRates,
      type: type,
      isEmailVerified: isEmailVerified,
      profile: profile,
      documents: documents,
      email: email,
      tel: tel,
      acceptePromotions: acceptePromotions,
      docs: docs,
      bookings: bookings,
      documentsProvided: documentsProvided,
      countryCode: countryCode,
      listeNoire: effacerListeNoire ? null : (listeNoire ?? this.listeNoire),
    );
  }

  String get fullName {
    return "$firstName-$lastName";
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Client && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  Future<Map<String, dynamic>> toJson() async {
    List<MultipartFile> files = await convertFiles();
    return {
      "email": email,
      "firstName": firstName,
      "lastName": lastName,
      if (firstNameAr != null) "firstNameAr": firstNameAr,
      if (lastNameAr != null) "lastNameAr": lastNameAr,
      "identityNumber": identityNumber,
      "nationalite": nationalite,
      "tel":tel,
      "countryCode":countryCode,
      "documentsProvided[]":documentsProvided,
      "documents[]": files,
    };
  }

  Future<List<MultipartFile>> convertFiles() async {
    List<MultipartFile> mfs = [];
    for (File f in documents ?? []) {
      MultipartFile mf = await MultipartFile.fromFile(
        f.path,
        filename: f.path.split("/").last,
      );
      mfs.add(mf);
    }
    return mfs;
  }
}

/// Pourquoi et depuis quand un client est sur liste noire.
class ListeNoire {
  final DateTime? le;
  final String? motif;
  final String? par;

  const ListeNoire({this.le, this.motif, this.par});

  factory ListeNoire.fromJson(Map<String, dynamic> json) {
    return ListeNoire(
      le: DateTime.tryParse((json["le"] ?? "").toString())?.toLocal(),
      motif: json["motif"]?.toString(),
      par: json["par"]?.toString(),
    );
  }
}
