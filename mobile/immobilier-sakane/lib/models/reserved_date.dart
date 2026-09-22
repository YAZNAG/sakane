

class ReservedDate{
  DateTime? checkin;
  DateTime? checkout;

  /// Réservation faite sur Airbnb (et non un simple blocage).
  bool airbnb;

  /// Séjour Airbnb à l'origine de cette plage, s'il y en a un.
  int? airbnbSejour;

  ReservedDate({
    this.checkin,
    this.checkout,
    this.airbnb = false,
    this.airbnbSejour,
  });



  factory ReservedDate.fromJson(Map<String, dynamic> json) {
    return ReservedDate(
      checkin: json['checkin']!=null?DateTime.tryParse(json["checkin"].toString()):null,
      checkout: json['checkout'] !=null? DateTime.tryParse(json["checkout"].toString()):null,
      airbnb: _lireBool(json['airbnb']),
      airbnbSejour: _lireInt(json['airbnbSejour']),
    );
  }

  static bool _lireBool(dynamic v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) return v == '1' || v.toLowerCase() == 'true';
    return false;
  }

  static int? _lireInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

}
