import 'package:immobilier/core/constants/enums/permissions.dart';

extension AppPermissionExtension on AppPermission {
  /// Code du droit tel que le serveur le connaît (ex. « create_property »).
  String get permissionName => code;
}
