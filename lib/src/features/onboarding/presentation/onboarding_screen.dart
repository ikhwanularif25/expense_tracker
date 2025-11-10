import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  Future<void> _onIntroEnd(BuildContext context) async {
    // Simpan status bahwa user sudah melihat onboarding
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isFirstTime', false);

    if (context.mounted) {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Gaya dasar untuk halaman onboarding
    const pageDecoration = PageDecoration(
      titleTextStyle: TextStyle(fontSize: 28.0, fontWeight: FontWeight.w700),
      bodyTextStyle: TextStyle(fontSize: 16.0),
      bodyPadding: EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 16.0),
      pageColor: Colors.transparent, // Ikuti warna tema scaffold
      imagePadding: EdgeInsets.zero,
    );

    return IntroductionScreen(
      globalBackgroundColor: Theme.of(context).scaffoldBackgroundColor,
      allowImplicitScrolling: true,
      autoScrollDuration: 300000, // Opsional: auto-scroll jika didiamkan lama
      pages: [
        // HALAMAN 1: Pencatatan
        PageViewModel(
          title: "Catat Tiap Transaksi",
          body:
              "Jangan biarkan pengeluaran kecil terlewat. Catat pemasukan dan pengeluaranmu dengan mudah dan cepat.",
          image: _buildImage(
            'assets/icons/food.svg',
            context,
          ), // Ganti dengan ilustrasi yang lebih relevan nanti
          decoration: pageDecoration,
        ),
        // HALAMAN 2: Kategori
        PageViewModel(
          title: "Atur Kategori",
          body:
              "Buat kategori kustommu sendiri agar laporan keuangan lebih terperinci dan sesuai gaya hidupmu.",
          image: _buildImage('assets/icons/transport.svg', context),
          decoration: pageDecoration,
        ),
        // HALAMAN 3: Laporan & Analisis
        PageViewModel(
          title: "Analisis Keuangan",
          body:
              "Pahami kebiasaan belanjamu lewat grafik interaktif dan laporan bulanan yang mudah dibaca.",
          image: _buildImage('assets/icons/salary.svg', context),
          decoration: pageDecoration,
        ),
      ],
      onDone: () => _onIntroEnd(context),
      onSkip: () =>
          _onIntroEnd(context), 
      showSkipButton: true,
      skipOrBackFlex: 0,
      nextFlex: 0,
      showBackButton: false,
      back: const Icon(Icons.arrow_back),
      skip: const Text('Lewati', style: TextStyle(fontWeight: FontWeight.w600)),
      next: const Icon(Icons.arrow_forward),
      done: const Text('Mulai', style: TextStyle(fontWeight: FontWeight.w600)),
      curve: Curves.fastLinearToSlowEaseIn,
      controlsMargin: const EdgeInsets.all(16),
      controlsPadding: const EdgeInsets.fromLTRB(8.0, 4.0, 8.0, 4.0),
      dotsDecorator: DotsDecorator(
        size: const Size(10.0, 10.0),
        color: Theme.of(context).disabledColor,
        activeSize: const Size(22.0, 10.0),
        activeShape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(25.0)),
        ),
        activeColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  // Helper sementara untuk menampilkan ikon SVG sebagai ilustrasi
  // Nanti ganti dengan ilustrasi onboarding sungguhan yang lebih besar/bagus
  Widget _buildImage(String assetName, BuildContext context) {
    // Jika kamu sudah punya package flutter_svg dan asetnya
    // return SvgPicture.asset(assetName, width: 250);
    // Untuk sementara pakai Icon besar jika belum ada ilustrasi khusus:
    return Icon(
      Icons.savings_rounded,
      size: 150,
      color: Theme.of(context).colorScheme.primary,
    );
  }
}
