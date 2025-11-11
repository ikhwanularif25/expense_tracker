import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../transactions/presentation/transaction_providers.dart';

class SummaryCard extends ConsumerWidget {
  const SummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Mengambil data ringkasan bulan ini dari provider
    final summaryAsync = ref.watch(monthlySummaryStreamProvider);
    // Formatter mata uang Rupiah
    final currencyFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 8, // Sedikit lebih menonjol
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          // Gradient warna modern
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.tertiary,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.primary.withAlpha(80),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: summaryAsync.when(
          data: (summary) => Column(
            children: [
              const Text(
                "Saldo Bulan Ini",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              // Widget Animasi untuk Saldo Utama
              AnimatedAmount(
                amount: summary['total'] ?? 0,
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1,
                ),
                formatter: currencyFormat,
              ),
              const SizedBox(height: 32),
              // Baris Pemasukan & Pengeluaran
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSummaryItem(
                    "Pemasukan",
                    summary['income'] ?? 0,
                    Colors.greenAccent.shade200,
                    currencyFormat,
                    Icons.arrow_downward_rounded,
                  ),
                  // Garis pemisah vertikal tipis
                  Container(height: 40, width: 1, color: Colors.white24),
                  _buildSummaryItem(
                    "Pengeluaran",
                    summary['expense'] ?? 0,
                    Colors.redAccent.shade100,
                    currencyFormat,
                    Icons.arrow_upward_rounded,
                  ),
                ],
              ),
            ],
          ),
          loading: () => const SizedBox(
            height: 180,
            child: Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),
          error: (_, __) => const SizedBox(
            height: 180,
            child: Center(
              child: Text(
                "Gagal memuat data",
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Fungsi helper untuk membangun item summary (Pemasukan/Pengeluaran)
  Widget _buildSummaryItem(
    String label,
    double amount,
    Color color,
    NumberFormat formatter,
    IconData icon,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: color.withAlpha(50), // Transparan
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Widget Animasi untuk item Pemasukan/Pengeluaran
        AnimatedAmount(
          amount: amount,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: Colors.white,
          ),
          formatter: formatter,
        ),
      ],
    );
  }
}

// --- Widget Terpisah untuk Animasi Angka ---
class AnimatedAmount extends StatelessWidget {
  final double amount;
  final TextStyle style;
  final NumberFormat formatter;

  const AnimatedAmount({
    super.key,
    required this.amount,
    required this.style,
    required this.formatter,
  });

  @override
  Widget build(BuildContext context) {
    // TweenAnimationBuilder otomatis menganimasikan perubahan nilai 'amount'
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: amount),
      duration: const Duration(milliseconds: 1500),
      curve: Curves.easeOutExpo, // Kurva animasi yang halus
      builder: (context, value, child) {
        return Text(formatter.format(value), style: style);
      },
    );
  }
}
