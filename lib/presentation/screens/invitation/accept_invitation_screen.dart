import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/invitation_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/providers.dart';
import '../../../router/app_router.dart';
import '../../widgets/custom_button.dart';

class AcceptInvitationScreen extends ConsumerStatefulWidget {
  final String invitationId;

  const AcceptInvitationScreen({
    super.key,
    required this.invitationId,
  });

  @override
  ConsumerState<AcceptInvitationScreen> createState() =>
      _AcceptInvitationScreenState();
}

class _AcceptInvitationScreenState
    extends ConsumerState<AcceptInvitationScreen> {
  bool _isLoading = true;
  bool _isAccepting = false;
  InvitationModel? _invitation;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadInvitation();
  }

  Future<void> _loadInvitation() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final projectRepo = ref.read(projectRepositoryProvider);
      final invitation = await projectRepo.getInvitationById(widget.invitationId);

      if (invitation == null) {
        setState(() {
          _errorMessage = 'Invitation not found';
          _isLoading = false;
        });
        return;
      }

      if (!invitation.isValid) {
        setState(() {
          _errorMessage = invitation.isExpired
              ? 'This invitation has expired'
              : 'This invitation is no longer valid';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _invitation = invitation;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load invitation: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _acceptInvitation() async {
    final authState = ref.read(authNotifierProvider);
    
    if (!authState.isAuthenticated) {
      // User needs to login first
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login or create an account first'),
          backgroundColor: AppColors.warning,
        ),
      );
      // Store the invitation ID to process after login
      context.go('${AppRoutes.login}?redirect=/invite/${widget.invitationId}');
      return;
    }

    setState(() => _isAccepting = true);

    try {
      final projectRepo = ref.read(projectRepositoryProvider);
      await projectRepo.acceptInvitation(
        invitationId: widget.invitationId,
        userId: authState.user!.id,
        userName: authState.user!.name,
        userEmail: authState.user!.email,
        userPhotoUrl: authState.user!.photoUrl,
      );

      // Refresh projects list
      ref.invalidate(userProjectsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Welcome to ${_invitation!.projectName}!'),
            backgroundColor: AppColors.success,
          ),
        );
        // Navigate to the project
        context.go('${AppRoutes.projects}/${_invitation!.projectId}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().contains('already')
              ? e.toString()
              : 'Failed to accept invitation: ${e.toString()}';
          _isAccepting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Project Invitation'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go(AppRoutes.dashboard),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorState(context)
              : _buildInvitationDetails(context, authState),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(25),
              ),
              child: const Icon(
                Icons.error_outline,
                size: 48,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: AppTheme.spaceLg),
            Text(
              'Invalid Invitation',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spaceSm),
            Text(
              _errorMessage!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spaceLg),
            PrimaryButton(
              text: 'Go to Dashboard',
              width: 200,
              onPressed: () => context.go(AppRoutes.dashboard),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvitationDetails(BuildContext context, AuthState authState) {
    final theme = Theme.of(context);
    final invitation = _invitation!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      child: Column(
        children: [
          const SizedBox(height: AppTheme.spaceLg),
          // Header
          Center(
            child: Column(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: AppColors.secondaryGradient,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: const Icon(
                    Icons.mail_outline,
                    size: 48,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: AppTheme.spaceMd),
                Text(
                  'You\'ve Been Invited!',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppTheme.spaceXs),
                Text(
                  '${invitation.invitedByName} has invited you to join:',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spaceXl),
          // Project card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppTheme.spaceLg),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(AppTheme.radiusXl),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.construction,
                  size: 48,
                  color: Colors.white,
                ),
                const SizedBox(height: AppTheme.spaceMd),
                Text(
                  invitation.projectName,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spaceLg),
          // Role info
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppTheme.spaceMd),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(
                color: AppColors.info.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppTheme.spaceSm),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                  child: Icon(
                    invitation.memberRole == ProjectMemberRoles.director
                        ? Icons.admin_panel_settings
                        : Icons.person_outline,
                    color: AppColors.info,
                  ),
                ),
                const SizedBox(width: AppTheme.spaceMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Role: ${ProjectMemberRoles.labels[invitation.memberRole] ?? invitation.memberRole}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: AppColors.info,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        ProjectMemberRoles.descriptions[invitation.memberRole] ??
                            '',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.info,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spaceXl),
          // Accept button
          if (!authState.isAuthenticated) ...[
            Text(
              'Please login or create an account to accept this invitation',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spaceMd),
            Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                    text: 'Sign Up',
                    onPressed: () => context.go(
                      '${AppRoutes.register}?redirect=/invite/${widget.invitationId}',
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.spaceMd),
                Expanded(
                  child: PrimaryButton(
                    text: 'Login',
                    onPressed: () => context.go(
                      '${AppRoutes.login}?redirect=/invite/${widget.invitationId}',
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            PrimaryButton(
              text: 'Accept Invitation',
              onPressed: _acceptInvitation,
              isLoading: _isAccepting,
            ),
            const SizedBox(height: AppTheme.spaceMd),
            SecondaryButton(
              text: 'Decline',
              onPressed: () => context.go(AppRoutes.dashboard),
            ),
          ],
          const SizedBox(height: AppTheme.spaceLg),
        ],
      ),
    );
  }
}
