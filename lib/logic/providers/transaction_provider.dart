import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cassa1/logic/providers/auth_provider.dart';
import 'package:cassa1/data/repositories/transaction_repository.dart';
import 'package:cassa1/data/services/cache_service.dart';
import 'package:cassa1/data/models/transaction.dart';

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository(
    ref.watch(firebaseServiceProvider),
    CacheService(ref.watch(sharedPreferencesProvider)),
  );
});

final transactionsProvider = StreamProvider<List<AppTransaction>>((ref) {
  return ref.watch(transactionRepositoryProvider).getTransactions();
});
