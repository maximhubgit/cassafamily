import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cassa1/logic/providers/auth_provider.dart';
import 'package:cassa1/data/repositories/entry_repository.dart';
import 'package:cassa1/data/services/cache_service.dart';
import 'package:cassa1/data/models/entry.dart';

final entryRepositoryProvider = Provider<EntryRepository>((ref) {
  return EntryRepository(
    ref.watch(firebaseServiceProvider),
    CacheService(ref.watch(sharedPreferencesProvider)),
  );
});

final entriesProvider = StreamProvider<List<Entry>>((ref) {
  return ref.watch(entryRepositoryProvider).getEntries();
});
