import 'package:drift/native.dart';
import 'package:expense_tracker/src/features/transactions/data/firebase_datasource.dart';
import 'package:expense_tracker/src/features/transactions/data/local_datasource.dart';
import 'package:expense_tracker/src/features/transactions/data/transaction_repository.dart';
import 'package:expense_tracker/src/services/local_db/drift_db.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' as drift;
import 'package:mockito/mockito.dart';

// Buat Mock (Tiruan) untuk FirebaseDataSource
class MockFirebaseDataSource extends Mock implements FirebaseDataSource {}

void main() {
  late AppDatabase db;
  late LocalDataSource localDataSource;
  late MockFirebaseDataSource mockFirebaseDataSource;
  late TransactionRepository repository;

  setUp(() {
    // Siapkan DB lokal in-memory
    db = AppDatabase.forTesting(NativeDatabase.memory());
    // Buat data source lokal asli
    localDataSource = LocalDataSource(db);
    // Buat data source firebase palsu
    mockFirebaseDataSource = MockFirebaseDataSource();

    // Inisialisasi repository untuk mode TAMU (isLoggedIn = false)
    repository = TransactionRepository(
      localDataSource,
      mockFirebaseDataSource,
      false, // Tes mode tamu
      null, // <-- TAMBAHKAN 'null' UNTUK USER ID
    );
  });

  tearDown(() async {
    await db.close();
  });

  test(
    'addTransaction should insert a transaction into the local database (guest mode)',
    () async {
      // ARRANCE
      final newTransaction = TransactionsCompanion.insert(
        amount: 50000,
        date: DateTime(2025, 1, 1),
        note: const drift.Value('Test Note'),
        categoryId: 1,
      );

      // Seed kategori di DB lokal
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

      // ACT
      await repository.addTransaction(newTransaction);

      // ASSERT
      final allTransactions = await db.select(db.transactions).get();
      expect(allTransactions.length, 1);
      expect(allTransactions.first.amount, 50000);
      expect(allTransactions.first.note, 'Test Note');
      // Pastikan Firebase TIDAK dipanggil
      verifyZeroInteractions(mockFirebaseDataSource);
    },
  );

  // ... (Tes lain untuk delete/update bisa ditambahkan dengan pola yang sama)
}
