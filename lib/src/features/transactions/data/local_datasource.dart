import 'package:drift/drift.dart';
import 'package:expense_tracker/src/features/reports/domain/report_filter.dart';
import 'package:expense_tracker/src/services/local_db/drift_db.dart'
    as drift_db;
import '../domain/budget_with_progress.dart';
import '../domain/transaction_with_category.dart';

/// Kelas ini HANYA bertanggung jawab untuk berbicara dengan database lokal (Drift/SQLite).
/// Ini adalah implementasi "offline-first" atau "guest-mode".
class LocalDataSource {
  final drift_db.AppDatabase _db;
  LocalDataSource(this._db);

  // --- Transaksi ---

  Future<void> addTransaction(drift_db.TransactionsCompanion entry) {
    return _db.into(_db.transactions).insert(entry);
  }

  Future<void> updateTransaction(drift_db.Transaction transaction) {
    return _db.update(_db.transactions).replace(transaction);
  }

  Future<void> deleteTransaction(int id) {
    return (_db.delete(_db.transactions)..where((t) => t.id.equals(id))).go();
  }

  Stream<List<TransactionWithCategory>> watchAllTransactions({
    String query = '',
  }) {
    final initialQuery = _db.select(_db.transactions).join([
      innerJoin(
        _db.categories,
        _db.categories.id.equalsExp(_db.transactions.categoryId),
      ),
    ]);

    if (query.isNotEmpty) {
      initialQuery.where(
        _db.transactions.note.contains(query) |
            _db.transactions.amount.cast<String>().contains(query) |
            _db.categories.name.contains(query),
      );
    }

    initialQuery.orderBy([
      OrderingTerm(expression: _db.transactions.date, mode: OrderingMode.desc),
    ]);

    return initialQuery.watch().map((rows) {
      return rows.map((row) {
        return TransactionWithCategory(
          transaction: row.readTable(_db.transactions),
          category: row.readTable(_db.categories),
        );
      }).toList();
    });
  }

  // --- Kategori ---

  Future<List<drift_db.Category>> getAllCategories() {
    return (_db.select(_db.categories)..orderBy([
          (t) => OrderingTerm(expression: t.isExpense, mode: OrderingMode.desc),
          (t) => OrderingTerm(expression: t.name),
        ]))
        .get();
  }

  Future<void> updateCategory(drift_db.Category category) {
    return _db.update(_db.categories).replace(category);
  }

  Future<void> deleteCategory(int id) async {
    // Hapus transaksi terkait dulu (Cascade Delete manual)
    await (_db.delete(
      _db.transactions,
    )..where((t) => t.categoryId.equals(id))).go();
    // Lalu hapus kategorinya
    await (_db.delete(_db.categories)..where((c) => c.id.equals(id))).go();
  }

  // --- Laporan & Dashboard ---

  Stream<Map<String, double>> watchMonthlySummary() {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(
      now.year,
      now.month + 1,
      1,
    ).subtract(const Duration(days: 1));

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

  Stream<List<Map<String, dynamic>>> watchCategorySumByFilter(
    ReportFilter filter, {
    required bool isExpense,
  }) {
    final now = DateTime.now();
    DateTime startDate;
    DateTime endDate;

    switch (filter) {
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
          ..where(_db.categories.isExpense.equals(isExpense));

    return query.watch().map((rows) {
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

  // --- Anggaran (Budget) ---

  Stream<List<BudgetWithProgress>> watchBudgetsWithProgress() {
    final now = DateTime.now();
    final currentPeriod = int.parse(
      '${now.year}${now.month.toString().padLeft(2, '0')}',
    );
    final startOfMonth = DateTime(now.year, now.month, 1);
    final startOfNextMonth = DateTime(now.year, now.month + 1, 1);

    final combinedTrigger = _db
        .customSelect(
          'SELECT 1',
          readsFrom: {_db.budgets, _db.categories, _db.transactions},
        )
        .watch();

    return combinedTrigger.asyncMap((_) async {
      final budgetRows = await (_db.select(_db.budgets).join([
        innerJoin(
          _db.categories,
          _db.categories.id.equalsExp(_db.budgets.categoryId),
        ),
      ])..where(_db.budgets.period.equals(currentPeriod))).get();

      final List<BudgetWithProgress> results = [];

      for (final row in budgetRows) {
        final budget = row.readTable(_db.budgets);
        final category = row.readTable(_db.categories);

        final querySpent = _db.select(_db.transactions)
          ..where((t) => t.categoryId.equals(category.id))
          ..where(
            (t) =>
                t.date.isBiggerOrEqualValue(startOfMonth) &
                t.date.isSmallerThanValue(startOfNextMonth),
          );

        final transactions = await querySpent.get();
        final spent = transactions.fold<double>(0, (sum, t) => sum + t.amount);

        results.add(
          BudgetWithProgress(budget: budget, category: category, spent: spent),
        );
      }
      return results;
    });
  }

  Future<void> setBudget(int categoryId, double amount) async {
    final now = DateTime.now();
    final currentPeriod = int.parse(
      '${now.year}${now.month.toString().padLeft(2, '0')}',
    );

    await _db.transaction(() async {
      final existingBudget =
          await (_db.select(_db.budgets)..where(
                (t) =>
                    t.categoryId.equals(categoryId) &
                    t.period.equals(currentPeriod),
              ))
              .getSingleOrNull();

      if (existingBudget != null) {
        await (_db.update(_db.budgets)
              ..where((t) => t.id.equals(existingBudget.id)))
            .write(drift_db.BudgetsCompanion(amount: Value(amount)));
      } else {
        await _db
            .into(_db.budgets)
            .insert(
              drift_db.BudgetsCompanion.insert(
                categoryId: categoryId,
                amount: amount,
                period: currentPeriod,
              ),
            );
      }
    });
  }

  Future<void> deleteBudget(int id) {
    return (_db.delete(_db.budgets)..where((t) => t.id.equals(id))).go();
  }

  Stream<List<drift_db.Category>> watchAllCategories() {
    return (_db.select(_db.categories)).watch();
  }

  Future<int> addCategory(drift_db.CategoriesCompanion entry) {
    // .insert() di Drift akan mengembalikan ID yang baru dibuat
    return _db.into(_db.categories).insert(entry);
  }

  // FUNGSI BARU: Ambil semua data mentah (bukan stream)
  Future<List<drift_db.Category>> getAllGuestCategories() {
    return _db.select(_db.categories).get();
  }

  Future<List<drift_db.Transaction>> getAllGuestTransactions() {
    return _db.select(_db.transactions).get();
  }

  // FUNGSI BARU: Hapus semua data setelah migrasi
  Future<void> deleteAllGuestData() async {
    await _db.delete(_db.transactions).go();
    await _db.delete(_db.categories).go();
    await _db.delete(_db.budgets).go();
    // TODO: Hapus juga data 'shared_preferences' isGuest
  }
}
