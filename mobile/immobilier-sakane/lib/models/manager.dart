import 'package:immobilier/core/constants/enums/permissions.dart';
import 'package:immobilier/core/extensions/extension_on_app_permision.dart';

class Manager {
  int? id;
  String? firstName;
  String? lastName;
  String? email;
  String? token;
  String? password;
  String? fcmToken;
  String? phone;
  Set<String>? permissions;
  List<String>? roles;

  Manager({
    this.id,
    this.firstName,
    this.lastName,
    this.email,
    this.token,
    this.password,
    this.fcmToken,
    this.permissions,
    this.roles,
    this.phone
  });

  factory Manager.fromJson(Map<String, dynamic> json) {
    return Manager(
      id: json['id'],
      firstName: json['firstName'],
      lastName: json['lastName'],
      email: json['email'],
      token: json['token'],
      password: json['password'],
      fcmToken: json['fcmToken'],
      permissions: (json["permissions"] as List?)?.map((p)=>p.toString()).toSet(),
      roles: (json["roles"] as List?)?.map((p)=>p.toString()).toList(),
      phone: json["phone"]
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'firstName':firstName,
      'lastName':lastName,
      'email': email,
      'password': password,
      'fcmToken': fcmToken,
      'role':roles?.first,
      "phone":phone
    };
  }

  String get name{
    if (firstName?.isEmpty??true) return "$firstName";
    return "${firstName![0].toUpperCase()}${firstName!.substring(1)}";
  }

  /// Vrai si l'utilisateur a le rôle administrateur (tous les droits).
  bool get isAdmin =>
      (roles ?? const <String>[]).any((r) => r.trim().toLowerCase() == 'admin');

  /// Vrai si l'utilisateur a ce droit. L'administrateur peut tout ;
  /// pour les autres, [permissions] contient les droits effectifs
  /// (rôle + accordés − retirés) renvoyés par le serveur.
  bool can(AppPermission permission){
    if (isAdmin) return true;
    String permissionName=permission.permissionName;
    return (permissions?.contains(permissionName)??false);
  }

  /// Vrai si l'utilisateur a au moins un de ces droits
  /// (le serveur accepte une route dès qu'un des droits exigés est présent).
  bool canAny(Iterable<AppPermission> liste) => liste.any(can);

  bool get isHasAccessToPlatform{
    return canAny(const [AppPermission.viewSlider, AppPermission.viewAnnounces, AppPermission.activateAnnounce, AppPermission.cancelAnnounce]);
  }

  Manager copyWith({
    int? id,
    String? firstName,
    String? lastName,
    String? email,
    String? token,
    String? password,
    String? fcmToken,
    Set<String>? permissions,
    List<String>? roles,
    String? permissionName,
    String? phone
  }) {
    return Manager(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      token: token ?? this.token,
      password: password ?? this.password,
      fcmToken: fcmToken ?? this.fcmToken,
      permissions: permissions ?? this.permissions,
      roles: roles ?? this.roles,
      phone: phone ?? this.phone
    );
  }

}
