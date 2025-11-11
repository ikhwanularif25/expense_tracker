import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/auth_service.dart';
import 'guest_mode_provider.dart';

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
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
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                "Login untuk sinkronisasi data atau coba sebagai tamu.",
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // Tombol Login Google
              ElevatedButton.icon(
                onPressed: () async {
                  // 1. Panggil service login
                  final user = await ref
                      .read(authServiceProvider)
                      .signInWithGoogle();

                  // 2. Jika login sukses, navigasi ke dashboard
                  if (user != null && context.mounted) {
                    ref.read(guestModeProvider.notifier).state =
                        false; // Matikan mode tamu
                    context.go('/'); // Navigasi ke Dashboard
                  }
                },
                icon: const Icon(Icons.g_mobiledata), // Nanti ganti
                label: const Text("Masuk dengan Google"),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
              const SizedBox(height: 12),

              // Tombol Mode Tamu
              TextButton(
                onPressed: () {
                  context.go('/'); // Navigasi sementara ke Dashboard
                },
                child: const Text("Lanjutkan sebagai Tamu"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
