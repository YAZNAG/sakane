/// Quartier d'une ville : HAY SALAM, HAY DAKHLA, HAY FOUNTY...
class Secteur {
  int? id;
  String? name;
  int? cityId;

  Secteur({this.id, this.name, this.cityId});

  factory Secteur.fromJson(Map<String, dynamic> json) {
    return Secteur(
      id: json['id'],
      name: json['name'],
      cityId: json['city'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'city': cityId,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Secteur && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
