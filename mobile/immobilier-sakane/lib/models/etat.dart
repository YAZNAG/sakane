class Etat {
  String? name;
  String? code;

  Etat({this.name, this.code});

  factory Etat.fromJson(Map<String, dynamic> json) {
    return Etat(name: json['name'], code: json['code']??json["value"]);
  }

  Map<String, dynamic> toJson() => {'name': name, 'code': code};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Etat && runtimeType == other.runtimeType && code == other.code;

  @override
  int get hashCode => code.hashCode;
}
