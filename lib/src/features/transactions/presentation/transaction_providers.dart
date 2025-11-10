import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../data/transaction_repository.dart';
import '../domain/transaction_with_category.dart';

// Provider untuk menyimpan keyword pencarian saat ini (State UI)
final searchQueryProvider = StateProvider.autoDispose<String>((ref) => '');

// Provider stream utama untuk daftar transaksi.
// Provider ini sekarang 'mendengarkan' perubahan pada searchQueryProvider.
// Setiap kali user mengetik (search query berubah), provider ini akan
// otomatis meminta data ulang ke repository dengan query baru.
final transactionListStreamProvider =
    StreamProvider.autoDispose<List<TransactionWithCategory>>((ref) {
      final repository = ref.watch(transactionRepositoryProvider);
      final query = ref.watch(searchQueryProvider);

      return repository.watchAllTransactions(query: query);
    });
