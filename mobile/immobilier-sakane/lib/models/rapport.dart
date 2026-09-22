import 'dart:io';

import 'package:dio/dio.dart';
import 'package:immobilier/core/extensions/extension_on_date.dart';
import 'package:immobilier/models/media.dart';

class Rapport {
  int? id;
  String? name;
  String? description;
  DateTime? date;
  List<Media>? images;
  List<File>? files;
  int? realestate;

  Rapport({
    this.id,
    this.name,
    this.description,
    this.date,
    this.images,
    this.realestate,
    this.files
  });

  factory Rapport.fromJson(Map<String, dynamic> json) {
    return Rapport(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      date: DateTime.parse(json['date']),
      images: (json['images'] as List<dynamic>)
          .map((img) => Media.fromJson(img))
          .toList(),
    );
  }

  Future<Map<String, dynamic>> toJson() async{
    List<MultipartFile> mfs=await convertFiles();
    return {
      "name": name,
      "description": description,
      "date": date?.formattedDateEn,
      "images[]": mfs,
      "realestate":realestate
    };
  }


  Future<List<MultipartFile>> convertFiles()async{
    List<MultipartFile> mfls= [];
    for(File f in files??[]){
      MultipartFile mf=await MultipartFile.fromFile(f.path,filename: f.path.split("/").last);
      mfls.add(mf);
    }
    return mfls;
  }

  Rapport copyWith({
    int? id,
    String? name,
    String? description,
    DateTime? date,
    List<Media>? images,
    List<File>? files,
    int? realestate,

  }) {
    return Rapport(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      date: date ?? this.date,
      images: images ?? this.images,
      realestate: realestate ?? this.realestate,
      files: files ?? this.files
    );
  }

}

