class DbUser {
  final String username;
  final bool canCreateDb;
  final bool canCreateRole;

  DbUser({
    required this.username,
    required this.canCreateDb,
    required this.canCreateRole,
  });

  factory DbUser.fromJson(Map<String, dynamic> json) {
    return DbUser(
      username: json['username'],
      canCreateDb: json['canCreateDb'] ?? false,
      canCreateRole: json['canCreateRole'] ?? false,
    );
  }
}

class UserPermission {
  final String tableName;
  final List<String> privileges;

  UserPermission({
    required this.tableName,
    required this.privileges,
  });

  factory UserPermission.fromJson(Map<String, dynamic> json) {
    final privilegesList = json['privileges'] as List<dynamic>? ?? [];
    return UserPermission(
      tableName: json['tableName'],
      privileges: privilegesList.cast<String>(),
    );
  }
}
