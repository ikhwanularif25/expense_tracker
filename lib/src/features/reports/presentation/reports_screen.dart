import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:intl/intl.dart';
import '../../../common_widgets/empty_placeholder_widget.dart';
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
                dropdownColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                items: ReportFilter.values.map((filter) {
                  return DropdownMenuItem(
                    value: filter,
                    child: Text(filter.label),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    HapticFeedback.selectionClick();
                    ref.read(reportFilterProvider.notifier).state = value;
                  }
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
              HapticFeedback.selectionClick();
              ref.read(reportTypeProvider.notifier).state = newSelection.first;
            },
          ),
          const SizedBox(height: 16),

          // ISI LAPORAN
          Expanded(
            child: spendingAsync.when(
              data: (data) {
                if (data.isEmpty) {
                  return EmptyPlaceholderWidget(
                    message:
                        "Tidak ada data ${isExpense ? 'pengeluaran' : 'pemasukan'}\nuntuk periode ${currentFilter.label.toLowerCase()}.",
                    iconData: Icons.pie_chart_outline, // Ikon chart kosong
                  );
                }

                final totalSum = data.fold<double>(
                  0,
                  (sum, item) => sum + (item['total'] as double),
                );

                return Column(
                  children: [
                    AspectRatio(
                      aspectRatio: 1.5,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0.0, end: 1.0),
                        duration: const Duration(seconds: 1),
                        curve: Curves.easeOutCirc,
                        builder: (context, animValue, child) {
                          return PieChart(
                            PieChartData(
                              sectionsSpace: 2,
                              centerSpaceRadius: 40,
                              startDegreeOffset: 270,
                              sections: data.map((item) {
                                final double originalValue = item['total'];
                                final double animatedValue =
                                    originalValue * animValue;

                                final percentage =
                                    (originalValue / totalSum * 100)
                                        .toStringAsFixed(1);

                                return PieChartSectionData(
                                  color: Color(item['color']),
                                  value: animatedValue,
                                  title: animValue > 0.5 ? '$percentage%' : '',
                                  radius: 80,
                                  titleStyle: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                );
                              }).toList(),
                            ),
                          );
                        },
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
                      child: ListView.separated(
                        // Gunakan separated biar lebih rapi
                        padding: const EdgeInsets.all(16),
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemCount: data.length,
                        itemBuilder: (context, index) {
                          final item = data[index];
                          final double percentageValue =
                              (item['total'] as double) /
                              totalSum; // Hitung persentase (0.0 - 1.0)

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Baris atas: Nama Kategori dan Jumlah Uang
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: Color(item['color']),
                                        radius: 6,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        item['category'],
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(currencyFormat.format(item['total'])),
                                ],
                              ),
                              const SizedBox(height: 6),
                              // Progress Bar Animasi
                              LayoutBuilder(
                                // Butuh LayoutBuilder untuk tahu lebar maksimal
                                builder: (context, constraints) {
                                  return Stack(
                                    children: [
                                      // Background bar (abu-abu tipis)
                                      Container(
                                        height: 6,
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.surfaceContainerHighest,
                                          borderRadius: BorderRadius.circular(
                                            3,
                                          ),
                                        ),
                                      ),
                                      // Foreground bar (berwarna & animasi)
                                      Container(
                                            height: 6,
                                            width:
                                                constraints.maxWidth *
                                                percentageValue, // Lebar sesuai persentase
                                            decoration: BoxDecoration(
                                              color: Color(item['color']),
                                              borderRadius:
                                                  BorderRadius.circular(3),
                                            ),
                                          )
                                          .animate(
                                            delay: (100 * index).ms,
                                          ) // Delay berurutan tiap item
                                          .custom(
                                            // Animasi custom untuk lebar dari 0 ke target
                                            duration: 1000.ms,
                                            curve: Curves.easeOutExpo,
                                            builder: (context, value, child) {
                                              // value berjalan dari 0.0 ke 1.0
                                              return Container(
                                                height: 6,
                                                // Lebar tumbuh dari 0 sampai target
                                                width:
                                                    constraints.maxWidth *
                                                    percentageValue *
                                                    value,
                                                decoration: BoxDecoration(
                                                  color: Color(item['color']),
                                                  borderRadius:
                                                      BorderRadius.circular(3),
                                                ),
                                              );
                                            },
                                          ),
                                    ],
                                  );
                                },
                              ),
                            ],
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
