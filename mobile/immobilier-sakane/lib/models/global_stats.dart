class GlobalStats {
  num? totalPlatform;
  num? totalRealworld;
  num? totalCharges;
  List<StatItem>? platform;
  List<StatItem>? realworld;
  List<StatItem>? charges;

  GlobalStats({
    this.totalPlatform,
    this.totalRealworld,
    this.totalCharges,
    this.platform,
    this.realworld,
    this.charges,
  });

  factory GlobalStats.fromJson(Map<String, dynamic> json) {
    return GlobalStats(
      totalPlatform: json['totalPlatform'] as num?,
      totalRealworld: json['totalRealworld'] as num?,
      totalCharges: json['totalCharges'] as num?,
      platform: (json['platform'] as List?)
          ?.map((e) => StatItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      realworld: (json['realworld'] as List?)
          ?.map((e) => StatItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      charges: (json['charges'] as List?)
          ?.map((e) => StatItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalPlatform': totalPlatform,
      'totalRealworld': totalRealworld,
      'totalCharges': totalCharges,
      'platform': platform?.map((e) => e.toJson()).toList(),
      'realworld': realworld?.map((e) => e.toJson()).toList(),
      'charges': charges?.map((e) => e.toJson()).toList(),
    };
  }
}

class StatItem {
  String? period;
  num? amount;

  StatItem({
    this.period,
    this.amount,
  });

  factory StatItem.fromJson(Map<String, dynamic> json) {
    return StatItem(
      period: json['period'] as String?,
      amount: json['amount'] as num?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'period': period,
      'amount': amount,
    };
  }
}
