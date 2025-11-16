import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:expense_tracker/src/features/transactions/data/firebase_datasource.dart';
import '../data/auth_service.dart';
import 'guest_mode_provider.dart';
import '../../transactions/data/transaction_repository.dart';
import '../../transactions/data/local_datasource.dart';

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  bool _isLoading = false;

  /// Dipanggil saat tombol "Masuk dengan Google" ditekan
  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);

    try {
      final (user, isNewUser) = await ref
          .read(authServiceProvider)
          .signInWithGoogle();

      // Pastikan widget masih ter-mount setelah 'await'
      if (user != null && context.mounted) {
        ref.read(guestModeProvider.notifier).state = false;
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('isGuestMode');

        final repo = ref.read(transactionRepositoryProvider);

        // --- PERBAIKAN: TUNGGU (AWAIT) SEMUA PROSES ASYNC ---
        if (isNewUser) {
          debugPrint("User baru terdeteksi, menjalankan migrasi/seed...");

          final localCategories = await ref
              .read(localDataSourceProvider)
              .getAllGuestCategories();

          if (localCategories.isNotEmpty) {
            // Tunggu migrasi selesai
            await repo.migrateGuestDataToCloud();
          } else {
            // Tunggu seeding selesai
            await repo.seedCloudWithDefaults();
          }
        } else {
          debugPrint(
            "User lama terdeteksi, mengecek integritas kategori cloud...",
          );

          final cloudCategories = await ref
              .read(firebaseDataSourceProvider)
              .watchCloudCategories()
              .first;

          if (cloudCategories.docs.isEmpty) {
            debugPrint("Kategori cloud kosong. Menanam data default...");
            // Tunggu seeding selesai
            await repo.seedCloudWithDefaults();
          }
        }
        // --- AKHIR PERBAIKAN ---

        // Navigasi HANYA setelah semua selesai
        if (context.mounted) context.go('/');
      } else {
        // Login gagal atau dibatalkan
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error di WelcomeScreen: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Dipanggil saat tombol "Lanjutkan sebagai Tamu" ditekan
  Future<void> _handleGuestSignIn() async {
    ref.read(guestModeProvider.notifier).state = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isGuestMode', true);
    if (context.mounted) {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    // (UI Build method tidak berubah)
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: _isLoading
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 24),
                    Text(
                      "Menyiapkan akun Anda...\nJangan tutup aplikasi.",
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.wallet_rounded,
                      size: 100,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      "Selamat Datang di Expense Tracker",
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Login untuk sinkronisasi data atau coba sebagai tamu.",
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 48),
                    ElevatedButton.icon(
                      onPressed: _handleGoogleSignIn,
                      icon: const Icon(Icons.g_mobiledata_outlined),
                      label: const Text("Masuk dengan Google"),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(
                          context,
                        ).colorScheme.onPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _handleGuestSignIn,
                      child: const Text("Lanjutkan sebagai Tamu"),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
