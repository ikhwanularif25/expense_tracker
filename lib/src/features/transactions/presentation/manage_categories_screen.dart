import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../services/local_db/drift_db.dart';
import '../data/transaction_repository.dart';

// Kita butuh provider stream kategori agar list otomatis update
final categoryListStreamProvider = StreamProvider.autoDispose<List<Category>>((
  ref,
) {
  final db = ref.watch(appDatabaseProvider);
  // Query sederhana untuk ambil semua kategori
  return (db.select(
    db.categories,
  )..orderBy([(t) => OrderingTerm(expression: t.name)])).watch();
});

class ManageCategoriesScreen extends ConsumerWidget {
  const ManageCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoryListStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Atur Kategori"),
        actions: [
          IconButton(
            onPressed: () => context.push('/add-category'),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: categoriesAsync.when(
        data: (categories) {
          if (categories.isEmpty) {
            return const Center(child: Text("Belum ada kategori kustom"));
          }
          return ListView.builder(
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Color(category.color),
                  radius: 16,
                  child: Icon(
                    category.isExpense
                        ? Icons.arrow_upward
                        : Icons.arrow_downward,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                title: Text(category.name),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      // Navigasi ke layar edit (kita pakai AddCategoryScreen dengan mode edit nanti)
                      context.push('/edit-category', extra: category);
                    } else if (value == 'delete') {
                      _confirmDelete(context, ref, category);
                    }
                  },
                  itemBuilder: (BuildContext context) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    // Jangan izinkan hapus kategori default jika mau (opsional), tapi untuk sekarang kita izinkan semua
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Hapus', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Category category) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Hapus Kategori?"),
        content: Text(
          "Menghapus kategori '${category.name}' juga akan MENGHAPUS SEMUA TRANSAKSI yang terkait dengannya. Yakin?",
        ),
        actions: [
          TextButton(onPressed: () => ctx.pop(), child: const Text("Batal")),
          TextButton(
            onPressed: () async {
              ctx.pop(); // Tutup dialog
              await ref
                  .read(transactionRepositoryProvider)
                  .deleteCategory(category.id);
              // Opsional: Tampilkan snackbar sukses
            },
            child: const Text("Hapus", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
