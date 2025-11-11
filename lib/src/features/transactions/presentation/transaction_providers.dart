import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../data/transaction_repository.dart';
import '../domain/transaction_with_category.dart';
// 1. Beri prefix pada import database
import 'package:expense_tracker/src/services/local_db/drift_db.dart'
    as drift_db;

// Provider untuk menyimpan keyword pencarian saat ini (State UI)
final searchQueryProvider = StateProvider.autoDispose<String>((ref) => '');

// Provider stream utama untuk daftar transaksi.
final transactionListStreamProvider =
    StreamProvider.autoDispose<List<TransactionWithCategory>>((ref) {
      final repository = ref.watch(transactionRepositoryProvider);
      final query = ref.watch(searchQueryProvider);

      return repository.watchAllTransactions(query: query);
    });

// Provider untuk stream summary dashboard
final monthlySummaryStreamProvider =
    StreamProvider.autoDispose<Map<String, double>>((ref) {
      final repository = ref.watch(transactionRepositoryProvider);
      return repository.watchMonthlySummary();
    });

// 2. Gunakan prefix 'drift_db.Category'
final categoryListStreamProvider =
    StreamProvider.autoDispose<List<drift_db.Category>>((ref) {
      final repository = ref.watch(transactionRepositoryProvider);
      return repository.watchAllCategories();
    });
