import 'dart:io';

import 'package:dio/dio.dart';
import 'package:immobilier/core/extensions/extension_on_date.dart';
import 'package:immobilier/models/media.dart';

import 'owner.dart';
import 'client.dart';
import 'realestate.dart';

class Contract {
  int? id;
  DateTime? signedDate;
  DateTime? expirationDate;
  String? note;
  Owner? owner;
  Client? client;
  Realestate? realestate;
  List<Media>? documents;
  List<File>? files;

  Contract({
    this.id,
    this.signedDate,
    this.expirationDate,
    this.note,
    this.owner,
    this.client,
    this.realestate,
    this.documents,
    this.files
  });

  factory Contract.fromJson(Map<String, dynamic> json) {
    return Contract(
      id: json['id'],
      signedDate: json['signed_date'] != null
          ? DateTime.tryParse(json['signed_date'])
          : null,
      expirationDate: json['expiration_date'] != null
          ? DateTime.tryParse(json['expiration_date'])
          : null,
      note: json['note'],
      owner: json['owner'] != null ? Owner.fromJson(json['owner']) : null,
      client: json['client'] != null ? Client.fromJson(json['client']) : null,
      realestate: json['realestate'] != null
          ? Realestate.fromJson(json['realestate'])
          : null,
      documents: json['documents'] != null
          ? (json['documents'] as List)
                .map((d) => Media.fromJson(d))
                .toList()
          : null,
    );
  }

  Future<Map<String,dynamic>> toJson()async{
    List<MultipartFile> mfs=[];
    for(File f in files??[]){
      final mf=await convertFile(f);
      mfs.add(mf);
    }
    return {
      "note":note,
      "owner":owner?.id,
      "client":client?.id,
      "signed":signedDate?.formattedDateEn,
      "expiration":expirationDate?.formattedDateEn,
      "realestate":realestate?.id,
      "documents[]":mfs
    };
  }

  Future<MultipartFile> convertFile(File file)async{
    final mf=await MultipartFile.fromFile(file.path,filename: file.path.split("/").last);
    return mf;
  }

  Contract copyWith({
    int? id,
    DateTime? signedDate,
    DateTime? expirationDate,
    String? note,
    Owner? owner,
    Client? client,
    Realestate? realestate,
    List<Media>? documents,
    List<File>? files,
  }) {
    return Contract(
      id: id ?? this.id,
      signedDate: signedDate ?? this.signedDate,
      expirationDate: expirationDate ?? this.expirationDate,
      note: note ?? this.note,
      owner: owner ?? this.owner,
      client: client ?? this.client,
      realestate: realestate ?? this.realestate,
      documents: documents ?? this.documents,
      files: files ?? this.files,
    );
  }

}
