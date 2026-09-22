class HostReview {
  final int? id;
  final double? rate;
  final String? comment;
  final int? cleanliness;
  final int? communication;
  final int? observanceHouseRules;

  HostReview({
    this.id,
    this.rate,
    this.comment,
    this.cleanliness,
    this.communication,
    this.observanceHouseRules,
  });

  factory HostReview.fromJson(Map<String, dynamic> json) {
    return HostReview(
      id: json['id'],
      rate: (json['rate'] as num?)?.toDouble(),
      comment: json['comment'],
      cleanliness: json['cleanliness'],
      communication: json['communication'],
      observanceHouseRules: json['observanceHouseRules'],
    );
  }
}
