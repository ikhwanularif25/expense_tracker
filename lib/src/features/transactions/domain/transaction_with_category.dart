import '../../../services/local_db/drift_db.dart';

/// Kelas model gabungan untuk menampung data Transaksi beserta Kategorinya.
/// Digunakan untuk menampilkan data lengkap di UI (misal: HomeScreen).
class TransactionWithCategory {
  final Transaction transaction;
  final Category category;

  TransactionWithCategory({required this.transaction, required this.category});
}
