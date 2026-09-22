class CLientReview {
  final int? id;
  final double? rate;
  final String? comment;
  final int? cleanliness;
  final int? accuracy;
  final int? location;
  final int? communication;

  CLientReview({
    this.id,
    this.rate,
    this.comment,
    this.cleanliness,
    this.accuracy,
    this.location,
    this.communication,
  });

  factory CLientReview.fromJson(Map<String, dynamic> json) {
    return CLientReview(
      id: json['id'],
      rate: (json['rate'] as num?)?.toDouble(),
      comment: json['comment'],
      cleanliness: json['cleanliness'],
      accuracy: json['accuracy'],
      location: json['location'],
      communication: json['communication'],
    );
  }
}
