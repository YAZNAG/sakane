import 'package:immobilier/models/country.dart';

class Region {
  int? id;
  String? name;
  Country? country;

  Region({this.id, this.name, this.country});

  factory Region.fromJson(Map<String, dynamic> json) {
    return Region(
      id: json['id'],
      name: json['name'],
      country: json['country'] != null
          ? Country.fromJson(json['country'])
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'country': country?.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Region && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
