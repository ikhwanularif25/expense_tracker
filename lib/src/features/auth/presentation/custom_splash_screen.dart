import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:loading_indicator/loading_indicator.dart'; // Paket yang sudah diperbaiki
import 'package:flutter_animate/flutter_animate.dart';

class CustomSplashScreen extends StatefulWidget {
  const CustomSplashScreen({super.key});

  @override
  State<CustomSplashScreen> createState() => _CustomSplashScreenState();
}

class _CustomSplashScreenState extends State<CustomSplashScreen> {
  @override
  void initState() {
    super.initState();
    _startAppInitialization();
  }

  void _startAppInitialization() async {
    // Memberi waktu total 2.5 detik untuk animasi dan inisialisasi
    await Future.delayed(const Duration(milliseconds: 2500));

    if (mounted) {
      // Navigasi ke rute utama aplikasi (Dashboard)
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Ambil warna utama dari tema untuk konsistensi
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      // Background yang konsisten dengan tema dark mode
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 1. Logo Aplikasi (diberi animasi fade in & scale up)
            Image.asset(
                  'assets/app_icon/Logo.png', // Ganti dengan path logo aslimu
                  width: 120,
                  height: 120,
                )
                .animate()
                .fadeIn(duration: 800.ms, delay: 200.ms)
                .scale(begin: const Offset(0.5, 0.5), end: const Offset(1, 1)),

            const SizedBox(height: 24),

            // 2. Nama Aplikasi
            Text(
                  'Finance Tracker',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                    letterSpacing: 1.5,
                  ),
                )
                .animate()
                .fadeIn(duration: 800.ms, delay: 500.ms)
                .slideY(begin: 0.2, end: 0),

            const SizedBox(height: 8),

            // 3. Sub Judul
            Text(
              'Smart Personal Budgeting',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade400),
            ).animate().fadeIn(duration: 800.ms, delay: 700.ms),

            const SizedBox(height: 64),

            // 4. Animasi Tiga Titik (Menggunakan BallPulse dari loading_indicator)
            SizedBox(
              height: 20,
              width: 50,
              child: LoadingIndicator(
                indicatorType:
                    Indicator.ballPulse, // Jenis animasi titik melompat
                colors: [primaryColor], // Warna titik
                strokeWidth: 2,
              ),
            ).animate().fadeIn(duration: 800.ms, delay: 1000.ms),
          ],
        ),
      ),
    );
  }
}
