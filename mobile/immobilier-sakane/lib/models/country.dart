class Country {
  int? id;
  String? name;

  Country({this.id, this.name});

  factory Country.fromJson(Map<String, dynamic> json) {
    return Country(id: json['id'], name: json['name']);
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}
