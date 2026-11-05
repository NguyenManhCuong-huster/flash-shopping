import '../models/common.dart';
import '../models/user.dart';
import '../remote/api_client.dart';

/// UC02: nhóm gia đình.
class GroupRepository {
  GroupRepository(this._api);
  final ApiClient _api;

  Group _group(ApiResponse r) => Group.fromJson(asJson(r.map['group']));

  Future<Group> get() async => _group(await _api.get('/user/group'));
  Future<Group> create(String? name) async => _group(await _api.post('/user/group', data: {'name': name}));
  Future<Group> rename(String name) async => _group(await _api.put('/user/group', data: {'name': name}));
  Future<Group> addMember(String username) async => _group(await _api.post('/user/group/add', data: {'username': username}));
  Future<Group> removeMember(String username) async => _group(await _api.delete('/user/group', data: {'username': username}));
  Future<Group> transferLeader(String username) async => _group(await _api.put('/user/group/leader', data: {'username': username}));
  Future<void> leave() => _api.post('/user/group/leave');
}
