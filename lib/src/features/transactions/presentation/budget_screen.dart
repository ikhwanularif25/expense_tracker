import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../auth/data/auth_service.dart';
import '../data/transaction_repository.dart';
import '../domain/budget_with_progress.dart';
import '../../../common_widgets/empty_placeholder_widget.dart';
import '../../../services/local_db/drift_db.dart';

// Provider stream untuk data budget
final budgetListStreamProvider =
    StreamProvider.autoDispose<List<BudgetWithProgress>>((ref) {
      final repository = ref.watch(transactionRepositoryProvider);
      return repository.watchBudgetsWithProgress();
    });

// Kita butuh provider kategori juga di sini untuk dialog tambah anggaran
final categoryListStreamProvider = StreamProvider.autoDispose<List<Category>>((
  ref,
) {
  final db = ref.watch(appDatabaseProvider);
  return (db.select(
    db.categories,
  )..orderBy([(t) => OrderingTerm(expression: t.name)])).watch();
});

class BudgetScreen extends ConsumerWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetsAsync = ref.watch(budgetListStreamProvider);
    final currencyFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text("Anggaran Bulanan"),
        actions: [
          IconButton(
            onPressed: () => _showSetBudgetDialog(context, ref),
            icon: const Icon(Icons.add),
            tooltip: 'Tambah Anggaran',
          ),
        ],
      ),
      body: budgetsAsync.when(
        data: (budgets) {
          if (budgets.isEmpty) {
            return const EmptyPlaceholderWidget(
              message:
                  "Belum ada anggaran bulan ini.\nYuk, atur batas pengeluaranmu!",
              iconData: Icons.savings_outlined,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: budgets.length,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final item = budgets[index];
              final isOverBudget = item.spent > item.budget.amount;
              final color = isOverBudget
                  ? Colors.redAccent
                  : Theme.of(context).colorScheme.primary;

              return Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        16,
                        16,
                        4,
                        16,
                      ), // Padding kanan lebih kecil untuk menu
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header Kategori & Menu Opsi
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: Color(
                                  item.category.color,
                                ).withAlpha(50),
                                radius: 18,
                                child: Icon(
                                  Icons
                                      .category, // Ganti dengan SvgPicture jika sudah siap
                                  color: Color(item.category.color),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  item.category.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              // Sisa Anggaran
                              Text(
                                isOverBudget
                                    ? "Over!"
                                    : "Sisa: ${currencyFormat.format(item.remaining)}",
                                style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              // Menu Opsi (Titik Tiga)
                              PopupMenuButton<String>(
                                icon: const Icon(
                                  Icons.more_vert,
                                  color: Colors.grey,
                                ),
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    _showSetBudgetDialog(
                                      context,
                                      ref,
                                      budgetToEdit: item,
                                    );
                                  } else if (value == 'delete') {
                                    _confirmDeleteBudget(context, ref, item);
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Edit'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Text(
                                      'Hapus',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Progress Bar
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: TweenAnimationBuilder<double>(
                              tween: Tween<double>(
                                begin: 0,
                                end: item.progress,
                              ), // Animasi dari 0 ke nilai progress
                              duration: const Duration(
                                milliseconds: 1000,
                              ), // Durasi animasi 1 detik
                              curve: Curves
                                  .easeOutCubic, // Kurva animasi yang halus
                              builder: (context, value, child) {
                                return LinearProgressIndicator(
                                  value: value, // Gunakan nilai animasi di sini
                                  minHeight: 8,
                                  backgroundColor: Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                                  color: color,
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Detail Angka (Terpakai / Total)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                currencyFormat.format(item.spent),
                                style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                currencyFormat.format(item.budget.amount),
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  )
                  .animate()
                  .fadeIn(
                    delay: (100 * index)
                        .ms, // Delay berdasarkan indeks agar muncul berurutan
                    duration: 300.ms,
                  )
                  .slideY(
                    delay: (100 * index).ms,
                    duration: 300.ms,
                    begin: 0.1, // Mulai sedikit di bawah
                    end: 0, // Berakhir di posisi normal
                  );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  void _showSetBudgetDialog(
    BuildContext context,
    WidgetRef ref, {
    BudgetWithProgress? budgetToEdit,
  }) {
    showDialog(
      context: context,
      builder: (context) => SetBudgetDialog(budgetToEdit: budgetToEdit),
    );
  }

  void _confirmDeleteBudget(
    BuildContext context,
    WidgetRef ref,
    BudgetWithProgress item,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Hapus Anggaran?"),
        content: Text(
          "Anggaran untuk kategori '${item.category.name}' akan dihapus.",
        ),
        actions: [
          TextButton(onPressed: () => ctx.pop(), child: const Text("Batal")),
          TextButton(
            onPressed: () async {
              ctx.pop();

              // --- PERBAIKAN LOGIKA DELETE HIBRIDA ---
              // Cek mode saat ini
              final isCloudMode = ref.read(authStateProvider).value != null;

              if (isCloudMode) {
                // Mode Cloud: Kirim ID Kategori dan Periode
                await ref
                    .read(transactionRepositoryProvider)
                    .deleteBudget(item.category.id, item.budget.period);
              } else {
                // Mode Tamu: Kirim ID Budget (dari data lokal)
                await ref
                    .read(transactionRepositoryProvider)
                    .deleteBudget(
                      item.budget.id, // ID unik dari tabel Budgets lokal
                      0, // Period tidak dipakai di mode lokal, kirim 0
                    );
              }
            },
            child: const Text("Hapus", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
// --- Widget Dialog Tambah/Edit Anggaran ---
class SetBudgetDialog extends ConsumerStatefulWidget {
  final BudgetWithProgress? budgetToEdit;

  const SetBudgetDialog({super.key, this.budgetToEdit});

  @override
  ConsumerState<SetBudgetDialog> createState() => _SetBudgetDialogState();
}

class _SetBudgetDialogState extends ConsumerState<SetBudgetDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  Category? _selectedCategory;

  @override
  void initState() {
    super.initState();
    if (widget.budgetToEdit != null) {
      _amountController.text = widget.budgetToEdit!.budget.amount
          .toStringAsFixed(0);
      // Kategori akan di-set setelah data termuat di FutureBuilder/StreamBuilder
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoryListStreamProvider);

    return AlertDialog(
      title: Text(
        widget.budgetToEdit == null ? "Atur Anggaran Baru" : "Edit Anggaran",
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              categoriesAsync.when(
                data: (categories) {
                  final expenseCategories = categories
                      .where((c) => c.isExpense)
                      .toList();

                  // Logika pre-select saat edit
                  if (_selectedCategory == null &&
                      widget.budgetToEdit != null) {
                    try {
                      _selectedCategory = expenseCategories.firstWhere(
                        (c) => c.id == widget.budgetToEdit!.category.id,
                      );
                    } catch (_) {}
                  }

                  return DropdownButtonFormField<Category>(
                    decoration: const InputDecoration(
                      labelText: 'Kategori Pengeluaran',
                    ),
                    initialValue: _selectedCategory,
                    // Disable dropdown jika sedang mode EDIT
                    onChanged: widget.budgetToEdit == null
                        ? (value) => setState(() => _selectedCategory = value)
                        : null,
                    disabledHint: _selectedCategory != null
                        ? Text(_selectedCategory!.name)
                        : null,
                    items: expenseCategories.map((category) {
                      return DropdownMenuItem(
                        value: category,
                        child: Text(category.name),
                      );
                    }).toList(),
                    validator: (value) =>
                        value == null ? 'Harap pilih kategori' : null,
                  );
                },
                loading: () => const SizedBox(
                  height: 60,
                  child: Center(child: LinearProgressIndicator()),
                ),
                error: (_, __) => const Text("Gagal memuat kategori"),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Batas Anggaran (Rp)',
                  prefixText: 'Rp ',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Harap isi jumlah';
                  final amount = double.tryParse(
                    value.replaceAll(RegExp(r'[^0-9]'), ''),
                  );
                  if (amount == null || amount <= 0) {
                    return 'Jumlah harus lebih dari 0';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Batal"),
        ),
        ElevatedButton(onPressed: _saveBudget, child: const Text("Simpan")),
      ],
    );
  }

  void _saveBudget() async {
    if (_formKey.currentState!.validate() && _selectedCategory != null) {
      final amount = double.parse(
        _amountController.text.replaceAll(RegExp(r'[^0-9]'), ''),
      );

      // Fungsi setBudget di repo menggunakan insertOnConflictUpdate,
      // jadi aman untuk dipakai baik saat tambah baru maupun edit (jika ID kategori & periode sama).
      await ref
          .read(transactionRepositoryProvider)
          .setBudget(_selectedCategory!.id, amount);

      if (mounted) Navigator.pop(context);
    }
  }
}
