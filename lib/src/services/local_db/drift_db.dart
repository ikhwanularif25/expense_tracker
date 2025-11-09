import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
part 'drift_db.g.dart';


class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 50)();
  IntColumn get color => integer()(); 
  TextColumn get iconPath => text()();
  BoolColumn get isExpense => boolean().withDefault(
    const Constant(true),
  )(); 
}

// Tabel Transaksi
class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  RealColumn get amount => real()();
  DateTimeColumn get date => dateTime()();
  TextColumn get note => text().nullable()();
  IntColumn get categoryId => integer().references(Categories, #id)();
}

// Definisi Database Utama
@DriftDatabase(tables: [Categories, Transactions])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll(); 
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
