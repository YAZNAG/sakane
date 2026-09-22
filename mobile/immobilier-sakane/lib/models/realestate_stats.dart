
class RealestateStats {
  final double platform;
  final double realworld;
  final double charges;
  final List<ValueItem> platformValues;
  final List<ValueItem> realworldValues;

  RealestateStats({
    required this.platform,
    required this.realworld,
    required this.charges,
    required this.platformValues,
    required this.realworldValues,
  });

  factory RealestateStats.fromJson(Map<String, dynamic> json) {
    return RealestateStats(
      platform: (json['platform'] ?? 0).toDouble(),
      realworld: (json['realworld'] ?? 0).toDouble(),
      charges: (json['charges'] ?? 0).toDouble(),
      platformValues: (json['platformValues'] as List<dynamic>?)
          ?.map((e) => ValueItem.fromJson(e))
          .toList() ??
          [],
      realworldValues: (json['realworldValues'] as List<dynamic>?)
          ?.map((e) => ValueItem.fromJson(e))
          .toList() ??
          [],
    );
  }
}

class ValueItem {
  final String period;
  final double amount;

  ValueItem({
    required this.period,
    required this.amount,
  });

  factory ValueItem.fromJson(Map<String, dynamic> json) {
    return ValueItem(
      period: json['period'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
    );
  }
}
