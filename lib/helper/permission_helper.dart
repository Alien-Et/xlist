import 'package:xlist/models/user.dart';

class PermissionHelper {
  static bool isAdmin(UserModel user) => user.role == UserRole.ADMIN;

  /// 是否有权限
  /// [user] 用户
  /// [permission] 权限
  static bool can(UserModel user, int permission) {
    return PermissionHelper.isAdmin(user) ||
        ((user.permission ?? 0) >> permission) & 1 == 1;
  }

  static bool canWrite(UserModel user) => PermissionHelper.can(user, 3);
  static bool canRename(UserModel user) => PermissionHelper.can(user, 4);
  static bool canMove(UserModel user) => PermissionHelper.can(user, 5);
  static bool canCopy(UserModel user) => PermissionHelper.can(user, 6);
  static bool canDelete(UserModel user) => PermissionHelper.can(user, 7);
}
