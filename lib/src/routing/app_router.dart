import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:expense_tracker/src/services/local_db/drift_db.dart'
    as drift_db;

// Import semua provider dan layar yang kita butuhkan
import '../features/auth/data/auth_service.dart';
import '../features/auth/presentation/guest_mode_provider.dart';
import '../features/auth/presentation/custom_splash_screen.dart';
import '../features/auth/presentation/welcome_screen.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../common_widgets/scaffold_with_navbar.dart';
import '../features/dashboard/presentation/home_screen.dart';
import '../features/reports/presentation/reports_screen.dart';
import '../features/transactions/presentation/add_category_screen.dart';
import '../features/transactions/presentation/add_transaction_screen.dart';
import '../features/transactions/presentation/budget_screen.dart';
import '../features/transactions/presentation/manage_categories_screen.dart';
import '../services/local_db/drift_db.dart';

// Buat provider baru untuk router
final goRouterProvider = Provider<GoRouter>((ref) {
  final _rootNavigatorKey = GlobalKey<NavigatorState>();
  final _shellNavigatorAKey = GlobalKey<NavigatorState>(debugLabel: 'shellA');
  final _shellNavigatorBKey = GlobalKey<NavigatorState>(debugLabel: 'shellB');
  final _shellNavigatorCKey = GlobalKey<NavigatorState>(debugLabel: 'shellC');

  // Dengarkan provider auth dan mode tamu
  final authState = ref.watch(authStateProvider);
  final isGuest = ref.watch(guestModeProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    debugLogDiagnostics: true, // Aktifkan untuk debug navigasi
    // Bagian 'redirect' inilah yang menjadi "Penjaga"
    redirect: (BuildContext context, GoRouterState state) {
      // Dapatkan status login
      // true = ada user login, false = null (belum login)
      final isLoggedIn = authState.value != null;
      // Dapatkan path yang sedang dituju
      final location = state.matchedLocation;

      // Daftar rute yang boleh diakses publik (sebelum login)
      final isPublicRoute =
          (location == '/splash' ||
          location == '/onboarding' ||
          location == '/welcome');

      // Jika pengguna adalah tamu atau sudah login
      final isAllowedInApp = isLoggedIn || isGuest;

      // --- LOGIKA REDIRECT ---

      // 1. Jika pengguna sudah login/tamu TAPI mencoba kembali ke rute publik
      if (isAllowedInApp && isPublicRoute) {
        return '/'; // Alihkan ke Dashboard
      }

      // 2. Jika pengguna BELUM login/tamu DAN mencoba mengakses rute privat
      if (!isAllowedInApp && !isPublicRoute) {
        return '/welcome'; // Paksa ke WelcomeScreen
      }

      // 3. Jika tidak ada kondisi di atas, izinkan (return null)
      return null;
    },

    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const CustomSplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),

      // Rute Utama Aplikasi (Dilindungi)
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            ScaffoldWithNavBar(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            navigatorKey: _shellNavigatorAKey,
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shellNavigatorBKey,
            routes: [
              GoRoute(
                path: '/reports',
                builder: (context, state) => const ReportsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shellNavigatorCKey,
            routes: [
              GoRoute(
                path: '/budgets',
                builder: (context, state) => const BudgetScreen(),
              ),
            ],
          ),
        ],
      ),

      // Rute Fullscreen (Dilindungi)
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/add-transaction',
        builder: (context, state) {
          // --- PERBAIKI LOGIKA BUILDER INI ---

          // Mode Edit (Cloud atau Lokal)
          if (state.extra != null) {
            // Mode Cloud: data dikirim sebagai Map
            if (state.extra is Map) {
              final data = state.extra as Map<String, dynamic>;
              return AddTransactionScreen(
                transactionToEdit: data['transaction'] as drift_db.Transaction?,
                firestoreDocId: data['firestoreDocId'] as String?,
              );
            }
            // Mode Tamu: data dikirim sebagai Transaction
            else if (state.extra is drift_db.Transaction) {
              return AddTransactionScreen(
                transactionToEdit: state.extra as drift_db.Transaction?,
                firestoreDocId: null, // Lokal, tidak ada ID cloud
              );
            }
          }

          // Mode Tambah Baru (extra == null)
          return const AddTransactionScreen();
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/manage-categories',
        builder: (context, state) => const ManageCategoriesScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/add-category',
        builder: (context, state) => const AddCategoryScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/edit-category',
        builder: (context, state) {
          final categoryToEdit = state.extra as Category;
          return AddCategoryScreen(categoryToEdit: categoryToEdit);
        },
      ),
    ],
  );
});
