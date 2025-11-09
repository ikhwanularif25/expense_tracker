// lib/main.dart
import 'package:expense_tracker/src/constants/app_tehem.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'src/routing/app_router.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized(); // Pastikan binding siap
  await initializeDateFormatting('id_ID', null);

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Expense Tracker Portfolio',
      theme: AppTheme.darkTheme, // Pakai tema gelap kita
      themeMode: ThemeMode.dark, // Paksa dark mode untuk MVP ini
      routerConfig: goRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
