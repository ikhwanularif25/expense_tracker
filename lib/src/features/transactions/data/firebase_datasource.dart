import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

// Kelas ini HANYA tahu cara berbicara dengan Firebase.
class FirebaseDataSource {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Mendapatkan 'path' koleksi pribadi pengguna
  CollectionReference<Map<String, dynamic>> _getTransactionsCollection() {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not logged in");
    // Ini mengarah ke 'users/{userId}/transactions'
    // Sesuai dengan Security Rules yang kita buat
    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('transactions');
  }

  CollectionReference<Map<String, dynamic>> _getCategoriesCollection() {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not logged in");
    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('categories');
  }

  CollectionReference<Map<String, dynamic>> _getBudgetsCollection() {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not logged in");
    return _firestore.collection('users').doc(user.uid).collection('budgets');
  }

  // --- Implementasi CRUD untuk Firebase ---
  Stream<QuerySnapshot<Map<String, dynamic>>> watchCloudTransactions({
    String query = '',
    DateTime? startDate,
    DateTime? endDate,
  }) {
    // Mulai dengan query dasar
    Query<Map<String, dynamic>> queryRef = _getTransactionsCollection().orderBy(
      'date',
      descending: true,
    );

    // Terapkan filter tanggal (untuk Laporan)
    if (startDate != null) {
      queryRef = queryRef.where(
        'date',
        isGreaterThanOrEqualTo: startDate.toIso8601String(),
      );
    }
    if (endDate != null) {
      // Kita perlu 'endDate' + 1 hari untuk 'isLessThan'
      // ATAU gunakan endDate.toIso8601String() jika sudah diatur ke akhir hari
      // Untuk amannya, kita pakai trik 'startOfNextDay'
      final endOfDay = DateTime(endDate.year, endDate.month, endDate.day + 1);
      queryRef = queryRef.where('date', isLessThan: endOfDay.toIso8601String());
    }

    // Terapkan filter pencarian (untuk Dashboard)
    if (query.isNotEmpty) {
      queryRef = queryRef
          .where('note', isGreaterThanOrEqualTo: query)
          .where('note', isLessThanOrEqualTo: '$query\uf8ff');
    }

    return queryRef.snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchCloudBudgets(int period) {
    // Ambil anggaran untuk periode (YYYYMM) saat ini
    return _getBudgetsCollection()
        .where('period', isEqualTo: period)
        .snapshots();
  }

  Future<void> addTransaction(Map<String, dynamic> data) async {
    try {
      await _getTransactionsCollection().add(data);
    } catch (e) {
      debugPrint("Error adding to Firestore: $e");
    }
  }

  Future<void> updateTransaction(
    String docId,
    Map<String, dynamic> data,
  ) async {
    try {
      // Gunakan ID dokumen untuk mencari dan me-replace datanya
      await _getTransactionsCollection().doc(docId).update(data);
    } catch (e) {
      debugPrint("Error updating in Firestore: $e");
    }
  }

  Future<void> deleteTransaction(String docId) async {
    try {
      await _getTransactionsCollection().doc(docId).delete();
    } catch (e) {
      debugPrint("Error deleting from Firestore: $e");
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchCloudCategories() {
    return _getCategoriesCollection().orderBy('name').snapshots();
  }

  // --- FUNGSI BARU: Tambah kategori ke cloud ---
  Future<void> addCategory(Map<String, dynamic> data) async {
    try {
      // Kita set ID dokumen = ID lokal agar sinkron (meski ini tidak ideal)
      // Cara lebih baik: biarkan Firebase generate ID, tapi kita butuh refactor besar.
      // Untuk MVP V2, kita pakai ID lokal.
      await _getCategoriesCollection().doc(data['id'].toString()).set(data);
    } catch (e) {
      debugPrint("Error adding category to Firestore: $e");
    }
  }

  // --- FUNGSI BARU: Update kategori di cloud ---
  Future<void> updateCategory(String docId, Map<String, dynamic> data) async {
    try {
      await _getCategoriesCollection().doc(docId).update(data);
    } catch (e) {
      debugPrint("Error updating category in Firestore: $e");
    }
  }

  // --- FUNGSI BARU: Hapus kategori di cloud ---
  Future<void> deleteCategory(String docId) async {
    try {
      // TODO: Hapus juga transaksi terkait kategori ini di cloud (PENTING)
      await _getCategoriesCollection().doc(docId).delete();
    } catch (e) {
      debugPrint("Error deleting category from Firestore: $e");
    }
  }
  Future<void> setBudget(int categoryId, double amount, int period) async {
    try {
      // Buat ID dokumen kustom agar 'categoryId' & 'period' unik
      // Ini membuat 'setBudget' otomatis bisa untuk 'tambah' atau 'edit'
      final docId = "${categoryId}_$period";

      final data = {
        'categoryId': categoryId,
        'amount': amount,
        'period': period,
      };
      // 'set' dengan 'merge: true' akan membuat baru atau update jika sudah ada
      await _getBudgetsCollection()
          .doc(docId)
          .set(data, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Error setting budget in Firestore: $e");
    }
  }

  Future<void> deleteBudget(int categoryId, int period) async {
    try {
      final docId = "${categoryId}_$period";
      await _getBudgetsCollection().doc(docId).delete();
    } catch (e) {
      debugPrint("Error deleting budget from Firestore: $e");
    }
  }
}

// Nanti kita akan tambahkan fungsi stream, update, delete di sini.
