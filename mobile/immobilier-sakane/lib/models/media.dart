class Media {
  int? id;
  String? url;

  Media({this.id, this.url});

  factory Media.fromJson(Map<String, dynamic> json) {
    return Media(id: json['id'], url: json['url']);
  }

  Map<String, dynamic> toJson() => {'id': id, 'url': url};
}
