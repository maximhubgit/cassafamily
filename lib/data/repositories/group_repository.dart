import 'dart:convert';
import '../models/group.dart';
import '../services/firebase_service.dart';
import '../services/cache_service.dart';

class GroupRepository {
  final FirebaseService firebaseService;
  final CacheService cacheService;

  GroupRepository(this.firebaseService, this.cacheService);

  Stream<List<Group>> getGroups() async* {
    final cached = cacheService.getGroups();
    if (cached != null) {
      final List<dynamic> decoded = jsonDecode(cached);
      yield decoded.map((json) => Group.fromJson(json)).toList();
    }
    await for (final groups in firebaseService.getGroupsStream()) {
      final json = jsonEncode(groups.map((g) => g.toJson()).toList());
      await cacheService.saveGroups(json);
      yield groups;
    }
  }

  Future<void> add(Group group) => firebaseService.addGroup(group);
  Future<void> update(Group group) => firebaseService.updateGroup(group);
  Future<void> delete(String id) => firebaseService.deleteGroup(id);
}
