import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_svg/flutter_svg.dart'; // Pastikan sudah add flutter_svg
import '../../../services/local_db/drift_db.dart';
import '../data/transaction_repository.dart';

class AddCategoryScreen extends ConsumerStatefulWidget {
  // 1. Terima parameter opsional untuk mode edit
  final Category? categoryToEdit;

  const AddCategoryScreen({super.key, this.categoryToEdit});

  @override
  ConsumerState<AddCategoryScreen> createState() => _AddCategoryScreenState();
}

class _AddCategoryScreenState extends ConsumerState<AddCategoryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _isExpense = true;
  int _selectedColor = 0xFFFF5722;
  String _selectedIcon = 'assets/icons/food.svg';

  final List<int> _colorOptions = [
    0xFFFF5722,
    0xFF03A9F4,
    0xFF4CAF50,
    0xFFFFC107,
    0xFF9C27B0,
    0xFFE91E63,
    0xFF795548,
    0xFF607D8B,
  ];

  final List<String> _iconOptions = [
    'assets/icons/food.svg',
    'assets/icons/transport.svg',
    'assets/icons/salary.svg',
  ];

  @override
  void initState() {
    super.initState();
    // 2. Isi form jika dalam mode edit
    if (widget.categoryToEdit != null) {
      final cat = widget.categoryToEdit!;
      _nameController.text = cat.name;
      _isExpense = cat.isExpense;
      _selectedColor = cat.color;
      _selectedIcon = cat.iconPath;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _saveCategory() async {
    if (_formKey.currentState!.validate()) {
      final repo = ref.read(transactionRepositoryProvider);

      if (widget.categoryToEdit == null) {
        // --- MODE TAMBAH BARU ---
        // Kita perlu akses langsung ke DB untuk insert Companion,
        // atau buat fungsi insertCategory di repo (lebih baik).
        // Untuk konsistensi dengan kode sebelumnya, kita akses DB langsung di sini sementara:
        final database = ref.read(appDatabaseProvider);
        await database
            .into(database.categories)
            .insert(
              CategoriesCompanion.insert(
                name: _nameController.text,
                color: _selectedColor,
                iconPath: _selectedIcon,
                isExpense: drift.Value(_isExpense),
              ),
            );
      } else {
        // --- MODE EDIT ---
        final updatedCategory = widget.categoryToEdit!.copyWith(
          name: _nameController.text,
          color: _selectedColor,
          iconPath: _selectedIcon,
          isExpense: _isExpense,
        );
        // Panggil fungsi update di repo
        await repo.updateCategory(updatedCategory);
      }

      if (mounted) {
        context.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.categoryToEdit != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? "Edit Kategori" : "Tambah Kategori Baru"),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nama Kategori',
                border: OutlineInputBorder(),
              ),
              validator: (value) => value == null || value.isEmpty
                  ? 'Harap isi nama kategori'
                  : null,
            ),
            const SizedBox(height: 16),

            SwitchListTile(
              title: Text(_isExpense ? 'Pengeluaran' : 'Pemasukan'),
              value: _isExpense,
              onChanged: (val) => setState(() => _isExpense = val),
              secondary: Icon(
                _isExpense ? Icons.arrow_upward : Icons.arrow_downward,
                color: _isExpense ? Colors.redAccent : Colors.green,
              ),
            ),
            const Divider(),

            const Text(
              "Pilih Warna",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _colorOptions.map((color) {
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = color),
                  child: CircleAvatar(
                    backgroundColor: Color(color),
                    radius: 18,
                    child: _selectedColor == color
                        ? const Icon(Icons.check, color: Colors.white, size: 20)
                        : null,
                  ),
                );
              }).toList(),
            ),
            const Divider(height: 32),

            const Text(
              "Pilih Ikon",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _iconOptions.map((iconPath) {
                final isSelected = _selectedIcon == iconPath;
                return GestureDetector(
                  onTap: () => setState(() => _selectedIcon = iconPath),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primaryContainer
                          : null,
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey.shade700,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SvgPicture.asset(
                      iconPath,
                      width: 24,
                      height: 24,
                      colorFilter: ColorFilter.mode(
                        isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 40),

            ElevatedButton(
              onPressed: _saveCategory,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
              child: Text(isEditing ? "Update Kategori" : "Simpan Kategori"),
            ),
          ],
        ),
      ),
    );
  }
}
