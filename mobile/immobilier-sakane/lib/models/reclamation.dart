import 'dart:io';

import 'package:dio/dio.dart';
import 'package:immobilier/models/media.dart';

class Reclamation {
  int? id;
  String? note;
  String? status; // "pending" | "resolved"
  int? realestateId;
  String? realestateName;
  List<Media>? images;
  List<File>? files;
  String? createdAt;

  /// Nom du gestionnaire ayant signale la reclamation
  String? signaledBy;

  Reclamation({
    this.id,
    this.note,
    this.status,
    this.realestateId,
    this.realestateName,
    this.images,
    this.files,
    this.createdAt,
    this.signaledBy,
  });

  factory Reclamation.fromJson(Map<String, dynamic> json) {
    return Reclamation(
      id: json['id'],
      note: json['note'],
      status: json['status'],
      realestateId: json['realestateId'],
      realestateName: json['realestate']?['title'],
      images: (json['images'] as List<dynamic>?)
          ?.map((img) => Media.fromJson(img))
          .toList(),
      createdAt: json['createdAt'],
      signaledBy: json['signaledBy']?['name'],
    );
  }

  Future<Map<String, dynamic>> toJson() async {
    List<MultipartFile> mfs = await _convertFiles();
    return {
      'note': note,
      'realestate': realestateId,
      'images[]': mfs,
    };
  }

  Future<List<MultipartFile>> _convertFiles() async {
    List<MultipartFile> result = [];
    for (File f in files ?? []) {
      result.add(await MultipartFile.fromFile(f.path, filename: f.path.split('/').last));
    }
    return result;
  }

  bool get isPending => status == 'pending';
  bool get isResolved => status == 'resolved';

  Reclamation copyWith({
    int? id,
    String? note,
    String? status,
    int? realestateId,
    String? realestateName,
    List<Media>? images,
    List<File>? files,
    String? createdAt,
  }) {
    return Reclamation(
      id: id ?? this.id,
      note: note ?? this.note,
      status: status ?? this.status,
      realestateId: realestateId ?? this.realestateId,
      realestateName: realestateName ?? this.realestateName,
      images: images ?? this.images,
      files: files ?? this.files,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
