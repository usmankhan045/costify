import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/providers.dart';
import '../../../router/app_router.dart';

class MainShell extends ConsumerWidget {
  final Widget child;

  const MainShell({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(bottomNavIndexProvider);
    final authState = ref.watch(authNotifierProvider);
    final projectsAsync = ref.watch(userProjectsProvider);
    
    // Check if user is labour in ALL projects (hide reports only if labour in every project)
    // If user has at least one project where they're admin/director, show reports
    final isLabourInAllProjects = projectsAsync.when(
      data: (projects) {
        if (projects.isEmpty) return false;
        final userId = authState.user?.id ?? '';
        // Check if user has at least one project where they're admin or director
        final hasAnyAdminOrDirectorProject = projects.any((p) => 
          p.isUserAdmin(userId) || p.isUserDirector(userId)
        );
        // Only hide reports if they have projects but NO admin/director projects
        // (meaning they're labour in all their projects)
        return !hasAnyAdminOrDirectorProject;
      },
      loading: () => false,
      error: (_, __) => false,
    );

    // Calculate navigation index (adjust if reports is hidden)
    final navigationDestinations = _buildDestinations(isLabourInAllProjects);
    final adjustedIndex = _adjustIndex(currentIndex, isLabourInAllProjects);

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: adjustedIndex,
          onDestinationSelected: (index) {
            final actualIndex = _getActualIndex(index, isLabourInAllProjects);
            ref.read(bottomNavIndexProvider.notifier).state = actualIndex;
            switch (actualIndex) {
              case 0:
                context.go(AppRoutes.dashboard);
                break;
              case 1:
                context.go(AppRoutes.projects);
                break;
              case 2:
                context.go(AppRoutes.expenses);
                break;
              case 3:
                if (!isLabourInAllProjects) {
                  context.go(AppRoutes.reports);
                }
                break;
              case 4:
                context.go(AppRoutes.settings);
                break;
            }
          },
          destinations: navigationDestinations,
        ),
      ),
    );
  }

  List<NavigationDestination> _buildDestinations(bool hideReports) {
    final baseDestinations = [
      const NavigationDestination(
        icon: Icon(Icons.dashboard_outlined),
        selectedIcon: Icon(Icons.dashboard),
        label: 'Dashboard',
      ),
      const NavigationDestination(
        icon: Icon(Icons.folder_outlined),
        selectedIcon: Icon(Icons.folder),
        label: 'Projects',
      ),
      const NavigationDestination(
        icon: Icon(Icons.receipt_long_outlined),
        selectedIcon: Icon(Icons.receipt_long),
        label: 'Expenses',
      ),
      if (!hideReports)
        const NavigationDestination(
          icon: Icon(Icons.analytics_outlined),
          selectedIcon: Icon(Icons.analytics),
          label: 'Reports',
        ),
      const NavigationDestination(
        icon: Icon(Icons.settings_outlined),
        selectedIcon: Icon(Icons.settings),
        label: 'Settings',
      ),
    ];
    return baseDestinations;
  }

  int _adjustIndex(int index, bool hideReports) {
    if (!hideReports) return index;
    // If reports is hidden and index is 3 (reports), show settings instead
    // If index is 4 (settings), keep it as 3 (since reports is removed)
    if (index == 3) return 3; // Reports -> Settings
    if (index == 4) return 3; // Settings stays at 3
    return index;
  }

  int _getActualIndex(int displayedIndex, bool hideReports) {
    if (!hideReports) return displayedIndex;
    // Map displayed index to actual index
    // 0: Dashboard, 1: Projects, 2: Expenses, 3: Settings (reports hidden)
    if (displayedIndex == 3) return 4; // Settings
    return displayedIndex;
  }
}

