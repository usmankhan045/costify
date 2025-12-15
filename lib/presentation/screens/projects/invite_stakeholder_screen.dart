import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/providers.dart';
import '../../widgets/custom_button.dart';

class InviteStakeholderScreen extends ConsumerStatefulWidget {
  final String projectId;

  const InviteStakeholderScreen({
    super.key,
    required this.projectId,
  });

  @override
  ConsumerState<InviteStakeholderScreen> createState() =>
      _InviteStakeholderScreenState();
}

class _InviteStakeholderScreenState
    extends ConsumerState<InviteStakeholderScreen> {
  String? _inviteLink;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _generateInviteLink();
  }

  Future<void> _generateInviteLink() async {
    setState(() => _isLoading = true);

    try {
      final authState = ref.read(authNotifierProvider);
      final projectRepo = ref.read(projectRepositoryProvider);
      final projectAsync = ref.read(projectProvider(widget.projectId));

      final project = projectAsync.value;
      if (project == null) return;

      final invitation = await projectRepo.createInvitation(
        projectId: widget.projectId,
        projectName: project.name,
        invitedBy: authState.user!.id,
        invitedByName: authState.user!.name,
      );

      setState(() {
        _inviteLink = invitation.shareableLink;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate invite link: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _copyLink() {
    if (_inviteLink == null) return;

    Clipboard.setData(ClipboardData(text: _inviteLink!));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Invite link copied to clipboard!'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _shareLink() {
    if (_inviteLink == null) return;

    Share.share(
      'You\'ve been invited to join a construction project on Costify! Click the link to join: $_inviteLink',
      subject: 'Costify Project Invitation',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final projectAsync = ref.watch(projectProvider(widget.projectId));

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.inviteStakeholder),
      ),
      body: projectAsync.when(
        data: (project) {
          if (project == null) {
            return const Center(child: Text('Project not found'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.spaceMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                          Icons.person_add,
                          size: 48,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spaceMd),
                      Text(
                        'Invite to ${project.name}',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppTheme.spaceXs),
                      Text(
                        'Share this link with stakeholders to invite them to your project.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.spaceXl),
                // Invite link card
                Container(
                  padding: const EdgeInsets.all(AppTheme.spaceMd),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.shareLink,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spaceSm),
                      if (_isLoading)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(AppTheme.spaceMd),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else if (_inviteLink != null)
                        Container(
                          padding: const EdgeInsets.all(AppTheme.spaceMd),
                          decoration: BoxDecoration(
                            color: theme.scaffoldBackgroundColor,
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMd),
                            border: Border.all(
                              color: theme.colorScheme.outline.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _inviteLink!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.primary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy),
                                onPressed: _copyLink,
                                tooltip: 'Copy link',
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: AppTheme.spaceMd),
                      Row(
                        children: [
                          Expanded(
                            child: SecondaryButton(
                              text: 'Copy Link',
                              icon: Icons.copy,
                              onPressed: _inviteLink != null ? _copyLink : null,
                            ),
                          ),
                          const SizedBox(width: AppTheme.spaceMd),
                          Expanded(
                            child: PrimaryButton(
                              text: 'Share',
                              icon: Icons.share,
                              onPressed: _inviteLink != null ? _shareLink : null,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.spaceLg),
                // Info card
                Container(
                  padding: const EdgeInsets.all(AppTheme.spaceMd),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(
                      color: AppColors.info.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: AppColors.info,
                            size: 20,
                          ),
                          const SizedBox(width: AppTheme.spaceSm),
                          Text(
                            'How it works',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: AppColors.info,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTheme.spaceSm),
                      _buildInfoItem(
                        context,
                        '1. Share the invite link with your stakeholder',
                      ),
                      _buildInfoItem(
                        context,
                        '2. They must have a Costify account to join',
                      ),
                      _buildInfoItem(
                        context,
                        '3. The link expires in 7 days',
                      ),
                      _buildInfoItem(
                        context,
                        '4. They can add expenses once they join',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.spaceLg),
                // Current members
                Text(
                  'Current Team Members',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppTheme.spaceSm),
                _buildMemberCard(
                  context,
                  name: project.adminName,
                  role: 'Admin',
                  isAdmin: true,
                ),
                ...project.members.map(
                  (member) => _buildMemberCard(
                    context,
                    name: member.name,
                    role: 'Stakeholder',
                    joinedAt: member.joinedAt,
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Failed to load project')),
      ),
    );
  }

  Widget _buildInfoItem(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spaceXs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  ', style: TextStyle(color: AppColors.info)),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.info,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberCard(
    BuildContext context, {
    required String name,
    required String role,
    bool isAdmin = false,
    DateTime? joinedAt,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceSm),
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceContainerDark : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        boxShadow: AppColors.softShadow,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: isAdmin
                ? AppColors.primaryContainer
                : theme.colorScheme.surfaceContainerHighest,
            child: Text(
              Formatters.getInitials(name),
              style: theme.textTheme.titleSmall?.copyWith(
                color: isAdmin ? AppColors.primary : null,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: AppTheme.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  joinedAt != null
                      ? 'Joined ${Formatters.getRelativeTime(joinedAt)}'
                      : role,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (isAdmin)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spaceSm,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Text(
                'ADMIN',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

