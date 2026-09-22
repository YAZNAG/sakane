class TypeTransaction {
  String? name;
  String? value;

  TypeTransaction({this.name, this.value});

  factory TypeTransaction.fromJson(Map<String, dynamic> json) {
    return TypeTransaction(name: json['name'], value: json['value']);
  }

  Map<String, dynamic> toJson() => {'name': name, 'value': value};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TypeTransaction &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;
}
