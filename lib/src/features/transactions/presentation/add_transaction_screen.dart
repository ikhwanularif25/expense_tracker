import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' as drift;
import '../../../services/local_db/drift_db.dart';
import '../data/transaction_repository.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  final Transaction? transactionToEdit;

  const AddTransactionScreen({super.key, this.transactionToEdit});

  @override
  ConsumerState<AddTransactionScreen> createState() =>
      _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  Category? _selectedCategory;

  @override
  void initState() {
    super.initState();
    if (widget.transactionToEdit != null) {
      final trans = widget.transactionToEdit!;
      _amountController.text = trans.amount.toStringAsFixed(0);
      _noteController.text = trans.note ?? '';
      _selectedDate = trans.date;
      // Kategori akan di-set di dalam FutureBuilder
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

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
      // Hapus karakter non-digit (misal 'Rp', titik, koma) sebelum parsing
      final amountStr = _amountController.text.replaceAll(
        RegExp(r'[^0-9]'),
        '',
      );
      final amount = double.parse(amountStr);

      if (widget.transactionToEdit == null) {
        // --- MODE TAMBAH BARU ---
        final newTransaction = TransactionsCompanion(
          amount: drift.Value(amount),
          date: drift.Value(_selectedDate),
          note: drift.Value(
            _noteController.text.isEmpty ? null : _noteController.text,
          ),
          categoryId: drift.Value(_selectedCategory!.id),
        );
        await ref
            .read(transactionRepositoryProvider)
            .addTransaction(newTransaction);
      } else {
        // --- MODE EDIT ---
        final updatedTransaction = widget.transactionToEdit!.copyWith(
          amount: amount,
          date: _selectedDate,
          note: drift.Value(
            _noteController.text.isEmpty ? null : _noteController.text,
          ),
          categoryId: _selectedCategory!.id,
        );
        await ref
            .read(transactionRepositoryProvider)
            .updateTransaction(updatedTransaction);
      }

      HapticFeedback.mediumImpact();

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
  Widget build(BuildContext context) {
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
              // Input Jumlah
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Jumlah (Rp)',
                  prefixText: 'Rp ',
                  border: OutlineInputBorder(), // Tambah border agar lebih rapi
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Harap isi jumlah';
                  }
                  final amount = double.tryParse(
                    value.replaceAll(RegExp(r'[^0-9]'), ''),
                  );
                  if (amount == null || amount <= 0) {
                    return 'Jumlah harus lebih dari 0';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Input Tanggal
              ListTile(
                contentPadding: EdgeInsets.zero, // Rata kiri dengan input lain
                title: const Text("Tanggal"),
                subtitle: Text(
                  DateFormat('dd MMMM yyyy', 'id').format(_selectedDate),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: _pickDate,
              ),
              const Divider(),

              // Dropdown Kategori
              FutureBuilder<List<Category>>(
                future: ref
                    .read(transactionRepositoryProvider)
                    .getAllCategories(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    // Tampilkan placeholder saat loading agar layout tidak 'lompat'
                    return const SizedBox(
                      height: 60,
                      child: Center(child: LinearProgressIndicator()),
                    );
                  }

                  final categories = snapshot.data!;

                  // Logika inisialisasi kategori saat mode edit
                  if (_selectedCategory == null &&
                      widget.transactionToEdit != null) {
                    try {
                      _selectedCategory = categories.firstWhere(
                        (cat) => cat.id == widget.transactionToEdit!.categoryId,
                      );
                    } catch (_) {
                      // Kategori lama mungkin sudah dihapus
                    }
                  }

                  // Pastikan _selectedCategory valid di daftar baru
                  if (_selectedCategory != null &&
                      !categories.any(
                        (cat) => cat.id == _selectedCategory!.id,
                      )) {
                    _selectedCategory = null;
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      DropdownButtonFormField<Category>(
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
                                // Indikator warna kategori
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
                      // Tombol tambah kategori baru
                      TextButton.icon(
                        onPressed: () async {
                          await context.push('/add-category');
                          setState(() {}); // Refresh daftar kategori
                        },
                        icon: const Icon(Icons.add_circle_outline, size: 18),
                        label: const Text("Kategori Baru"),
                        style: TextButton.styleFrom(
                          visualDensity:
                              VisualDensity.compact, // Agar lebih rapat
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 8),

              // Input Catatan
              TextFormField(
                controller: _noteController,
                decoration: const InputDecoration(
                  labelText: 'Catatan (Opsional)',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 3, // Agar lebih luas untuk catatan panjang
                maxLength: 100,
              ),
              const SizedBox(height: 32),

              // Tombol Simpan
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
