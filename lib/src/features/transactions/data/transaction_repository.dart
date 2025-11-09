import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/local_db/drift_db.dart';

// Repository untuk mengelola data transaksi & kategori
class TransactionRepository {
  final AppDatabase _db;
  TransactionRepository(this._db);

  // Ambil semua transaksi, diurutkan tanggal terbaru
  Stream<List<Transaction>> watchAllTransactions() {
    return (_db.select(_db.transactions)..orderBy([
          (t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc),
        ]))
        .watch();
  }

  // Tambah transaksi baru
  Future<void> addTransaction(TransactionsCompanion entry) {
    return _db.into(_db.transactions).insert(entry);
  }

  // Hapus transaksi
  Future<void> deleteTransaction(int id) {
    return (_db.delete(_db.transactions)..where((t) => t.id.equals(id))).go();
  }

  // Ambil semua kategori (untuk dropdown saat tambah transaksi)
  Future<List<Category>> getAllCategories() {
    return _db.select(_db.categories).get();
  }

  // Stream ringkasan transaksi bulan ini
  Stream<Map<String, double>> watchMonthlySummary() {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    // Akhir bulan ini (awal bulan depan dikurang 1 hari)
    final endOfMonth = DateTime(
      now.year,
      now.month + 1,
      1,
    ).subtract(const Duration(days: 1));

    // Query untuk mengambil transaksi bulan ini beserta data kategorinya
    final query = _db.select(_db.transactions).join([
      innerJoin(
        _db.categories,
        _db.categories.id.equalsExp(_db.transactions.categoryId),
      ),
    ])..where(_db.transactions.date.isBetweenValues(startOfMonth, endOfMonth));

    return query.watch().map((rows) {
      double income = 0;
      double expense = 0;

      for (final row in rows) {
        final transaction = row.readTable(_db.transactions);
        final category = row.readTable(_db.categories);

        if (category.isExpense) {
          expense += transaction.amount;
        } else {
          income += transaction.amount;
        }
      }

      return {'income': income, 'expense': expense, 'total': income - expense};
    });
  }

  // Stream total pengeluaran per kategori bulan ini
  Stream<List<Map<String, dynamic>>> watchCategorySpendingThisMonth() {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(
      now.year,
      now.month + 1,
      1,
    ).subtract(const Duration(days: 1));

    final query =
        _db.select(_db.transactions).join([
            innerJoin(
              _db.categories,
              _db.categories.id.equalsExp(_db.transactions.categoryId),
            ),
          ])
          ..where(
            _db.transactions.date.isBetweenValues(startOfMonth, endOfMonth),
          )
          ..where(_db.categories.isExpense.equals(true)); // Hanya pengeluaran

    return query.watch().map((rows) {
      final Map<String, double> totals = {};
      final Map<String, int> colors = {};

      for (final row in rows) {
        final amount = row.readTable(_db.transactions).amount;
        final categoryName = row.readTable(_db.categories).name;
        final color = row.readTable(_db.categories).color;

        totals[categoryName] = (totals[categoryName] ?? 0) + amount;
        colors[categoryName] = color;
      }

      return totals.entries
          .map(
            (e) => {
              'category': e.key,
              'total': e.value,
              'color': colors[e.key],
            },
          )
          .toList();
    });
  }
}

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return TransactionRepository(db);
});

final transactionListStreamProvider =
    StreamProvider.autoDispose<List<Transaction>>((ref) {
      final repository = ref.watch(transactionRepositoryProvider);
      return repository.watchAllTransactions();
    });

final monthlySummaryStreamProvider =
    StreamProvider.autoDispose<Map<String, double>>((ref) {
      final repository = ref.watch(transactionRepositoryProvider);
      return repository.watchMonthlySummary();
    });

final categorySpendingStreamProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
      final repository = ref.watch(transactionRepositoryProvider);
      return repository.watchCategorySpendingThisMonth();
    });
