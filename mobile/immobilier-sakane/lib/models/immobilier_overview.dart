

import 'package:immobilier/models/realestate.dart';

class ImmobilierOverview{
  int? reserved;
  int? available;
  int? cleaning;
  int? allImmobilier;
  List<Realestate>? realestates;

  ImmobilierOverview({
    this.reserved,
    this.available,
    this.cleaning,
    this.realestates,
    this.allImmobilier
  });



  factory ImmobilierOverview.fromMap(Map<String, dynamic> map) {
    return ImmobilierOverview(
      reserved: (map['reserved'] as num).toInt(),
      available: (map['available'] as num).toInt(),
      cleaning: (map['cleaning'] as num).toInt(),
      allImmobilier: (map['all'] as num).toInt(),
      realestates: (map['todayCheckout'] as List?)?.map((e)=>Realestate.fromJson(e)).toList(),
    );
  }
}