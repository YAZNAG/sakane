import 'dart:io';

import 'package:dio/dio.dart';
import 'package:immobilier/core/utils/helper_functions.dart';
import 'package:immobilier/models/charge_document.dart';
import 'package:immobilier/models/realestate.dart';

class Charge {
  int? id;
  String? nom;
  String? description;
  String? type;
  String? status;
  double? amount;
  Realestate? realEstate;
  DateTime? createdAt;
  File? document;

  /// Piece jointe deja enregistree cote serveur (recu, facture...)
  ChargeDocument? documentFile;

  /// L'agent qui a saisi la charge. Une depense contestee doit pouvoir
  /// se rapporter a quelqu'un.
  String? creePar;

  /// Renseignes lorsque la charge a ete annulee.
  DateTime? annuleeLe;
  double? rembourse;
  String? motifAnnulation;


  Charge({
    this.id,
    this.nom,
    this.description,
    this.type,
    this.status,
    this.amount,
    this.realEstate,
    this.createdAt,
    this.document,
    this.documentFile,
    this.creePar,
    this.annuleeLe,
    this.rembourse,
    this.motifAnnulation,
  });

  /// Une charge annulee ne se modifie plus : elle n'est la que pour
  /// memoire.
  bool get estAnnulee => status == "cancelled";







  Future<Map<String, dynamic>> toJson()async {
    MultipartFile? multipartFile=await convertFileToMF(document);
    return {
      'nom': this.nom,
      'description': this.description,
      'amount': this.amount,
      'realestate': this.realEstate?.id,
      'document': multipartFile,
      if (this.status != null) 'status': this.status,
    };
  }

  factory Charge.fromJson(Map<String, dynamic> json) {
    return Charge(
      id: json['id']  ,
      nom: json['nom']  ,
      description: json['description']  ,
      type: json['type']  ,
      status: json['status']  ,
      amount: (json['amount'] as num?)?.toDouble(),
      realEstate:json['realestate']!=null?Realestate.fromJson(json['realestate']):null,
      createdAt: json["createdAt"]!=null?DateTime.parse(json["createdAt"]):null,
      documentFile: json['document'] != null
          ? ChargeDocument.fromJson(json['document'])
          : null,
      creePar: json['creePar'],
      annuleeLe: DateTime.tryParse(json['annuleeLe'] ?? '')?.toLocal(),
      rembourse: (json['rembourse'] as num?)?.toDouble(),
      motifAnnulation: json['motifAnnulation'],
    );
  }

  Charge copyWith({
    int? id,
    String? nom,
    String? description,
    String? type,
    String? status,
    double? amount,
    Realestate? realEstate,
    DateTime? createdAt,
    File? document,
    MultipartFile? multipartFile,
  }) {
    return Charge(
      id: id ?? this.id,
      nom: nom ?? this.nom,
      description: description ?? this.description,
      type: type ?? this.type,
      status: status ?? this.status,
      amount: amount ?? this.amount,
      realEstate: realEstate ?? this.realEstate,
      createdAt: createdAt ?? this.createdAt,
      document: document ?? this.document,
      documentFile: this.documentFile,
      creePar: this.creePar,
      annuleeLe: this.annuleeLe,
      rembourse: this.rembourse,
      motifAnnulation: this.motifAnnulation,
    );
  }

}




