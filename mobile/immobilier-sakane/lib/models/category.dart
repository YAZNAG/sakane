class Category {
  String? name;
  String? value;

  Category({this.name, this.value});

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(name: json['name'], value: json['value']);
  }

  Map<String, dynamic> toJson() => {'name': name, 'value': value};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Category &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;
}
