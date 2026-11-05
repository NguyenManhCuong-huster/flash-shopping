import 'dart:io';

import '../data/models/user.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/group_repository.dart';
import 'session_service.dart';

/// UC01 (đăng ký, xác minh), UC12 (hồ sơ, mật khẩu) và UC02 (nhóm gia đình).
class AccountService {
  AccountService(this._auth, this._groups, this._session);
  final AuthRepository _auth;
  final GroupRepository _groups;
  final SessionService _session;

  Future<String> register(String email, String password, String name) => _auth.register(email: email.trim(), password: password, name: name.trim());
  Future<String?> resendCode(String email) => _auth.sendVerificationCode(email.trim());
  Future<String> verify(String code, String confirmToken) => _auth.verifyEmail(code.trim(), confirmToken);

  Future<User> updateProfile({String? name, String? username, String? language, String? timezone, File? image}) async {
    final u = await _auth.updateProfile(name: name, username: username, language: language, timezone: timezone, image: image);
    _session.updateUser(u);
    return u;
  }

  Future<String> changePassword(String oldPassword, String newPassword) => _auth.changePassword(oldPassword, newPassword);

  Future<void> deleteAccount() async {
    await _auth.deleteAccount();
    await _session.logout();
  }

  // ---------- Nhóm ----------
  Future<Group> group() => _groups.get();

  Future<Group> createGroup(String? name) async {
    final g = await _groups.create(name?.trim().isEmpty ?? true ? null : name!.trim());
    await _session.refreshProfile();
    return g;
  }

  Future<Group> renameGroup(String name) => _groups.rename(name.trim());
  Future<Group> addMember(String username) => _groups.addMember(username.trim());
  Future<Group> removeMember(String username) => _groups.removeMember(username);

  Future<Group> transferLeader(String username) async {
    final g = await _groups.transferLeader(username);
    await _session.refreshProfile();
    return g;
  }

  Future<void> leaveGroup() async {
    await _groups.leave();
    await _session.refreshProfile();
  }
}
