class Feature {
  int? id;
  String? name;
  String? description;
  String? icon;
  bool? isSelected;

  Feature({this.id, this.name, this.description, this.icon});

  factory Feature.fromJson(Map<String, dynamic> json) {
    return Feature(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      icon: json['icon'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'icon': icon,
  };
}
