import 'package:immobilier/models/region.dart';

class City {
  int? id;
  String? name;
  Region? region;

  City({this.id, this.name, this.region});

  factory City.fromJson(Map<String, dynamic> json) {
    return City(
      id: json['id'],
      name: json['name'],
      //region: json['region'] != null ? Region.fromJson(json['region']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'region': region?.toJson(),
  };


  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is City && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
