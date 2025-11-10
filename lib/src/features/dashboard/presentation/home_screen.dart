import 'package:expense_tracker/src/features/settings/presentation/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../common_widgets/empty_placeholder_widget.dart';
import '../../transactions/data/transaction_repository.dart';
import '../../transactions/presentation/transaction_providers.dart';
import 'widgets/summary_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isSearchActive = false; // State lokal untuk toggle tampilan search bar
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final transactionsAsyncValue = ref.watch(transactionListStreamProvider);

    return Scaffold(
      appBar: AppBar(
        // Jika mode search aktif, tampilkan TextField di judul AppBar
        title: _isSearchActive
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Cari transaksi...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.white54),
                ),
                style: const TextStyle(color: Colors.white),
                onChanged: (value) {
                  // Update provider saat mengetik
                  ref.read(searchQueryProvider.notifier).state = value;
                },
              )
            : const Text("Dashboard"),
        actions: [
          IconButton(
            icon: Icon(_isSearchActive ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearchActive = !_isSearchActive;
                if (!_isSearchActive) {
                  // Jika menutup search, reset query
                  _searchController.clear();
                  ref.read(searchQueryProvider.notifier).state = '';
                }
              });
            },
          ),
          IconButton(
            icon: Icon(
              // Ikon berubah tergantung tema aktif
              Theme.of(context).brightness == Brightness.dark
                  ? Icons.light_mode
                  : Icons.dark_mode,
            ),
            tooltip: 'Ganti Tema',
            onPressed: () {
              // Logika toggle sederhana
              final currentMode = ref.read(themeModeProvider);
              final newMode = currentMode == ThemeMode.dark
                  ? ThemeMode.light
                  : ThemeMode.dark;
              ref.read(themeModeProvider.notifier).state = newMode;
            },
          ),
          IconButton(
            icon: const Icon(Icons.category),
            tooltip: 'Atur Kategori',
            onPressed: () => context.push('/manage-categories'),
          ),
        ],
      ),
      body: Column(
        children: [
          if (!_isSearchActive) const SummaryCard(),

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
                  return const EmptyPlaceholderWidget(
                    message:
                        "Belum ada transaksi.\nYuk, catat pengeluaranmu hari ini!",
                    iconData: Icons
                        .account_balance_wallet_outlined, // Ikon dompet kosong
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
                                  : Icons.arrow_downward, 
                              color: Color(category.color),
                              size: 20,
                            ),
                            
                          ),
                          title: Text(
                            category.name,
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
                                  HapticFeedback.heavyImpact();
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
