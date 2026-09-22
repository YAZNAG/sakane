/// Piece jointe d'une charge : recu, facture ou photo du justificatif.
class ChargeDocument {
  final int? id;
  final String? url;
  final String? name;
  final String? mimeType;
  final int? size;
  final bool isImage;
  final bool isPdf;

  const ChargeDocument({
    this.id,
    this.url,
    this.name,
    this.mimeType,
    this.size,
    this.isImage = false,
    this.isPdf = false,
  });

  factory ChargeDocument.fromJson(Map<String, dynamic> json) {
    return ChargeDocument(
      id: json['id'],
      url: json['url'],
      name: json['name'],
      mimeType: json['mimeType'],
      size: json['size'],
      isImage: json['isImage'] == true,
      isPdf: json['isPdf'] == true,
    );
  }

  /// Taille lisible : "245 Ko", "1,2 Mo"
  String get tailleLisible {
    final o = size ?? 0;
    if (o <= 0) return '';
    if (o < 1024) return '$o o';
    if (o < 1024 * 1024) return '${(o / 1024).round()} Ko';
    return '${(o / 1024 / 1024).toStringAsFixed(1).replaceAll('.', ',')} Mo';
  }
}
