import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:expense_tracker/src/features/auth/data/auth_service.dart';
import 'package:expense_tracker/src/services/local_db/drift_db.dart'
    as drift_db;
import '../domain/budget_with_progress.dart';
import '../domain/transaction_with_category.dart';
import '../../reports/domain/report_filter.dart';
import 'firebase_datasource.dart';
import 'local_datasource.dart';
import 'package:rxdart/rxdart.dart';
import 'package:flutter/foundation.dart';

/// Repository Hibrida.
class TransactionRepository {
  final LocalDataSource _localDB;
  final FirebaseDataSource _remoteDB;
  final bool _isCloudMode;
  final String? _userId;

  TransactionRepository(
    this._localDB,
    this._remoteDB,
    this._isCloudMode,
    this._userId,
  );

  // --- Transaksi ---
  // (Fungsi add, update, delete Transaction tidak berubah)
  Future<void> addTransaction(drift_db.TransactionsCompanion entry) async {
    if (_isCloudMode) {
      final data = {
        'amount': entry.amount.value,
        'date': entry.date.value.toIso8601String(),
        'note': entry.note.value,
        'categoryId': entry.categoryId.value,
        'createdAt': FieldValue.serverTimestamp(),
      };
      await _remoteDB.addTransaction(data);
    } else {
      await _localDB.addTransaction(entry);
    }
  }

  Future<void> updateTransaction(
    drift_db.Transaction transaction, {
    String? firestoreDocId,
  }) async {
    if (_isCloudMode) {
      if (firestoreDocId == null) {
        debugPrint("Firestore Doc ID is null, cannot update cloud data");
        return;
      }
      final data = {
        'amount': transaction.amount,
        'date': transaction.date.toIso8601String(),
        'note': transaction.note,
        'categoryId': transaction.categoryId,
      };
      await _remoteDB.updateTransaction(firestoreDocId, data);
    } else {
      await _localDB.updateTransaction(transaction);
    }
  }

  Future<void> deleteTransaction(int localId, {String? firestoreDocId}) async {
    if (_isCloudMode) {
      if (firestoreDocId == null) {
        debugPrint("Firestore Doc ID is null, cannot delete cloud data");
        return;
      }
      await _remoteDB.deleteTransaction(firestoreDocId);
    } else {
      await _localDB.deleteTransaction(localId);
    }
  }

  Stream<List<TransactionWithCategory>> watchAllTransactions({
    String query = '',
  }) {
    // 1. Dapatkan stream kategori (yang sekarang sudah hibrida)
    // PERBAIKAN 1: TUNGGU KATEGORI TERISI (tidak kosong)
    final categoriesStream = watchAllCategories().where(
      (list) => list.isNotEmpty,
    );

    if (_isCloudMode) {
      // --- Logika CLOUD ---
      final transactionsStream = _remoteDB.watchCloudTransactions(query: query);

      return Rx.combineLatest2(transactionsStream, categoriesStream, (
        QuerySnapshot cloudTransactions,
        List<drift_db.Category> cloudCategories, // <-- Data dari CLOUD
      ) {
        return cloudTransactions.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;

          drift_db.Category category;
          try {
            // Cocokkan dengan kategori CLOUD
            category = cloudCategories.firstWhere(
              (cat) => cat.id == data['categoryId'],
            );
          } catch (e) {
            category = drift_db.Category(
              id: -1,
              name: "Unknown",
              color: 0xFF808080,
              iconPath: '',
              isExpense: true,
            );
          }
          // ... (Parsing note sudah benar)
          String? finalNote;
          final String? originalNote = data['note'] as String?;
          final String firestoreDocId = doc.id;
          if (originalNote != null && originalNote.isNotEmpty) {
            finalNote = "$firestoreDocId::$originalNote";
          } else {
            finalNote = firestoreDocId;
          }
          final transaction = drift_db.Transaction(
            id: 0,
            amount: (data['amount'] as num).toDouble(),
            date: DateTime.parse(data['date']),
            note: finalNote,
            categoryId: data['categoryId'],
          );
          return TransactionWithCategory(
            transaction: transaction,
            category: category,
          );
        }).toList();
      });
    } else {
      // --- Logika LOKAL (Tamu) ---
      // (watchAllTransactions lokal sudah mengembalikan TransactionWithCategory)
      return _localDB.watchAllTransactions(query: query);
    }
  }

  // --- Kategori (HIBRIDA) ---

  Stream<List<drift_db.Category>> watchAllCategories() {
    if (_isCloudMode) {
      // Jika login, baca dari Firebase
      return _remoteDB.watchCloudCategories().map((snapshot) {
        return snapshot.docs.map((doc) {
          final data = doc.data();
          return drift_db.Category(
            id: data['id'],
            name: data['name'],
            color: data['color'],
            iconPath: data['iconPath'],
            isExpense: data['isExpense'],
          );
        }).toList();
      });
    } else {
      // Jika tamu, baca dari Lokal
      return _localDB.watchAllCategories();
    }
  }

  Future<void> addCategory(drift_db.CategoriesCompanion entry) async {
    // 'Hack' untuk sinkronisasi ID:
    // 1. Simpan ke lokal DULU untuk dapat ID (jika tamu)
    int localId = -1;
    if (!_isCloudMode) {
      localId = await _localDB.addCategory(entry);
    } else {
      // Jika mode cloud, kita 'simulasikan' insert lokal HANYA untuk dapat ID auto-increment
      localId = await _localDB.addCategory(entry);
    }

    if (_isCloudMode) {
      // 2. Upload ke Firebase
      final data = {
        'id': localId,
        'name': entry.name.value,
        'color': entry.color.value,
        'iconPath': entry.iconPath.value,
        'isExpense': entry.isExpense.value,
      };
      await _remoteDB.addCategory(data);
    }
  }

  Future<void> updateCategory(drift_db.Category category) async {
    await _localDB.updateCategory(category);
    if (_isCloudMode) {
      final data = {
        'name': category.name,
        'color': category.color,
        'iconPath': category.iconPath,
        'isExpense': category.isExpense,
      };
      await _remoteDB.updateCategory(category.id.toString(), data);
    }
  }

  Future<void> deleteCategory(int id) async {
    await _localDB.deleteCategory(id);
    if (_isCloudMode) {
      await _remoteDB.deleteCategory(id.toString());
    }
  }

  // --- Laporan & Dashboard ---

  Stream<Map<String, double>> watchMonthlySummary() {
    // Ambil stream kategori HIBRIDA
    // PERBAIKAN 2: TUNGGU KATEGORI TERISI
    final categoriesStream = watchAllCategories().where(
      (list) => list.isNotEmpty,
    );

    if (_isCloudMode) {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final startOfNextMonth = DateTime(now.year, now.month + 1, 1);

      final transactionsStream = _remoteDB.watchCloudTransactions().map(
        (snapshot) => snapshot.docs.where((doc) {
          try {
            final date = DateTime.parse(doc.data()['date']);
            return date.isAfter(startOfMonth) &&
                date.isBefore(startOfNextMonth);
          } catch (e) {
            return false;
          }
        }).toList(),
      );

      return Rx.combineLatest2(transactionsStream, categoriesStream, (
        List<QueryDocumentSnapshot> cloudTransactions,
        List<drift_db.Category> cloudCategories,
      ) {
        double income = 0;
        double expense = 0;
        for (final doc in cloudTransactions) {
          final data = doc.data() as Map<String, dynamic>;
          try {
            final category = cloudCategories.firstWhere(
              (cat) => cat.id == data['categoryId'],
            );
            if (category.isExpense) {
              expense += (data['amount'] as num).toDouble();
            } else {
              income += (data['amount'] as num).toDouble();
            }
          } catch (e) {
            debugPrint("Error calculating summary (category not found): $e");
          }
        }
        return {
          'income': income,
          'expense': expense,
          'total': income - expense,
        };
      });
    } else {
      return _localDB.watchMonthlySummary();
    }
  }

  Stream<List<Map<String, dynamic>>> watchCategorySumByFilter(
    ReportFilter filter, {
    required bool isExpense,
  }) {
    // Ambil stream kategori HIBRIDA
    // PERBAIKAN 3: TUNGGU KATEGORI TERISI
    final categoriesStream = watchAllCategories().where(
      (list) => list.isNotEmpty,
    );

    if (_isCloudMode) {
      final now = DateTime.now();
      DateTime startDate;
      DateTime endDate;
      switch (filter) {
        // ... (logika switch case tanggal)
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

      final transactionsStream = _remoteDB.watchCloudTransactions(
        startDate: startDate,
        endDate: endDate,
      );

      return Rx.combineLatest2(transactionsStream, categoriesStream, (
        QuerySnapshot cloudTransactions,
        List<drift_db.Category> cloudCategories,
      ) {
        final Map<String, double> totals = {};
        final Map<String, int> colors = {};
        for (final doc in cloudTransactions.docs) {
          final data = doc.data() as Map<String, dynamic>?;
          if (data == null) continue;
          try {
            final category = cloudCategories.firstWhere(
              (cat) => cat.id == data['categoryId'],
            );
            if (category.isExpense == isExpense) {
              final amount = (data['amount'] as num).toDouble();
              totals[category.name] = (totals[category.name] ?? 0) + amount;
              colors[category.name] = category.color;
            }
          } catch (e) {
            debugPrint("Error calculating report: $e");
          }
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
    } else {
      return _localDB.watchCategorySumByFilter(filter, isExpense: isExpense);
    }
  }

  // --- Anggaran (Budget) ---
  Stream<List<BudgetWithProgress>> watchBudgetsWithProgress() {
    // Ambil stream kategori HIBRIDA
    // PERBAIKAN 4: TUNGGU KATEGORI TERISI
    final categoriesStream = watchAllCategories().where(
      (list) => list.isNotEmpty,
    );

    if (_isCloudMode) {
      final now = DateTime.now();
      final currentPeriod = int.parse(
        '${now.year}${now.month.toString().padLeft(2, '0')}',
      );
      final startOfMonth = DateTime(now.year, now.month, 1);
      final startOfNextMonth = DateTime(now.year, now.month + 1, 1);

      final budgetsStream = _remoteDB.watchCloudBudgets(currentPeriod);
      final transactionsStream = _remoteDB.watchCloudTransactions(
        startDate: startOfMonth,
        endDate: startOfNextMonth.subtract(const Duration(days: 1)),
      );

      return Rx.combineLatest3(
        budgetsStream,
        transactionsStream,
        categoriesStream,
        (
          QuerySnapshot cloudBudgets,
          QuerySnapshot cloudTransactions,
          List<drift_db.Category> cloudCategories,
        ) {
          return cloudBudgets.docs.map((budgetDoc) {
            final budgetData = budgetDoc.data() as Map<String, dynamic>?;
            drift_db.Category category;
            try {
              if (budgetData == null) throw Exception("Budget data is null");
              category = cloudCategories.firstWhere(
                (cat) => cat.id == budgetData['categoryId'],
              );
            } catch (e) {
              category = drift_db.Category(
                id: -1,
                name: "Unknown",
                color: 0xFF808080,
                iconPath: '',
                isExpense: true,
              );
            }
            double spent = 0;
            for (final transDoc in cloudTransactions.docs) {
              final data = transDoc.data() as Map<String, dynamic>?;
              if (data != null && data['categoryId'] == category.id) {
                spent += (data['amount'] as num).toDouble();
              }
            }
            final budget = drift_db.Budget(
              id: 0,
              categoryId: budgetData?['categoryId'] ?? 0,
              amount: (budgetData?['amount'] as num? ?? 0).toDouble(),
              period: budgetData?['period'] ?? 0,
            );
            return BudgetWithProgress(
              budget: budget,
              category: category,
              spent: spent,
            );
          }).toList();
        },
      );
    } else {
      return _localDB.watchBudgetsWithProgress();
    }
  }

  Future<void> setBudget(int categoryId, double amount) {
    if (_isCloudMode) {
      final now = DateTime.now();
      final currentPeriod = int.parse(
        '${now.year}${now.month.toString().padLeft(2, '0')}',
      );
      return _remoteDB.setBudget(categoryId, amount, currentPeriod);
    } else {
      return _localDB.setBudget(categoryId, amount);
    }
  }

  Future<void> deleteBudget(int categoryId, int period) {
    if (_isCloudMode) {
      // PERBAIKAN: Gunakan 'period' dari parameter, bukan 'currentPeriod'
      return _remoteDB.deleteBudget(categoryId, period);
    } else {
      return _localDB.deleteBudget(categoryId); // Mode lokal pakai budget.id
    }
  }

  // --- FUNGSI MIGRASI & SEED ---

  Future<void> migrateGuestDataToCloud() async {
    debugPrint("Memulai migrasi data tamu ke cloud...");
    try {
      final localCategories = await _localDB.getAllGuestCategories();
      final localTransactions = await _localDB.getAllGuestTransactions();
      if (localCategories.isEmpty && localTransactions.isEmpty) {
        debugPrint(
          "Tidak ada data tamu untuk dimigrasi. Menjalankan seed data cloud...",
        );
        await seedCloudWithDefaults();
        return;
      }
      final categoriesToUpload = localCategories.map((cat) {
        return {
          'id': cat.id,
          'name': cat.name,
          'color': cat.color,
          'iconPath': cat.iconPath,
          'isExpense': cat.isExpense,
        };
      }).toList();
      final transactionsToUpload = localTransactions.map((t) {
        return {
          'amount': t.amount,
          'date': t.date.toIso8601String(),
          'note': t.note,
          'categoryId': t.categoryId,
          'createdAt': FieldValue.serverTimestamp(),
        };
      }).toList();
      await _remoteDB.batchMigrateCategories(categoriesToUpload);
      await _remoteDB.batchMigrateTransactions(transactionsToUpload);
      await _localDB.deleteAllGuestData();
      debugPrint("Migrasi selesai.");
    } catch (e) {
      debugPrint("MIGRASI GAGAL: $e");
    }
  }

  // (Fase 10 - Baru) Menanam data kategori default di cloud
  // Dibuat 'public' (tanpa '_') agar bisa dipanggil WelcomeScreen
  Future<void> seedCloudWithDefaults() async {
    debugPrint("Menanam kategori default di Firebase...");
    final defaultCategories = [
      {
        'id': 1,
        'name': 'Makanan',
        'color': 0xFFFF5722,
        'iconPath': 'assets/icons/food.svg',
        'isExpense': true,
      },
      {
        'id': 2,
        'name': 'Transport',
        'color': 0xFF03A9F4,
        'iconPath': 'assets/icons/transport.svg',
        'isExpense': true,
      },
      {
        'id': 3,
        'name': 'Gaji',
        'color': 0xFF4CAF50,
        'iconPath': 'assets/icons/salary.svg',
        'isExpense': false,
      },
    ];
    // 1. Tanam di Cloud
    await _remoteDB.batchMigrateCategories(defaultCategories);

    // 2. Tanam di LOKAL (dan TUNGGU (await) sampai selesai)
    // PERBAIKAN: Tambahkan 'await' di setiap pemanggilan
    await _localDB.addCategory(
      drift_db.CategoriesCompanion(
        id: drift.Value(1),
        name: drift.Value('Makanan'),
        color: drift.Value(0xFFFF5722),
        iconPath: drift.Value('assets/icons/food.svg'),
        isExpense: drift.Value(true),
      ),
    );
    await _localDB.addCategory(
      drift_db.CategoriesCompanion(
        id: drift.Value(2),
        name: drift.Value('Transport'),
        color: drift.Value(0xFF03A9F4),
        iconPath: drift.Value('assets/icons/transport.svg'),
        isExpense: drift.Value(true),
      ),
    );
    await _localDB.addCategory(
      drift_db.CategoriesCompanion(
        id: drift.Value(3),
        name: drift.Value('Gaji'),
        color: drift.Value(0xFF4CAF50),
        iconPath: drift.Value('assets/icons/salary.svg'),
        isExpense: drift.Value(false),
      ),
    );
  }
}

// --- PROVIDER UNTUK DATA SOURCES ---
final localDataSourceProvider = Provider<LocalDataSource>((ref) {
  final db = ref.watch(drift_db.appDatabaseProvider);
  return LocalDataSource(db);
});
final firebaseDataSourceProvider = Provider<FirebaseDataSource>((ref) {
  return FirebaseDataSource();
});

// --- PROVIDER REPOSITORY HIBRIDA ---
final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  final localDB = ref.watch(localDataSourceProvider);
  final remoteDB = ref.watch(firebaseDataSourceProvider);
  final authState = ref.watch(authStateProvider);
  final isCloudMode = authState.value != null;
  final userId = authState.value?.uid;
  return TransactionRepository(localDB, remoteDB, isCloudMode, userId);
});
