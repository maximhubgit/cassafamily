import 'dart:convert';
import '../models/entry.dart';
import '../services/firebase_service.dart';
import '../services/cache_service.dart';

class EntryRepository {
  final FirebaseService firebaseService;
  final CacheService cacheService;

  EntryRepository(this.firebaseService, this.cacheService);

  Stream<List<Entry>> getEntries() async* {
    final cached = cacheService.getEntries();
    if (cached != null) {
      final List<dynamic> decoded = jsonDecode(cached);
      yield decoded.map((json) => Entry.fromJson(json)).toList();
    }
    await for (final entries in firebaseService.getEntriesStream()) {
      final json = jsonEncode(entries.map((e) => e.toJson()).toList());
      await cacheService.saveEntries(json);
      yield entries;
    }
  }

  Future<void> add(Entry entry) => firebaseService.addEntry(entry);
  Future<void> update(Entry entry) => firebaseService.updateEntry(entry);
  Future<void> delete(String id) => firebaseService.deleteEntry(id);
}
