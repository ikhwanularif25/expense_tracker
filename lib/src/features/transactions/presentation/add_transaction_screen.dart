// import 'package.expense_tracker/src/features/transactions/presentation/transaction_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
// 1. IMPORT KEMBALI 'intl' UNTUK DATEFORMAT
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' as drift;
import '../../../services/local_db/drift_db.dart' as drift_db;
import '../data/transaction_repository.dart';
import 'transaction_providers.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  final drift_db.Transaction? transactionToEdit;
  final String? firestoreDocId; // Untuk mode Cloud

  const AddTransactionScreen({
    super.key,
    this.transactionToEdit,
    this.firestoreDocId,
  });

  @override
  ConsumerState<AddTransactionScreen> createState() =>
      _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  drift_db.Category? _selectedCategory;

  @override
  void initState() {
    super.initState();
    if (widget.transactionToEdit != null) {
      final trans = widget.transactionToEdit!;
      _amountController.text = trans.amount.toStringAsFixed(0);
      _selectedDate = trans.date;

      String? actualNote;
      if (widget.firestoreDocId != null && trans.note != null) {
        final parts = trans.note!.split('::');
        if (parts.length > 1) {
          actualNote = parts[1];
        }
      } else {
        actualNote = trans.note;
      }
      _noteController.text = actualNote ?? '';
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  // 2. FUNGSI _pickDate SEKARANG DIGUNAKAN LAGI
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _saveTransaction() async {
    if (_formKey.currentState!.validate() && _selectedCategory != null) {
      final amountStr = _amountController.text.replaceAll(
        RegExp(r'[^0-9]'),
        '',
      );
      final amount = double.parse(amountStr);

      if (widget.transactionToEdit == null) {
        // --- MODE TAMBAH BARU ---
        final newTransaction = drift_db.TransactionsCompanion(
          amount: drift.Value(amount),
          date: drift.Value(_selectedDate),
          note: drift.Value(
            // drift.Value() di sini sudah benar
            _noteController.text.isEmpty ? null : _noteController.text,
          ),
          categoryId: drift.Value(_selectedCategory!.id),
        );
        await ref
            .read(transactionRepositoryProvider)
            .addTransaction(newTransaction);
      } else {
        // --- MODE EDIT ---
        // 3. PERBAIKAN: KEMBALIKAN 'drift.Value()' PADA 'note'
        final updatedTransaction = widget.transactionToEdit!.copyWith(
          amount: amount,
          date: _selectedDate,
          note: drift.Value(
            // <-- WAJIB ADA drift.Value()
            _noteController.text.isEmpty ? null : _noteController.text,
          ),
          categoryId: _selectedCategory!.id,
        );

        await ref
            .read(transactionRepositoryProvider)
            .updateTransaction(
              updatedTransaction,
              firestoreDocId: widget.firestoreDocId,
            );
      }

      if (mounted) {
        context.pop();
      }
    } else if (_selectedCategory == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Harap pilih kategori')));
    }
  }

  @override
  Widget build(BuildContext ctxt) {
    // Ganti nama 'context' agar tidak konflik
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.transactionToEdit == null
              ? "Tambah Transaksi"
              : "Edit Transaksi",
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Jumlah (Rp)',
                  prefixText: 'Rp ',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  /* ... (Validasi sama) ... */
                },
              ),
              const SizedBox(height: 16),

              // 4. PERBAIKAN: TAMBAHKAN 'onTap' DAN 'DateFormat' KEMBALI
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text("Tanggal"),
                subtitle: Text(
                  DateFormat('dd MMMM yyyy', 'id').format(_selectedDate),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: _pickDate, // <-- TAMBAHKAN INI KEMBALI
              ),
              const Divider(),

              Consumer(
                builder: (context, ref, child) {
                  final categoriesAsync = ref.watch(categoryListStreamProvider);
                  return categoriesAsync.when(
                    data: (categories) {
                      // ... (Logika Dropdown sama)
                      if (_selectedCategory == null &&
                          widget.transactionToEdit != null) {
                        try {
                          _selectedCategory = categories.firstWhere(
                            (cat) =>
                                cat.id == widget.transactionToEdit!.categoryId,
                          );
                        } catch (_) {}
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          DropdownButtonFormField<drift_db.Category>(
                            decoration: const InputDecoration(
                              labelText: 'Kategori',
                              border: OutlineInputBorder(),
                            ),
                            value: _selectedCategory,
                            items: categories.map((category) {
                              return DropdownMenuItem(
                                value: category,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: Color(category.color),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(category.name),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedCategory = value;
                              });
                            },
                            validator: (value) =>
                                value == null ? 'Harap pilih kategori' : null,
                          ),
                          TextButton.icon(
                            onPressed: () async {
                              await context.push('/add-category');
                            },
                            icon: const Icon(
                              Icons.add_circle_outline,
                              size: 18,
                            ),
                            label: const Text("Kategori Baru"),
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ],
                      );
                    },
                    loading: () => const SizedBox(
                      height: 60,
                      child: Center(child: LinearProgressIndicator()),
                    ),
                    error: (err, stack) => Text("Gagal memuat kategori: $err"),
                  );
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _noteController,
                decoration: const InputDecoration(
                  labelText: 'Catatan (Opsional)',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
                maxLength: 100,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _saveTransaction,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
                child: const Text(
                  "Simpan Transaksi",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
