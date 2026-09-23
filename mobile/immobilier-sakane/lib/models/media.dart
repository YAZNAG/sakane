class Media {
  int? id;
  String? url;

  /// Vignette, quand le serveur la fabrique : une grille de photos ne
  /// telecharge pas huit images pleine taille.
  String? thumbUrl;

  /// Photo d'origine, non redimensionnee : la galerie plein ecran et le
  /// partage s'en servent.
  String? urlOriginal;

  Media({this.id, this.url, this.thumbUrl, this.urlOriginal});

  /// L'adresse a afficher : la vignette si elle existe, sinon la photo.
  String? get vignette => _premiere([thumbUrl, url, urlOriginal]);

  /// L'adresse a montrer en grand ou a partager.
  String? get pleineTaille => _premiere([url, urlOriginal, thumbUrl]);

  static String? _premiere(List<String?> adresses) {
    for (final a in adresses) {
      if ((a ?? '').trim().isNotEmpty) return a!.trim();
    }
    return null;
  }

  factory Media.fromJson(Map<String, dynamic> json) {
    return Media(
      id: json['id'],
      url: json['url'],
      thumbUrl: _texte(json['thumbUrl'] ?? json['thumb_url']),
      urlOriginal: _texte(json['urlOriginal'] ?? json['url_original']),
    );
  }

  static String? _texte(dynamic valeur) {
    if (valeur is! String) return null;
    final texte = valeur.trim();
    return texte.isEmpty ? null : texte;
  }

  Map<String, dynamic> toJson() => {'id': id, 'url': url};
}
