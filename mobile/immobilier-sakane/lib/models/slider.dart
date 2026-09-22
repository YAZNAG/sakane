
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:immobilier/models/media.dart';

class SliderModel {
  int? id;
  String? name;
  String? description;
  bool? isActive;
  List<Media>? images;
  List<File>? files;

  SliderModel({
    this.id,
    this.name,
    this.description,
    this.isActive,
    this.images,
    this.files
  });

  factory SliderModel.fromJson(Map<String, dynamic> json) {
    return SliderModel(
      id: json['id'] as int?,
      name: json['name'] as String?,
      description: json['description'] as String?,
      isActive: json['isActive'] as bool?,
      images: (json['images'] as List?)
          ?.map((e) => Media.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<Map<String, dynamic>> toJson() async{
    List<MultipartFile> mfs=[];
    for(File f in files??[]){
      final mf=await convertFile(f);
      mfs.add(mf);
    }
    return {
      'id': id,
      'name': name,
      'description': description,
      'isActive': isActive,
      'images[]':mfs,
    };
  }
  Future<MultipartFile> convertFile(File file)async{
    final mf=await MultipartFile.fromFile(file.path,filename: file.path.split("/").last);
    return mf;
  }

  SliderModel copyWith({
    int? id,
    String? name,
    String? description,
    bool? isActive,
    List<Media>? images,
    List<File>? files,
  }) {
    return SliderModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      images: images ?? this.images,
      files: files ?? this.files,
    );
  }

}

