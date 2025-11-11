import 'package:cloud_firestore/cloud_firestore.dart';
// Import 'drift' untuk 'Value'
import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:expense_tracker/src/features/auth/data/auth_service.dart';
// Import 'drift_db' dengan prefix
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
///
/// Bertanggung jawab untuk memutuskan apakah harus memanggil database lokal (Tamu)
/// atau database cloud (Login). UI hanya berinteraksi dengan kelas ini.
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
      // Logika Cloud
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
      // Logika Lokal
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
    if (_isCloudMode) {
      // --- Logika CLOUD ---
      final transactionsStream = _remoteDB.watchCloudTransactions(query: query);
      // PERBAIKAN: Ambil kategori dari LOKAL
      final categoriesStream = _localDB.watchAllCategories();

      return Rx.combineLatest2(transactionsStream, categoriesStream, (
        QuerySnapshot cloudTransactions,
        List<drift_db.Category> localCategories, // <-- Data dari LOKAL
      ) {
        return cloudTransactions.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;

          drift_db.Category category;
          try {
            // Cocokkan dengan kategori LOKAL
            category = localCategories.firstWhere(
              (cat) => cat.id == data['categoryId'],
            );
          } catch (e) {
            // Fallback
            category = drift_db.Category(
              id: -1,
              name: "Unknown",
              color: 0xFF808080,
              iconPath: '',
              isExpense: true,
            );
          }

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
      return _localDB.watchAllTransactions(query: query);
    }
  }

  // --- Kategori ---

  // PERBAIKAN: Kategori selalu ditangani oleh LOKAL
  Stream<List<drift_db.Category>> watchAllCategories() {
    return _localDB.watchAllCategories();
  }

  Future<void> addCategory(drift_db.CategoriesCompanion entry) async {
    // Selalu simpan ke LOKAL
    // TODO (V3): Jika cloud mode, tambahkan sinkronisasi ke Firebase 'categories'
    await _localDB.addCategory(entry);
  }

  Future<void> updateCategory(drift_db.Category category) {
    return _localDB.updateCategory(category);
  }

  Future<void> deleteCategory(int id) {
    return _localDB.deleteCategory(id);
  }

  // --- Laporan & Dashboard ---

  // PERBAIKAN: Implementasi 'watchMonthlySummary' untuk Cloud
  Stream<Map<String, double>> watchMonthlySummary() {
    if (_isCloudMode) {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final startOfNextMonth = DateTime(now.year, now.month + 1, 1);

      // 1. Ambil stream transaksi (cloud)
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

      // 2. Ambil stream kategori (LOKAL)
      final categoriesStream = _localDB.watchAllCategories();

      // 3. Gabungkan
      return Rx.combineLatest2(transactionsStream, categoriesStream, (
        List<QueryDocumentSnapshot> cloudTransactions,
        List<drift_db.Category> localCategories, // <-- Data LOKAL
      ) {
        double income = 0;
        double expense = 0;
        for (final doc in cloudTransactions) {
          final data = doc.data() as Map<String, dynamic>;
          try {
            // Cocokkan dengan kategori LOKAL
            final category = localCategories.firstWhere(
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
    if (_isCloudMode) {
      // --- Logika CLOUD ---
      final now = DateTime.now();
      DateTime startDate;
      DateTime endDate;

      // Tentukan rentang tanggal
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

      // 1. Ambil stream transaksi (cloud) DENGAN FILTER TANGGAL
      final transactionsStream = _remoteDB.watchCloudTransactions(
        startDate: startDate,
        endDate: endDate,
      );

      // 2. Ambil stream kategori (LOKAL)
      final categoriesStream = _localDB.watchAllCategories();

      // 3. Gabungkan
      return Rx.combineLatest2(transactionsStream, categoriesStream, (
        QuerySnapshot cloudTransactions,
        List<drift_db.Category> localCategories,
      ) {
        final Map<String, double> totals = {};
        final Map<String, int> colors = {};

        for (final doc in cloudTransactions.docs) {
          final data =
              doc.data()
                  as Map<String, dynamic>?; // Ambil data sebagai nullable

          if (data == null) continue; // Lewati jika data null

          try {
            // Cocokkan kategori
            final category = localCategories.firstWhere(
              (cat) => cat.id == data['categoryId'],
            );

            // Filter berdasarkan tipe (Pemasukan/Pengeluaran)
            if (category.isExpense == isExpense) {
              final amount = (data['amount'] as num).toDouble();
              totals[category.name] = (totals[category.name] ?? 0) + amount;
              colors[category.name] = category.color;
            }
          } catch (e) {
            debugPrint("Error calculating report (category not found): $e");
          }
        }
        // Ubah Map ke List
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
      // --- Logika LOKAL (sudah benar) ---
      return _localDB.watchCategorySumByFilter(filter, isExpense: isExpense);
    }
  }

  // --- Anggaran (Budget) ---
  Stream<List<BudgetWithProgress>> watchBudgetsWithProgress() {
    if (_isCloudMode) {
      // --- Logika CLOUD ---
      final now = DateTime.now();
      final currentPeriod = int.parse(
        '${now.year}${now.month.toString().padLeft(2, '0')}',
      );
      final startOfMonth = DateTime(now.year, now.month, 1);
      final startOfNextMonth = DateTime(now.year, now.month + 1, 1);

      // 1. Ambil stream budgets (cloud)
      final budgetsStream = _remoteDB.watchCloudBudgets(currentPeriod);

      // 2. Ambil stream transaksi (cloud) untuk bulan ini
      final transactionsStream = _remoteDB.watchCloudTransactions(
        startDate: startOfMonth,
        endDate: startOfNextMonth.subtract(const Duration(days: 1)),
      );

      // 3. Ambil stream kategori (LOKAL)
      final categoriesStream = _localDB.watchAllCategories();

      // 4. Gabungkan ketiganya
      return Rx.combineLatest3(
        budgetsStream,
        transactionsStream,
        categoriesStream,
        (
          QuerySnapshot cloudBudgets,
          QuerySnapshot cloudTransactions,
          List<drift_db.Category> localCategories,
        ) {
          // Buat List<BudgetWithProgress> dari data ini
          return cloudBudgets.docs.map((budgetDoc) {
            final budgetData = budgetDoc.data() as Map<String, dynamic>?;

            drift_db.Category category;
            try {
              if (budgetData == null) throw Exception("Budget data is null");
              category = localCategories.firstWhere(
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

            // Hitung total pengeluaran untuk kategori ini
            double spent = 0;
            for (final transDoc in cloudTransactions.docs) {
              final data = transDoc.data() as Map<String, dynamic>?;
              if (data != null && data['categoryId'] == category.id) {
                spent += (data['amount'] as num).toDouble();
              }
            }

            // Buat objek Budget (palsu) dari data Firebase
            final budget = drift_db.Budget(
              id: 0, // ID lokal tidak relevan
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
      // --- Logika LOKAL (sudah benar) ---
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
      final now = DateTime.now();
      final currentPeriod = int.parse(
        '${now.year}${now.month.toString().padLeft(2, '0')}',
      );
      // Hapus berdasarkan categoryId dan period
      return _remoteDB.deleteBudget(categoryId, currentPeriod);
    } else {
      // Logika lokal hapus berdasarkan ID unik budget
      return _localDB.deleteBudget(
        categoryId,
      ); // 'categoryId' di sini adalah 'budget.id' dari UI
    }
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
