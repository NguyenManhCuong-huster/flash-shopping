import 'common.dart';

class GroupRef {
  const GroupRef(this.id, this.name, this.role);
  final int id;
  final String name;

  /// admin = trưởng nhóm, member = thành viên
  final String role;

  bool get isLeader => role == 'admin';

  factory GroupRef.fromJson(Json j) => GroupRef(toInt(j['id']), j['name']?.toString() ?? '', j['role']?.toString() ?? 'member');
}

class User {
  const User({
    required this.id,
    required this.email,
    required this.name,
    this.username,
    this.language = 'vi',
    this.timezone = 'Asia/Ho_Chi_Minh',
    this.imageUrl,
    this.systemRole = 'user',
    this.isActive = true,
    this.group,
    this.groupId,
    this.groupRole,
  });

  final int id;
  final String email;
  final String name;
  final String? username;
  final String language;
  final String timezone;
  final String? imageUrl;
  final String systemRole;
  final bool isActive;
  final GroupRef? group;

  /// Chỉ có trong danh sách người dùng của trang quản trị
  final int? groupId;
  final String? groupRole;

  bool get isSystemAdmin => systemRole == 'admin';

  factory User.fromJson(Json j) => User(
        id: toInt(j['id']),
        email: j['email']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        username: j['username']?.toString(),
        language: j['language']?.toString() ?? 'vi',
        timezone: j['timezone']?.toString() ?? 'Asia/Ho_Chi_Minh',
        imageUrl: j['imageUrl']?.toString(),
        systemRole: j['systemRole']?.toString() ?? 'user',
        isActive: j['isActive'] != false,
        group: j['group'] is Map ? GroupRef.fromJson(asJson(j['group'])) : null,
        groupId: j['groupId'] == null ? null : toInt(j['groupId']),
        groupRole: j['groupRole']?.toString(),
      );
}

class Member {
  const Member({required this.id, required this.name, this.username, this.imageUrl, this.role = 'member'});
  final int id;
  final String name;
  final String? username;
  final String? imageUrl;
  final String role;

  bool get isLeader => role == 'admin';

  factory Member.fromJson(Json j) => Member(
        id: toInt(j['id']),
        name: j['name']?.toString() ?? '',
        username: j['username']?.toString(),
        imageUrl: j['imageUrl']?.toString(),
        role: j['role']?.toString() ?? 'member',
      );
}

class Group {
  const Group({required this.id, required this.name, required this.members});
  final int id;
  final String name;
  final List<Member> members;

  factory Group.fromJson(Json j) =>
      Group(id: toInt(j['id']), name: j['name']?.toString() ?? '', members: asList(j['members']).map(Member.fromJson).toList());
}

/// Kết quả đăng nhập.
class AuthTokens {
  const AuthTokens(this.accessToken, this.refreshToken, this.user);
  final String accessToken;
  final String refreshToken;
  final User user;
}
