import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../presentation/screens/auth/login_screen.dart';
import '../presentation/screens/auth/register_screen.dart';
import '../presentation/screens/auth/forgot_password_screen.dart';
import '../presentation/screens/auth/verify_2fa_screen.dart';
import '../presentation/screens/dashboard/dashboard_screen.dart';
import '../presentation/screens/dashboard/main_shell.dart';
import '../presentation/screens/projects/projects_screen.dart';
import '../presentation/screens/projects/project_detail_screen.dart';
import '../presentation/screens/projects/create_project_screen.dart';
import '../presentation/screens/projects/invite_stakeholder_screen.dart';
import '../presentation/screens/expenses/expenses_screen.dart';
import '../presentation/screens/expenses/expense_detail_screen.dart';
import '../presentation/screens/expenses/add_expense_screen.dart';
import '../presentation/screens/settings/settings_screen.dart';
import '../presentation/screens/settings/profile_screen.dart';
import '../presentation/screens/settings/security_screen.dart';
import '../presentation/screens/help/help_screen.dart';
import '../presentation/common/splash_screen.dart';

/// Route paths
class AppRoutes {
  AppRoutes._();

  // Auth routes
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String verify2FA = '/verify-2fa';

  // Main routes
  static const String dashboard = '/dashboard';
  static const String projects = '/projects';
  static const String projectDetail = '/projects/:id';
  static const String createProject = '/projects/create';
  static const String inviteStakeholder = '/projects/:id/invite';
  static const String expenses = '/expenses';
  static const String expenseDetail = '/expenses/:id';
  static const String addExpense = '/projects/:projectId/expenses/add';
  static const String settings = '/settings';
  static const String profile = '/settings/profile';
  static const String security = '/settings/security';
  static const String help = '/help';
}

/// Router provider
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authNotifierProvider);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true,
    refreshListenable: _RouterRefreshStream(ref),
    redirect: (context, state) {
      final isLoggedIn = authState.isAuthenticated;
      final requires2FA = authState.requires2FA;
      final currentPath = state.matchedLocation;

      // Auth routes that don't require authentication
      final authRoutes = [
        AppRoutes.login,
        AppRoutes.register,
        AppRoutes.forgotPassword,
        AppRoutes.splash,
      ];

      // If requires 2FA verification
      if (requires2FA && currentPath != AppRoutes.verify2FA) {
        return AppRoutes.verify2FA;
      }

      // If not logged in and trying to access protected route
      if (!isLoggedIn && !authRoutes.contains(currentPath) && currentPath != AppRoutes.verify2FA) {
        return AppRoutes.login;
      }

      // If logged in and trying to access auth routes
      if (isLoggedIn && authRoutes.contains(currentPath) && currentPath != AppRoutes.splash) {
        return AppRoutes.dashboard;
      }

      return null;
    },
    routes: [
      // Splash screen
      GoRoute(
        path: AppRoutes.splash,
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),

      // Auth routes
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        name: 'forgotPassword',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.verify2FA,
        name: 'verify2FA',
        builder: (context, state) => const Verify2FAScreen(),
      ),

      // Main shell with bottom navigation
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.dashboard,
            name: 'dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: AppRoutes.projects,
            name: 'projects',
            builder: (context, state) => const ProjectsScreen(),
            routes: [
              GoRoute(
                path: 'create',
                name: 'createProject',
                builder: (context, state) => const CreateProjectScreen(),
              ),
              GoRoute(
                path: ':id',
                name: 'projectDetail',
                builder: (context, state) {
                  final projectId = state.pathParameters['id']!;
                  return ProjectDetailScreen(projectId: projectId);
                },
                routes: [
                  GoRoute(
                    path: 'invite',
                    name: 'inviteStakeholder',
                    builder: (context, state) {
                      final projectId = state.pathParameters['id']!;
                      return InviteStakeholderScreen(projectId: projectId);
                    },
                  ),
                  GoRoute(
                    path: 'expenses/add',
                    name: 'addExpense',
                    builder: (context, state) {
                      final projectId = state.pathParameters['id']!;
                      return AddExpenseScreen(projectId: projectId);
                    },
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.expenses,
            name: 'expenses',
            builder: (context, state) => const ExpensesScreen(),
            routes: [
              GoRoute(
                path: ':id',
                name: 'expenseDetail',
                builder: (context, state) {
                  final expenseId = state.pathParameters['id']!;
                  return ExpenseDetailScreen(expenseId: expenseId);
                },
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.settings,
            name: 'settings',
            builder: (context, state) => const SettingsScreen(),
            routes: [
              GoRoute(
                path: 'profile',
                name: 'profile',
                builder: (context, state) => const ProfileScreen(),
              ),
              GoRoute(
                path: 'security',
                name: 'security',
                builder: (context, state) => const SecurityScreen(),
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.help,
            name: 'help',
            builder: (context, state) => const HelpScreen(),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Page not found',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              state.error?.message ?? 'The requested page could not be found.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go(AppRoutes.dashboard),
              child: const Text('Go to Dashboard'),
            ),
          ],
        ),
      ),
    ),
  );
});

/// Helper class to refresh router on auth state changes
class _RouterRefreshStream extends ChangeNotifier {
  _RouterRefreshStream(this._ref) {
    _ref.listen(authNotifierProvider, (_, __) {
      notifyListeners();
    });
  }

  final Ref _ref;
}

