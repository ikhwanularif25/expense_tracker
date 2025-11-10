import '../../../services/local_db/drift_db.dart';

/// Model gabungan untuk menampung data Anggaran (Budget)
/// beserta kategori dan total pengeluaran saat ini (spent).
class BudgetWithProgress {
  final Budget budget;
  final Category category;
  final double spent; // Total pengeluaran bulan ini untuk kategori ini

  BudgetWithProgress({
    required this.budget,
    required this.category,
    required this.spent,
  });

  // Getter untuk menghitung progres (0.0 - 1.0)
  double get progress => (spent / budget.amount).clamp(0.0, 1.0);

  // Getter untuk sisa anggaran
  double get remaining => budget.amount - spent;
}
