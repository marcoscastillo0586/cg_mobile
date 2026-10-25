import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/presentation/providers/auth_notifier.dart';
import '../features/auth/presentation/providers/auth_state.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/auth/presentation/screens/splash_screen.dart';
import '../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../features/expenses/presentation/screens/create_expense_screen.dart';
import '../features/expenses/presentation/screens/ticket_capture_screen.dart';
import '../features/incomes/presentation/screens/create_income_screen.dart';
import '../features/transfers/presentation/screens/create_transfer_screen.dart';
import '../features/movements/presentation/screens/movement_edit_screen.dart';
import '../features/movements/presentation/screens/movements_screen.dart';
import '../features/accounts_admin/presentation/screens/accounts_admin_screen.dart';
import '../features/categories_admin/presentation/screens/categories_admin_screen.dart';
import '../features/limits_admin/presentation/screens/limits_admin_screen.dart';
import '../features/analytics/presentation/screens/analytics_screen.dart';
import '../features/settings/presentation/screens/settings_screen.dart';
import '../features/sync/presentation/pending_operations_screen.dart';
import '../core/sync/outbox_repository.dart';
import 'app_routes.dart';
import '../features/dashboards/presentation/dashboards_admin_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: _RiverpodRouterNotifier(ref),
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final authState = ref.read(authNotifierProvider);
      final isLoggingIn = state.matchedLocation == AppRoutes.login;
      final isSplashing = state.matchedLocation == AppRoutes.splash;

      if (authState.status == AuthStatus.initial) {
        return isSplashing ? null : AppRoutes.splash;
      }

      if (!authState.isAuthenticated) {
        return isLoggingIn ? null : AppRoutes.login;
      }

      if (isLoggingIn || isSplashing) {
        return AppRoutes.dashboard;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.dashboard,
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: AppRoutes.expensesCreate,
        builder: (context, state) => CreateExpenseScreen(correction: state.extra as CorrectionSource?),
      ),
      GoRoute(
        path: AppRoutes.scanTicket,
        builder: (context, state) => const TicketCaptureScreen(),
      ),
      GoRoute(
        path: AppRoutes.incomesCreate,
        builder: (context, state) => CreateIncomeScreen(correction: state.extra as CorrectionSource?),
      ),
      GoRoute(
        path: AppRoutes.transfersCreate,
        builder: (context, state) => CreateTransferScreen(correction: state.extra as CorrectionSource?),
      ),
      GoRoute(
        path: AppRoutes.movements,
        builder: (context, state) {
          final idLugarStr = state.uri.queryParameters['id_lugar'];
          final idLugar = idLugarStr != null ? int.tryParse(idLugarStr) : null;
          final nombreLugar = state.uri.queryParameters['nombre'];
          return MovementsScreen(
            initialLugarId: idLugar,
            initialLugarNombre: nombreLugar,
          );
        },
      ),
      GoRoute(
        path: '/movements/edit/:id',
        builder: (context, state) => MovementEditScreen(
          serverId: int.parse(state.pathParameters['id']!),
          askDelete: state.uri.queryParameters['eliminar'] == '1',
        ),
      ),
      GoRoute(
        path: AppRoutes.accountsAdmin,
        builder: (context, state) => const AccountsAdminScreen(),
      ),
      GoRoute(
        path: AppRoutes.categoriesAdmin,
        builder: (context, state) => const CategoriesAdminScreen(),
      ),
      GoRoute(
        path: AppRoutes.limitsAdmin,
        builder: (context, state) => const LimitsAdminScreen(),
      ),
      GoRoute(
        path: AppRoutes.analytics,
        builder: (context, state) => const AnalyticsScreen(),
      ),
      GoRoute(
        path: AppRoutes.dashboardsAdmin,
        builder: (context, state) => const DashboardsAdminScreen(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.syncPending,
        builder: (context, state) => const PendingOperationsScreen(),
      ),
    ],
  );
});

class _RiverpodRouterNotifier extends ChangeNotifier {
  _RiverpodRouterNotifier(Ref ref) {
    ref.listen(authNotifierProvider, (_, __) {
      notifyListeners();
    });
  }
}
