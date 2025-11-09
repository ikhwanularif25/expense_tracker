import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/local_db/drift_db.dart';
import '../../reports/domain/report_filter.dart';
import '../domain/transaction_with_category.dart';

// Repository untuk mengelola data transaksi & kategori
class TransactionRepository {
  final AppDatabase _db;
  TransactionRepository(this._db);

  // Ambil semua transaksi, diurutkan tanggal terbaru
 Stream<List<TransactionWithCategory>> watchAllTransactions() {
    final query =
        _db.select(_db.transactions).join([
          innerJoin(
            _db.categories,
            _db.categories.id.equalsExp(_db.transactions.categoryId),
          ),
        ])..orderBy([
          // Urutkan berdasarkan tanggal transaksi descending
          OrderingTerm(
            expression: _db.transactions.date,
            mode: OrderingMode.desc,
          ),
        ]);

    return query.watch().map((rows) {
      return rows.map((row) {
        return TransactionWithCategory(
          transaction: row.readTable(_db.transactions),
          category: row.readTable(_db.categories),
        );
      }).toList();
    });
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
    // Urutkan berdasarkan jenis (isExpense) lalu nama
    return (_db.select(_db.categories)..orderBy([
          (t) => OrderingTerm(
            expression: t.isExpense,
            mode: OrderingMode.desc,
          ), // Pengeluaran dulu (true = 1, false = 0 di SQLite biasanya, sesuaikan jika terbalik)
          (t) => OrderingTerm(expression: t.name),
        ]))
        .get();
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
  Stream<List<Map<String, dynamic>>> watchCategorySumByFilter(
    ReportFilter filter, {
    required bool isExpense,
  }) {
    final now = DateTime.now();
    DateTime startDate;
    DateTime endDate;

    // ... (logika switch case filter tanggal TETAP SAMA) ...
    switch (filter) {
      // ... copas case yang lama ...
      case ReportFilter.thisMonth:
        startDate = DateTime(now.year, now.month, 1);
        endDate = DateTime(
          now.year,
          now.month + 1,
          1,
        ).subtract(const Duration(days: 1));
        break;
      case ReportFilter.lastMonth:
        startDate = DateTime(now.year, now.month - 1, 1);
        endDate = DateTime(now.year, now.month, 0);
        break;
      case ReportFilter.thisYear:
        startDate = DateTime(now.year, 1, 1);
        endDate = DateTime(now.year, 12, 31);
        break;
    }

    final query =
        _db.select(_db.transactions).join([
            innerJoin(
              _db.categories,
              _db.categories.id.equalsExp(_db.transactions.categoryId),
            ),
          ])
          ..where(_db.transactions.date.isBetweenValues(startDate, endDate))
          ..where(
            _db.categories.isExpense.equals(isExpense),
          ); // GUNAKAN PARAMETER BARU DI SINI

    return query.watch().map((rows) {
      // ... (logika mapping TETAP SAMA) ...
      final Map<String, double> totals = {};
      final Map<String, int> colors = {};
      for (final row in rows) {
        final amount = row.readTable(_db.transactions).amount;
        final category = row.readTable(_db.categories);
        totals[category.name] = (totals[category.name] ?? 0) + amount;
        colors[category.name] = category.color;
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

  Future<void> updateTransaction(Transaction transaction) {
    // .replace otomatis menggunakan ID dari objek transaction untuk mencari baris yang tepat
    return _db.update(_db.transactions).replace(transaction);
  }

  Future<void> updateCategory(Category category) {
    return _db.update(_db.categories).replace(category);
  }

  // Hapus kategori (Hati-hati: Transaksi yang menggunakan kategori ini bisa jadi orphan/yatim)
  Future<void> deleteCategory(int id) async {
    // Opsi 1: Hapus semua transaksi terkait dulu (Cascade Delete manual)
    await (_db.delete(
      _db.transactions,
    )..where((t) => t.categoryId.equals(id))).go();
    // Lalu hapus kategorinya
    await (_db.delete(_db.categories)..where((c) => c.id.equals(id))).go();
  }
}

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return TransactionRepository(db);
});

final transactionListStreamProvider =
    StreamProvider.autoDispose<List<TransactionWithCategory>>((ref) {
      final repository = ref.watch(transactionRepositoryProvider);
      return repository.watchAllTransactions();
    });

final monthlySummaryStreamProvider =
    StreamProvider.autoDispose<Map<String, double>>((ref) {
      final repository = ref.watch(transactionRepositoryProvider);
      return repository.watchMonthlySummary();
    });
