import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:loading_indicator/loading_indicator.dart'; // Paket yang sudah diperbaiki
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    // Tunggu minimal 2 detik agar animasi splash terlihat
    await Future.delayed(const Duration(milliseconds: 2500));

    // Cek apakah ini pertama kali buka aplikasi
    final prefs = await SharedPreferences.getInstance();

    final isFirstTime =
        prefs.getBool('isFirstTime') ??
        true; // Default true jika belum pernah diset

    if (mounted) {
      if (isFirstTime) {
        context.go('/onboarding');
      } else {
        context.go('/welcome');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/app_icons/Logo.png', width: 120, height: 120)
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
