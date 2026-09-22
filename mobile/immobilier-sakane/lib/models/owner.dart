import 'package:immobilier/models/contrat_proprietaire.dart';
import 'package:immobilier/models/realestate.dart';

class Owner {
  int? id;
  String? name;
  String? email;
  String? tel;
  String? address;
  List<Realestate>? realestates;

  /// Les contrats signés avec ce propriétaire.
  List<ContratProprietaire> contrats;

  Owner({this.id, this.name, this.realestates, this.email, this.tel, this.address, this.contrats = const []});

  factory Owner.fromJson(Map<String, dynamic> json) {
    return Owner(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      tel: json['tel'],
      address:json['address'],
      realestates: (json["realestates"] as List?)?.map((r)=>Realestate.fromJson(r)).toList(),
      contrats: ((json["contrats"] as List?) ?? const [])
          .map((c) => ContratProprietaire.fromJson(Map<String, dynamic>.from(c as Map)))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'tel': tel,
    'address':address
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is Owner && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;


}
