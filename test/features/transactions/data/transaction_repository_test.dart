import 'package:drift/native.dart';
import 'package:expense_tracker/src/features/transactions/data/transaction_repository.dart';
import 'package:expense_tracker/src/services/local_db/drift_db.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' as drift;

void main() {
  late AppDatabase db;
  late TransactionRepository repository;

  // Setup yang dijalankan SEBELUM setiap test
  setUp(() {
    // Gunakan in-memory database agar cepat & bersih tiap kali test jalan
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = TransactionRepository(db);
  });

  // Bersih-bersih SETELAH setiap test
  tearDown(() async {
    await db.close();
  });

  test(
    'addTransaction should insert a transaction into the database',
    () async {
      // ARRANCE (Siapkan data)
      final newTransaction = TransactionsCompanion.insert(
        amount: 50000,
        date: DateTime(2025, 1, 1),
        note: const drift.Value('Test Note'),
        categoryId: 1, // Asumsikan kategori ID 1 ada (nanti kita seed)
      );

      // Karena foreign key, kita perlu kategori dulu di DB in-memory
      await db
          .into(db.categories)
          .insert(
            CategoriesCompanion.insert(
              name: 'Test Cat',
              color: 0xFFFFFFFF,
              iconPath: 'assets/test.svg',
              isExpense: const drift.Value(true),
            ),
          );

      // ACT (Jalankan fungsi yang mau dites)
      await repository.addTransaction(newTransaction);

      // ASSERT (Periksa hasilnya)
      final allTransactions = await db.select(db.transactions).get();
      expect(allTransactions.length, 1); // Harusnya ada 1 transaksi
      expect(allTransactions.first.amount, 50000); // Jumlahnya harus sama
      expect(allTransactions.first.note, 'Test Note'); // Catatannya harus sama
    },
  );

  test('deleteTransaction should remove transaction from database', () async {
    // ARRANGE: Siapkan data awal (insert 1 kategori & 1 transaksi)
    await db
        .into(db.categories)
        .insert(
          CategoriesCompanion.insert(
            name: 'Cat 1',
            color: 0xFF000000,
            iconPath: 'icon.svg',
            isExpense: const drift.Value(true),
          ),
        );
    await repository.addTransaction(
      TransactionsCompanion.insert(
        amount: 10000,
        date: DateTime.now(),
        categoryId: 1,
      ),
    );

    // Pastikan data masuk dulu
    expect((await db.select(db.transactions).get()).length, 1);

    // ACT: Jalankan fungsi hapus (asumsi ID transaksi yang baru masuk adalah 1)
    await repository.deleteTransaction(1);

    // ASSERT: Cek apakah data sudah hilang
    expect((await db.select(db.transactions).get()).length, 0);
  });

  test('updateTransaction should modify existing transaction', () async {
    // ARRANGE: Siapkan data awal
    await db
        .into(db.categories)
        .insert(
          CategoriesCompanion.insert(
            name: 'Cat 1',
            color: 0xFF000000,
            iconPath: 'icon.svg',
            isExpense: const drift.Value(true),
          ),
        );
    // Insert dan ambil ID-nya (biar pasti)
    final initialId = await repository
        .addTransaction(
          TransactionsCompanion.insert(
            amount: 50000, // Nilai awal
            date: DateTime(2025, 1, 1),
            categoryId: 1,
          ),
        )
        .then((_) => 1); // Asumsi ID 1 krn autoIncrement di DB kosong

    // Ambil data transaksi yang baru disimpan untuk mendapatkan objek lengkapnya
    final originalTransaction = await (db.select(
      db.transactions,
    )..where((t) => t.id.equals(initialId))).getSingle();

    // ACT: Update nilai amount
    final updatedData = originalTransaction.copyWith(amount: 100000);
    await repository.updateTransaction(updatedData);

    // ASSERT: Cek apakah datanya berubah di DB
    final transactionFromDb = await (db.select(
      db.transactions,
    )..where((t) => t.id.equals(initialId))).getSingle();
    expect(
      transactionFromDb.amount,
      100000,
    ); // Amount harusnya berubah jadi 100.000
  });
}
