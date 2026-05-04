import 'package:shared_preferences/shared_preferences.dart';
// import 'dart:convert'; // non usato

class CacheService {
  final SharedPreferences prefs;

  CacheService(this.prefs);

  Future<void> save(String key, String json) async {
    await prefs.setString(key, json);
  }

  String? get(String key) {
    return prefs.getString(key);
  }

  // Subjects
  Future<void> saveSubjects(String json) => save('subjects', json);
  String? getSubjects() => get('subjects');

  // Groups
  Future<void> saveGroups(String json) => save('groups', json);
  String? getGroups() => get('groups');

  // Entries
  Future<void> saveEntries(String json) => save('entries', json);
  String? getEntries() => get('entries');

  // Transactions
  Future<void> saveTransactions(String json) => save('transactions', json);
  String? getTransactions() => get('transactions');
}
