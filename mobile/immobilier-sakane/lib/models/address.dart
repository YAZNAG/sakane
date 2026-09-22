import 'package:immobilier/models/city.dart';
import 'package:immobilier/models/region.dart';

class Address {
  String? address;
  City? city;
  Region? region;

  Address({this.address, this.city,this.region});

  factory Address.fromJson(Map<String, dynamic> json) {
    return Address(
      address: json['address'],
      city: json['city'] != null ? City.fromJson(json['city']) : null,
      region: json['city']["region"] != null ? Region.fromJson(json['city']["region"]) : null,
    );
  }


  Map<String, dynamic> toJson() => {'address': address, 'city': city?.toJson()};

  Address copyWithNullCity(){
    return  Address(
      address:  address,
      city: null,
      region:  region,
    );
  }

  Address copyWith({
    String? address,
    City? city,
    Region? region,
  }) {
    return Address(
      address: address ?? this.address,
      city: city ?? this.city,
      region: region ?? this.region,
    );
  }
}
