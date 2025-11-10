import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'drift_db.g.dart';

// Tabel Kategori
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 50)();
  IntColumn get color => integer()();
  TextColumn get iconPath => text()();
  BoolColumn get isExpense => boolean().withDefault(const Constant(true))();
}

// Tabel Transaksi
class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  RealColumn get amount => real()();
  DateTimeColumn get date => dateTime()();
  TextColumn get note => text().nullable()();
  IntColumn get categoryId => integer().references(Categories, #id)();
}

// Tabel Anggaran (Budget) - BARU
class Budgets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get categoryId => integer().references(Categories, #id)();
  RealColumn get amount => real()();
  IntColumn get period => integer()(); // Format: YYYYMM (misal: 202511)

  @override
  List<String> get customConstraints => ['UNIQUE(category_id, period)'];
}

// Definisi Database Utama
@DriftDatabase(
  tables: [Categories, Transactions, Budgets],
) // Pastikan Budgets masuk sini
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  // Constructor untuk testing yang lebih ringkas
  AppDatabase.forTesting(super.e);

  // Versi schema dinaikkan ke 2 karena ada tabel baru
  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    // Logika saat database pertama kali dibuat (fresh install)
    onCreate: (Migrator m) async {
      await m.createAll(); // Buat semua tabel termasuk Budgets
      // Seed data kategori default
      await into(categories).insert(
        CategoriesCompanion.insert(
          name: 'Makanan',
          color: 0xFFFF5722,
          iconPath: 'assets/icons/food.svg',
          isExpense: const Value(true),
        ),
      );
      await into(categories).insert(
        CategoriesCompanion.insert(
          name: 'Transport',
          color: 0xFF03A9F4,
          iconPath: 'assets/icons/transport.svg',
          isExpense: const Value(true),
        ),
      );
      await into(categories).insert(
        CategoriesCompanion.insert(
          name: 'Gaji',
          color: 0xFF4CAF50,
          iconPath: 'assets/icons/salary.svg',
          isExpense: const Value(false),
        ),
      );
    },
    // Logika saat aplikasi di-update dari versi lama
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        // Jika versi lama < 2, buat tabel Budgets yang baru ditambahkan
        await m.createTable(budgets);
      }
    },
  );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'app_db.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
