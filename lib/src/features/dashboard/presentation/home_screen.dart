import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../transactions/data/transaction_repository.dart';
import 'widgets/summary_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsyncValue = ref.watch(transactionListStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Dashboard"),
        actions: [
          IconButton(
            icon: const Icon(Icons.category),
            tooltip: 'Atur Kategori',
            onPressed: () => context.push('/manage-categories'),
          ),
        ],
      ),
      body: Column(
        children: [
          const SummaryCard(),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Transaksi Terakhir",
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),

          Expanded(
            child: transactionsAsyncValue.when(
              data: (transactions) {
                if (transactions.isEmpty) {
                  return const Center(
                    child: Text(
                      "Belum ada transaksi",
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final item =
                        transactions[index]; // Ini sekarang tipe TransactionWithCategory
                    final transaction = item.transaction;
                    final category = item.category;

                    return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Color(
                              category.color,
                            ).withOpacity(0.2),
                            child: Icon(
                              category.isExpense
                                  ? Icons.arrow_upward
                                  : Icons.arrow_downward, // Ganti ikon di sini
                              color: Color(category.color),
                              size: 20,
                            ),
                            // Nanti bisa diganti SvgPicture kalau sudah siap
                          ),
                          title: Text(
                            category.name, // Tampilkan Nama Kategori di sini
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Tampilkan catatan jika ada
                              if (transaction.note != null &&
                                  transaction.note!.isNotEmpty)
                                Text(
                                  transaction.note!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              // Tampilkan tanggal (gunakan extension helper tadi jika mau)
                              Text(
                                DateFormat(
                                  'dd MMM yyyy',
                                  'id_ID',
                                ).format(transaction.date),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Tampilkan Jumlah dengan warna sesuai jenisnya
                              Text(
                                NumberFormat.currency(
                                  locale: 'id_ID',
                                  symbol: 'Rp ',
                                  decimalDigits: 0,
                                ).format(transaction.amount),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: category.isExpense
                                      ? Colors.redAccent
                                      : Colors.green,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 20,
                                  color: Colors.grey,
                                ),
                                onPressed: () {
                                  ref
                                      .read(transactionRepositoryProvider)
                                      .deleteTransaction(transaction.id);
                                },
                              ),
                            ],
                          ),
                          onTap: () {
                            // Saat tap, kirim objek transaksi ASLI ke layar edit
                            context.push(
                              '/add-transaction',
                              extra: transaction,
                            );
                          },
                        )
                        .animate(delay: (100 * index).ms)
                        .fadeIn(duration: 500.ms)
                        .slideY(begin: 0.5, end: 0);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/add-transaction'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

extension DateHelpers on DateTime {
  bool isToday() {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }

  bool isYesterday() {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return year == yesterday.year &&
        month == yesterday.month &&
        day == yesterday.day;
  }
}
