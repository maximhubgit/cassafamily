import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cassa1/logic/providers/auth_provider.dart';
import 'package:cassa1/data/repositories/group_repository.dart';
import 'package:cassa1/data/services/cache_service.dart';
import 'package:cassa1/data/models/group.dart';

final groupRepositoryProvider = Provider<GroupRepository>((ref) {
  return GroupRepository(
    ref.watch(firebaseServiceProvider),
    CacheService(ref.watch(sharedPreferencesProvider)),
  );
});

final groupsProvider = StreamProvider<List<Group>>((ref) {
  return ref.watch(groupRepositoryProvider).getGroups();
});
