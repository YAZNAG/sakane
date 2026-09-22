
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:immobilier/core/extensions/extension_on_date.dart';
import 'package:immobilier/models/client_review.dart';
import 'package:immobilier/models/host_review.dart';
import 'package:immobilier/models/status.dart';

import 'realestate.dart';
import 'client.dart';



class Booking {
  final int? id;
  final double? amount;
  final DateTime? checkin;
  final DateTime? checkout;
  final int? nbGuest;
  final bool? isRatable;
  final double? nightPrice;
  final Client? client;
  final Realestate? realestate;
  final Status? status;
  final CLientReview? clientReview;
  final HostReview? myReview;
  final Uint8List? signature;
  String? privateContract;
  String? publicContract;
  String? typeGuest;

  /// Heures convenues, au format « HH:mm ». Nulles lorsque ce sont les
  /// heures d'usage de l'agence qui s'appliquent.
  final String? heureArrivee;
  final String? heureDepart;

  /// Somme deja versee par le client a la reservation.
  final double? avance;

  /// Depot de garantie, restitue au depart.
  final double? caution;

  /// Precisions utiles a l'agent : arrivee tardive, demande
  /// particuliere...
  final String? remarques;

  /// L'agent qui a enregistre la reservation.
  final String? creePar;

  /// A la creation : appliquer la facture d'office. Le total de la
  /// reservation est alors T.T.C, la TVA y est comprise.
  final bool? appliquerFacture;

  /// Taux de TVA (%) de la facture appliquee a la creation.
  final double? tvaFacture;

  /// La facture de cette reservation est deja appliquee.
  final bool factureAppliquee;

  Booking({
    this.id,
    this.amount,
    this.checkin,
    this.checkout,
    this.nbGuest,
    this.isRatable,
    this.nightPrice,
    this.client,
    this.realestate,
    this.status,
    this.clientReview,
    this.myReview,
    this.signature,
    this.privateContract,
    this.publicContract,
    this.typeGuest,
    this.heureArrivee,
    this.heureDepart,
    this.avance,
    this.caution,
    this.remarques,
    this.creePar,
    this.appliquerFacture,
    this.tvaFacture,
    this.factureAppliquee = false,
  });

  static bool _lireBooleen(dynamic v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    final t = v?.toString().toLowerCase().trim();
    return t == 'true' || t == '1' || t == 'oui';
  }

  factory Booking.fromJson(Map<String, dynamic> json) {
    return Booking(
      id: json['id'],
      amount: (json['amount'] as num?)?.toDouble(),
      checkin: json['checkin'] != null ? DateTime.parse(json['checkin']) : null,
      checkout: json['checkout'] != null ? DateTime.parse(json['checkout']) : null,
      nbGuest: json['nbGuest'],
      isRatable: json['isRatable'],
      nightPrice: (json['nightPrice'] as num?)?.toDouble(),
      client: json['client'] != null ? Client.fromJson(json['client']) : null,
      realestate: json['realestate'] != null ? Realestate.fromJson(json['realestate']) : null,
      status: json['status'] != null ? Status.fromJson(json['status']) : null,
      clientReview: json['clientReview'] != null ? CLientReview.fromJson(json['clientReview']) : null,
      myReview: json['myReview'] != null ? HostReview.fromJson(json['myReview']) : null,
      privateContract: json["privateContract"],
      publicContract: json["publicContract"],
      typeGuest: json["typeGuest"],
      heureArrivee: json["heureArrivee"],
      heureDepart: json["heureDepart"],
      avance: (json["avance"] as num?)?.toDouble(),
      caution: (json["caution"] as num?)?.toDouble(),
      remarques: json["remarques"],
      creePar: json["creePar"],
      factureAppliquee: _lireBooleen(json["factureAppliquee"])
    );
  }


  Future<Map<String,dynamic>> toJson()async{
    // Signature facultative pour un contrat cree depuis Airbnb.
    final mf = signature == null
        ? null
        : MultipartFile.fromBytes(signature!, filename: "signature.png");
    return {
      "checkin":checkin!.formattedDateEn,
      "checkout":checkout!.formattedDateEn,
      "guest":nbGuest,
      "realestate":realestate!.id,
      "client":client!.id,
      if (mf != null) "signature":mf,
      "nightPrice":nightPrice,
      "typeGuest":typeGuest,
      if (heureArrivee != null) "heureArrivee": heureArrivee,
      if (heureDepart != null) "heureDepart": heureDepart,
      if (avance != null) "avance": avance,
      if (caution != null) "caution": caution,
      if (remarques != null && remarques!.isNotEmpty)
        "remarques": remarques,
      if (appliquerFacture == true) ...{
        "appliquerFacture": 1,
        "tvaFacture": tvaFacture ?? 20,
      }
    };
  }

  Booking copyWith({
    int? id,
    double? amount,
    DateTime? checkin,
    DateTime? checkout,
    int? nbGuest,
    bool? isRatable,
    double? nightPrice,
    Client? client,
    Realestate? realestate,
    Status? status,
    CLientReview? clientReview,
    HostReview? myReview,
    Uint8List? signature,
    String? privateContract,
    String? publicContract,
    String? typeGuest,
    String? heureArrivee,
    String? heureDepart,
    double? avance,
    double? caution,
    String? remarques,
    bool? appliquerFacture,
    double? tvaFacture,
    bool? factureAppliquee,
  }) {
    return Booking(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      checkin: checkin ?? this.checkin,
      checkout: checkout ?? this.checkout,
      nbGuest: nbGuest ?? this.nbGuest,
      isRatable: isRatable ?? this.isRatable,
      nightPrice: nightPrice ?? this.nightPrice,
      client: client ?? this.client,
      realestate: realestate ?? this.realestate,
      status: status ?? this.status,
      clientReview: clientReview ?? this.clientReview,
      myReview: myReview ?? this.myReview,
      signature: signature ?? this.signature,
      privateContract: privateContract ?? this.privateContract,
      publicContract: publicContract ?? this.publicContract,
      typeGuest: typeGuest ?? this.typeGuest,
      heureArrivee: heureArrivee ?? this.heureArrivee,
      heureDepart: heureDepart ?? this.heureDepart,
      avance: avance ?? this.avance,
      caution: caution ?? this.caution,
      remarques: remarques ?? this.remarques,
      creePar: this.creePar,
      appliquerFacture: appliquerFacture ?? this.appliquerFacture,
      tvaFacture: tvaFacture ?? this.tvaFacture,
      factureAppliquee: factureAppliquee ?? this.factureAppliquee
    );
  }

}


