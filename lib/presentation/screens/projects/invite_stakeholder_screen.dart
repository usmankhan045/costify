import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/providers.dart';
import '../../widgets/custom_button.dart';

class InviteStakeholderScreen extends ConsumerStatefulWidget {
  final String projectId;

  const InviteStakeholderScreen({super.key, required this.projectId});

  @override
  ConsumerState<InviteStakeholderScreen> createState() =>
      _InviteStakeholderScreenState();
}

class _InviteStakeholderScreenState
    extends ConsumerState<InviteStakeholderScreen> {
  String? _inviteLink;
  bool _isLoading = false;
  String _selectedRole = ProjectMemberRoles.labour;

  Future<void> _generateInviteLink() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final authState = ref.read(authNotifierProvider);
      if (authState.user == null) {
        throw Exception('User not authenticated');
      }

      final projectRepo = ref.read(projectRepositoryProvider);
      final projectAsync = ref.read(projectProvider(widget.projectId));

      final project = projectAsync.value;
      if (project == null) {
        throw Exception('Project not found');
      }

      print('🔵 [Invite Screen] Generating invitation link...');
      print('🔵 [Invite Screen] Selected role: $_selectedRole');

      final invitation = await projectRepo.createInvitation(
        projectId: widget.projectId,
        projectName: project.name,
        invitedBy: authState.user!.id,
        invitedByName: authState.user!.name,
        memberRole: _selectedRole,
      );

      if (!mounted) return;
      setState(() {
        _inviteLink = invitation.shareableLink;
      });

      print('✅ [Invite Screen] Invitation link generated: $_inviteLink');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invitation link generated successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      print('❌ [Invite Screen] Error generating link: $e');
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

    final projectAsync = ref.read(projectProvider(widget.projectId));
    final project = projectAsync.value;
    final projectName = project?.name ?? 'a project';

    Share.share(
      'You\'ve been invited to join "$projectName" on Costify!\n\n'
      'Invitation Link: $_inviteLink\n\n'
      'To join:\n'
      '1. Open the Costify app\n'
      '2. Tap the link above (it will open the app automatically)\n'
      '3. Or manually enter the invitation ID in the app\n\n'
      'Note: Make sure you have the Costify app installed. The link will open the app directly.',
      subject: 'Costify Project Invitation - $projectName',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final projectAsync = ref.watch(projectProvider(widget.projectId));

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.inviteStakeholder)),
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
                const SizedBox(height: AppTheme.spaceLg),
                // Role selector
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
                        'Select Role',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spaceSm),
                      _buildRoleOption(
                        context,
                        role: ProjectMemberRoles.director,
                        title: ProjectMemberRoles
                            .labels[ProjectMemberRoles.director]!,
                        description: ProjectMemberRoles
                            .descriptions[ProjectMemberRoles.director]!,
                        icon: Icons.admin_panel_settings,
                      ),
                      const SizedBox(height: AppTheme.spaceSm),
                      _buildRoleOption(
                        context,
                        role: ProjectMemberRoles.labour,
                        title: ProjectMemberRoles
                            .labels[ProjectMemberRoles.labour]!,
                        description: ProjectMemberRoles
                            .descriptions[ProjectMemberRoles.labour]!,
                        icon: Icons.person_outline,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.spaceMd),
                // Generate button
                if (_inviteLink == null)
                  PrimaryButton(
                    text: 'Generate Invite Link',
                    onPressed: _isLoading ? null : _generateInviteLink,
                    isLoading: _isLoading,
                  ),
                if (_inviteLink != null) ...[
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
                        else if (_inviteLink != null) ...[
                          // Deep link
                          Container(
                            padding: const EdgeInsets.all(AppTheme.spaceMd),
                            decoration: BoxDecoration(
                              color: theme.scaffoldBackgroundColor,
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusMd,
                              ),
                              border: Border.all(
                                color: theme.colorScheme.outline.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _inviteLink!,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
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
                                const Divider(),
                                // Invitation ID
                                Row(
                                  children: [
                                    Icon(
                                      Icons.tag,
                                      size: 16,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: AppTheme.spaceSm),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Invitation ID:',
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  color: theme
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                  fontSize: 11,
                                                ),
                                          ),
                                          Text(
                                            _inviteLink!.split('/').last,
                                            style: theme.textTheme.bodyMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  fontFamily: 'monospace',
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.copy, size: 18),
                                      onPressed: () {
                                        final invitationId = _inviteLink!
                                            .split('/')
                                            .last;
                                        Clipboard.setData(
                                          ClipboardData(text: invitationId),
                                        );
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Invitation ID copied!',
                                            ),
                                            backgroundColor: AppColors.success,
                                            duration: Duration(seconds: 2),
                                          ),
                                        );
                                      },
                                      tooltip: 'Copy ID',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: AppTheme.spaceMd),
                        Row(
                          children: [
                            Expanded(
                              child: SecondaryButton(
                                text: 'Copy Link',
                                icon: Icons.copy,
                                onPressed: _inviteLink != null
                                    ? _copyLink
                                    : null,
                              ),
                            ),
                            const SizedBox(width: AppTheme.spaceMd),
                            Expanded(
                              child: PrimaryButton(
                                text: 'Share',
                                icon: Icons.share,
                                onPressed: _inviteLink != null
                                    ? _shareLink
                                    : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppTheme.spaceMd),
                        // Generate new link button
                        TextButton.icon(
                          onPressed: () {
                            setState(() => _inviteLink = null);
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Generate New Link'),
                        ),
                      ],
                    ),
                  ),
                ],
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
                        '2. They can tap the link to open in Costify app',
                      ),
                      _buildInfoItem(
                        context,
                        '3. They must have a Costify account to join',
                      ),
                      _buildInfoItem(context, '4. The link expires in 7 days'),
                      const SizedBox(height: AppTheme.spaceSm),
                      Container(
                        padding: const EdgeInsets.all(AppTheme.spaceSm),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusSm,
                          ),
                          border: Border.all(
                            color: AppColors.warning.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: AppColors.warning,
                              size: 16,
                            ),
                            const SizedBox(width: AppTheme.spaceSm),
                            Expanded(
                              child: Text(
                                'If the link doesn\'t open the app, they can:\n'
                                '1. Open Costify app\n'
                                '2. Go to Projects screen\n'
                                '3. Tap the link icon (🔗) in the top right\n'
                                '4. Enter the invitation ID manually',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppColors.warning,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
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
                    role: ProjectMemberRoles.labels[member.role] ?? member.role,
                    joinedAt: member.joinedAt,
                    isDirector: member.isDirector,
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

  Widget _buildRoleOption(
    BuildContext context, {
    required String role,
    required String title,
    required String description,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    final isSelected = _selectedRole == role;
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: _inviteLink == null
          ? () {
              setState(() => _selectedRole = role);
            }
          : null,
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spaceMd),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.1)
              : (isDark ? AppColors.surfaceContainerDark : Colors.white),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : theme.colorScheme.outline.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spaceSm),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.2)
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Icon(icon, color: isSelected ? AppColors.primary : null),
            ),
            const SizedBox(width: AppTheme.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isSelected ? AppColors.primary : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: AppColors.primary),
          ],
        ),
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
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.info),
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
    bool isDirector = false,
    DateTime? joinedAt,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hasSpecialRole = isAdmin || isDirector;

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
            backgroundColor: hasSpecialRole
                ? AppColors.primaryContainer
                : theme.colorScheme.surfaceContainerHighest,
            child: Text(
              Formatters.getInitials(name),
              style: theme.textTheme.titleSmall?.copyWith(
                color: hasSpecialRole ? AppColors.primary : null,
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
                      ? '$role • Joined ${Formatters.getRelativeTime(joinedAt)}'
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
          if (isDirector && !isAdmin)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spaceSm,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Text(
                'DIRECTOR',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.secondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
