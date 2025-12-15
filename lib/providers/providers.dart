import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/connectivity_service.dart';
import '../core/services/storage_service.dart';
import '../data/models/user_model.dart';
import '../data/models/project_model.dart';
import '../data/models/expense_model.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/project_repository.dart';
import '../data/repositories/expense_repository.dart';

// ============ Core Services ============

/// Storage service provider
final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService.instance;
});

/// Connectivity service provider
final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService.instance;
});

/// Connection status stream provider
final connectionStatusProvider = StreamProvider<bool>((ref) {
  return ref.watch(connectivityServiceProvider).connectionStream;
});

// ============ Firebase Providers ============

/// Firebase Auth provider
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

/// Firestore provider
final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

// ============ Repository Providers ============

/// Auth repository provider
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    auth: ref.watch(firebaseAuthProvider),
    firestore: ref.watch(firestoreProvider),
  );
});

/// Project repository provider
final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  return ProjectRepository(
    firestore: ref.watch(firestoreProvider),
  );
});

/// Expense repository provider
final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return ExpenseRepository(
    firestore: ref.watch(firestoreProvider),
  );
});

// ============ Auth State Providers ============

/// Auth state changes stream
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

/// Current user provider
final currentUserProvider = FutureProvider<UserModel?>((ref) async {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) async {
      if (user == null) return null;
      return ref.watch(authRepositoryProvider).getUserById(user.uid);
    },
    loading: () => null,
    error: (_, __) => null,
  );
});

/// Current user ID provider
final currentUserIdProvider = Provider<String?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) => user?.uid,
    loading: () => null,
    error: (_, __) => null,
  );
});

// ============ Project Providers ============

/// User projects provider
final userProjectsProvider = FutureProvider<List<ProjectModel>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];
  return ref.watch(projectRepositoryProvider).getProjectsForUser(userId);
});

/// Projects stream provider
final projectsStreamProvider = StreamProvider<List<ProjectModel>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value([]);
  return ref.watch(projectRepositoryProvider).streamProjectsForUser(userId);
});

/// Single project provider
final projectProvider = FutureProvider.family<ProjectModel?, String>((ref, projectId) async {
  return ref.watch(projectRepositoryProvider).getProjectById(projectId);
});

/// Selected project provider (for navigation)
final selectedProjectIdProvider = StateProvider<String?>((ref) => null);

/// Selected project details
final selectedProjectProvider = Provider<ProjectModel?>((ref) {
  final projectId = ref.watch(selectedProjectIdProvider);
  if (projectId == null) return null;
  
  final projectAsync = ref.watch(projectProvider(projectId));
  return projectAsync.when(
    data: (project) => project,
    loading: () => null,
    error: (_, __) => null,
  );
});

// ============ Expense Providers ============

/// Project expenses provider
final projectExpensesProvider = FutureProvider.family<List<ExpenseModel>, String>((ref, projectId) async {
  return ref.watch(expenseRepositoryProvider).getExpensesForProject(projectId);
});

/// Project expenses stream provider
final projectExpensesStreamProvider = StreamProvider.family<List<ExpenseModel>, String>((ref, projectId) {
  return ref.watch(expenseRepositoryProvider).streamExpensesForProject(projectId);
});

/// Pending expenses for project
final pendingExpensesProvider = FutureProvider.family<List<ExpenseModel>, String>((ref, projectId) async {
  return ref.watch(expenseRepositoryProvider).getPendingExpenses(projectId);
});

/// Expense summary provider
final expenseSummaryProvider = FutureProvider.family<ExpenseSummary, String>((ref, projectId) async {
  return ref.watch(expenseRepositoryProvider).getExpenseSummary(projectId);
});

/// Single expense provider
final expenseProvider = FutureProvider.family<ExpenseModel?, String>((ref, expenseId) async {
  return ref.watch(expenseRepositoryProvider).getExpenseById(expenseId);
});

// ============ UI State Providers ============

/// Theme mode provider (0 = system, 1 = light, 2 = dark)
final themeModeProvider = StateProvider<int>((ref) {
  return ref.watch(storageServiceProvider).themeMode;
});

/// Loading state provider
final loadingProvider = StateProvider<bool>((ref) => false);

/// Error message provider
final errorMessageProvider = StateProvider<String?>((ref) => null);

/// Bottom navigation index provider
final bottomNavIndexProvider = StateProvider<int>((ref) => 0);

// ============ Filter Providers ============

/// Expense status filter provider
final expenseStatusFilterProvider = StateProvider<String?>((ref) => null);

/// Expense category filter provider
final expenseCategoryFilterProvider = StateProvider<String?>((ref) => null);

/// Date range filter provider
final dateRangeFilterProvider = StateProvider<AppDateRange?>((ref) => null);

/// Custom DateRange class for filter (to avoid conflict with Flutter's DateTimeRange)
class AppDateRange {
  final DateTime start;
  final DateTime end;

  const AppDateRange({required this.start, required this.end});
}

// ============ Search Providers ============

/// Project search query provider
final projectSearchQueryProvider = StateProvider<String>((ref) => '');

/// Expense search query provider
final expenseSearchQueryProvider = StateProvider<String>((ref) => '');

/// Filtered projects provider
final filteredProjectsProvider = Provider<List<ProjectModel>>((ref) {
  final query = ref.watch(projectSearchQueryProvider).toLowerCase();
  final projectsAsync = ref.watch(userProjectsProvider);
  
  return projectsAsync.when(
    data: (projects) {
      if (query.isEmpty) return projects;
      return projects.where((project) {
        return project.name.toLowerCase().contains(query) ||
            (project.description?.toLowerCase().contains(query) ?? false);
      }).toList();
    },
    loading: () => [],
    error: (_, __) => [],
  );
});

/// Filtered expenses provider
final filteredExpensesProvider = Provider.family<List<ExpenseModel>, String>((ref, projectId) {
  final query = ref.watch(expenseSearchQueryProvider).toLowerCase();
  final statusFilter = ref.watch(expenseStatusFilterProvider);
  final categoryFilter = ref.watch(expenseCategoryFilterProvider);
  final dateRange = ref.watch(dateRangeFilterProvider);
  
  final expensesAsync = ref.watch(projectExpensesProvider(projectId));
  
  return expensesAsync.when(
    data: (expenses) {
      return expenses.where((expense) {
        // Search query filter
        if (query.isNotEmpty) {
          final matchesQuery = expense.title.toLowerCase().contains(query) ||
              (expense.description?.toLowerCase().contains(query) ?? false);
          if (!matchesQuery) return false;
        }
        
        // Status filter
        if (statusFilter != null && expense.status != statusFilter) {
          return false;
        }
        
        // Category filter
        if (categoryFilter != null && expense.category != categoryFilter) {
          return false;
        }
        
        // Date range filter
        if (dateRange != null) {
          if (expense.expenseDate.isBefore(dateRange.start) ||
              expense.expenseDate.isAfter(dateRange.end)) {
            return false;
          }
        }
        
        return true;
      }).toList();
    },
    loading: () => [],
    error: (_, __) => [],
  );
});

