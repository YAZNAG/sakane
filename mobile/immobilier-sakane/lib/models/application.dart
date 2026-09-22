class AppVersion {
  int? id;
  String? version;
  String? packageName;
  String? apkUrl;
  String? description;
  bool? isActive;
  DateTime? createdAt;
  DateTime? updatedAt;

  AppVersion({
    this.id,
    this.version,
    this.packageName,
    this.apkUrl,
    this.description,
    this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  factory AppVersion.fromJson(Map<String, dynamic> json) {
    return AppVersion(
      id: int.parse(json['id'].toString()),
      version: json['version'] ?? '',
      packageName: json['package_name'] ?? '',
      apkUrl: json['apk_url'] ?? '',
      description: json['description'] ?? '',
      isActive: json['is_active'].toString() == '1',
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }


}
