import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:intl/intl.dart';
import '../../transactions/data/transaction_repository.dart';
import '../domain/report_filter.dart';

// Provider state filter waktu
final reportFilterProvider = StateProvider.autoDispose<ReportFilter>(
  (ref) => ReportFilter.thisMonth,
);

// Provider state tipe laporan (true = Pengeluaran, false = Pemasukan)
final reportTypeProvider = StateProvider.autoDispose<bool>((ref) => true);

// Provider stream laporan utama
final filteredReportStreamProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
      final filter = ref.watch(reportFilterProvider);
      final isExpense = ref.watch(
        reportTypeProvider,
      ); // Watch tipe laporan juga
      final repository = ref.watch(transactionRepositoryProvider);
      // Panggil fungsi repo yang baru
      return repository.watchCategorySumByFilter(filter, isExpense: isExpense);
    });

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spendingAsync = ref.watch(filteredReportStreamProvider);
    final currentFilter = ref.watch(reportFilterProvider);
    final isExpense = ref.watch(reportTypeProvider);
    final currencyFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Laporan ${isExpense ? 'Pengeluaran' : 'Pemasukan'}",
        ), // Judul dinamis
        actions: [
          // Dropdown Filter Waktu
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<ReportFilter>(
                value: currentFilter,
                icon: const Icon(Icons.filter_list),
                style: Theme.of(context).textTheme.bodyMedium,
                dropdownColor: Theme.of(context).colorScheme.surfaceVariant,
                items: ReportFilter.values.map((filter) {
                  return DropdownMenuItem(
                    value: filter,
                    child: Text(filter.label),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null)
                    ref.read(reportFilterProvider.notifier).state = value;
                },
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          // TOGGLE TIPE LAPORAN
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment<bool>(
                value: true,
                label: Text('Pengeluaran'),
                icon: Icon(Icons.money_off),
              ),
              ButtonSegment<bool>(
                value: false,
                label: Text('Pemasukan'),
                icon: Icon(Icons.attach_money),
              ),
            ],
            selected: {isExpense},
            onSelectionChanged: (Set<bool> newSelection) {
              ref.read(reportTypeProvider.notifier).state = newSelection.first;
            },
          ),
          const SizedBox(height: 16),

          // ISI LAPORAN
          Expanded(
            child: spendingAsync.when(
              data: (data) {
                if (data.isEmpty) {
                  return Center(
                    child: Text(
                      "Belum ada data ${isExpense ? 'pengeluaran' : 'pemasukan'}\nuntuk periode ini",
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  );
                }

                final totalSum = data.fold<double>(
                  0,
                  (sum, item) => sum + (item['total'] as double),
                );

                return Column(
                  children: [
                    AspectRatio(
                      aspectRatio: 1.5, // Sedikit lebih lebar
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 40,
                          sections: data.map((item) {
                            final double value = item['total'];
                            final percentage = (value / totalSum * 100)
                                .toStringAsFixed(1);
                            return PieChartSectionData(
                              color: Color(item['color']),
                              value: value,
                              title: '$percentage%',
                              radius: 80,
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
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        "Total: ${currencyFormat.format(totalSum)}",
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
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
                            trailing: Text(
                              currencyFormat.format(item['total']),
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
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
          ),
        ],
      ),
    );
  }
}
