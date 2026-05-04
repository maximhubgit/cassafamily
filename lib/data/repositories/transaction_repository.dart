import 'dart:convert';
import '../models/transaction.dart';
import '../services/firebase_service.dart';
import '../services/cache_service.dart';

class TransactionRepository {
  final FirebaseService firebaseService;
  final CacheService cacheService;

  TransactionRepository(this.firebaseService, this.cacheService);

  Stream<List<AppTransaction>> getTransactions() async* {
    final cached = cacheService.getTransactions();
    if (cached != null) {
      final List<dynamic> decoded = jsonDecode(cached);
      yield decoded.map((json) => AppTransaction.fromJson(json)).toList();
    }
    await for (final transactions in firebaseService.getTransactionsStream()) {
      final json = jsonEncode(transactions.map((t) => t.toJson()).toList());
      await cacheService.saveTransactions(json);
      yield transactions;
    }
  }

  Future<void> add(AppTransaction transaction) => firebaseService.addTransaction(transaction);
  Future<void> update(AppTransaction transaction) => firebaseService.updateTransaction(transaction);
  Future<void> delete(String id) => firebaseService.deleteTransaction(id);

  Future<bool> isEntryLinked(String entryId) async {
    await for (final transactions in getTransactions()) {
      return transactions.any((t) => t.entryId == entryId);
    }
    return false;
  }
}
