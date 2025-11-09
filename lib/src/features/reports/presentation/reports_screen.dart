import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../transactions/data/transaction_repository.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spendingAsync = ref.watch(categorySpendingStreamProvider);
    final currencyFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return Scaffold(
      appBar: AppBar(title: const Text("Laporan Bulan Ini")),
      body: spendingAsync.when(
        data: (data) {
          if (data.isEmpty) {
            return const Center(child: Text("Belum ada pengeluaran bulan ini"));
          }

          final totalSpending = data.fold<double>(
            0,
            (sum, item) => sum + (item['total'] as double),
          );

          return Column(
            children: [
              AspectRatio(
                aspectRatio: 1.3,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 40,
                    sections: data.map((item) {
                      final double value = item['total'];
                      final percentage = (value / totalSpending * 100)
                          .toStringAsFixed(1);
                      return PieChartSectionData(
                        color: Color(item['color']),
                        value: value,
                        title: '$percentage%',
                        radius: 50,
                        titleStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: data.length,
                  itemBuilder: (context, index) {
                    final item = data[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Color(item['color']),
                        radius: 8,
                      ),
                      title: Text(item['category']),
                      trailing: Text(currencyFormat.format(item['total'])),
                    );
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}
