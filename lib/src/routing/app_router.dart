import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import '../common_widgets/scaffold_with_navbar.dart';
import '../features/auth/presentation/custom_splash_screen.dart';
import '../features/dashboard/presentation/home_screen.dart';
import '../features/reports/presentation/reports_screen.dart';
import '../features/transactions/presentation/add_category_screen.dart';
import '../features/transactions/presentation/add_transaction_screen.dart';
import '../features/transactions/presentation/manage_categories_screen.dart';
import '../services/local_db/drift_db.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorAKey = GlobalKey<NavigatorState>(debugLabel: 'shellA');
final _shellNavigatorBKey = GlobalKey<NavigatorState>(debugLabel: 'shellB');

final goRouter = GoRouter(
  initialLocation: '/',
  navigatorKey: _rootNavigatorKey,
  routes: [
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/splash',
      builder: (context, state) => const CustomSplashScreen(),
    ),
    
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          ScaffoldWithNavBar(navigationShell: navigationShell),
      branches: [
        // Branch Dashboard
        StatefulShellBranch(
          navigatorKey: _shellNavigatorAKey,
          routes: [
            GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
          ],
        ),
        // Branch Laporan
        StatefulShellBranch(
          navigatorKey: _shellNavigatorBKey,
          routes: [
            GoRoute(
              path: '/reports',
              builder: (context, state) => const ReportsScreen(),
            ),
          ],
        ),
      ],
    ),
    // Rute /add-transaction cukup SATU saja yang ini:
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/add-transaction',
      builder: (context, state) {
        // Ambil objek transaksi yang dikirim (jika ada)
        final transactionToEdit = state.extra as Transaction?;
        return AddTransactionScreen(transactionToEdit: transactionToEdit);
      },
    ),

    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/add-category',
      builder: (context, state) => const AddCategoryScreen(),
    ),

    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/manage-categories',
      builder: (context, state) => const ManageCategoriesScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/edit-category', // Rute baru untuk edit
      builder: (context, state) {
        final categoryToEdit = state.extra as Category;
        // Pastikan AddCategoryScreen sudah dimodifikasi untuk menerima parameter ini
        return AddCategoryScreen(categoryToEdit: categoryToEdit);
      },
    ),
  ],
);
