class Feature {
  int? id;
  String? name;
  String? description;
  String? icon;
  bool? isSelected;

  /// La famille de l'équipement : « interieur », « exterieur »,
  /// « confort », « equipements », « securite », « services ».
  String? groupe;

  /// Son rang dans sa famille, pour un ordre stable d'un écran à l'autre.
  int? ordre;

  /// Les types de biens auxquels il s'applique. Vide : tous.
  List<String> categories;

  Feature({
    this.id,
    this.name,
    this.description,
    this.icon,
    this.groupe,
    this.ordre,
    this.categories = const [],
  });

  factory Feature.fromJson(Map<String, dynamic> json) {
    return Feature(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      icon: json['icon'],
      groupe: json['groupe'],
      ordre: (json['ordre'] as num?)?.toInt(),
      categories: ((json['categories'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
    );
  }

  /// Un équipement sans type s'applique partout ; sans type demandé non plus.
  bool concerne(String? categorie) =>
      categories.isEmpty || categorie == null || categories.contains(categorie);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'icon': icon,
        'groupe': groupe,
        'ordre': ordre,
        'categories': categories,
      };
}
