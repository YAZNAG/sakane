import 'package:immobilier/models/realestate.dart';

class ProgramedCharge {
  final int? id;
  final String? nom;
  final String? description;
  final double? amount;
  final String? type;
  final int? month;
  final int? day;
  final String? dayName;
  final Realestate? realestate;

  ProgramedCharge({
    this.id,
    this.nom,
    this.description,
    this.amount,
    this.type,
    this.month,
    this.day,
    this.dayName,
    this.realestate,
  });

  factory ProgramedCharge.fromJson(Map<String, dynamic> json) {
    return ProgramedCharge(
      id: json["id"],
      nom: json["nom"],
      description: json["description"],
      amount: json["amount"] != null ? (json["amount"] as num).toDouble() : null,
      type: json["type"],
      month: json["month"],
      day: json["day"],
      dayName: json["dayName"],
      realestate: json["realestate"] != null
          ? Realestate.fromJson(json["realestate"])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "nom": nom,
      "description": description,
      "amount": amount,
      "type": type,
      "month": month,
      "day": day,
      "dayName": dayName,
      "realestate": realestate?.id,
    };
  }

  ProgramedCharge copyWith({
    int? id,
    String? nom,
    String? description,
    double? amount,
    String? type,
    int? month,
    int? day,
    String? dayName,
    Realestate? realestate,
  }) {
    return ProgramedCharge(
      id: id ?? this.id,
      nom: nom ?? this.nom,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      month: month ?? this.month,
      day: day ?? this.day,
      dayName: dayName ?? this.dayName,
      realestate: realestate ?? this.realestate,
    );
  }
}