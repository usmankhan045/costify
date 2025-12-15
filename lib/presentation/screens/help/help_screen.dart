import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class HelpScreen extends ConsumerWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.help),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Center(
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.support_agent,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceMd),
                  Text(
                    'How can we help you?',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spaceXl),
            // Quick actions
            Row(
              children: [
                Expanded(
                  child: _buildQuickAction(
                    context,
                    icon: Icons.email_outlined,
                    label: AppStrings.contactUs,
                    onTap: () => _launchEmail(),
                  ),
                ),
                const SizedBox(width: AppTheme.spaceMd),
                Expanded(
                  child: _buildQuickAction(
                    context,
                    icon: Icons.bug_report_outlined,
                    label: AppStrings.reportBug,
                    onTap: () => _showReportDialog(context, isBug: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spaceLg),
            // FAQ Section
            Text(
              AppStrings.faq,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spaceMd),
            _buildFAQItem(
              context,
              question: 'How do I create a new project?',
              answer:
                  'To create a new project, go to the Projects tab and tap the "+" button or "Create Project". Fill in the project details including name, budget, and dates, then tap "Create".',
            ),
            _buildFAQItem(
              context,
              question: 'How do I add stakeholders to my project?',
              answer:
                  'As an admin, open your project and tap "Invite Stakeholder". Share the generated link with your team members. They need to have a Costify account to join.',
            ),
            _buildFAQItem(
              context,
              question: 'How do I add an expense?',
              answer:
                  'Go to a project or the Expenses tab, tap "Add Expense", fill in the details including amount, category, and optionally upload a receipt photo.',
            ),
            _buildFAQItem(
              context,
              question: 'How does expense approval work?',
              answer:
                  'When stakeholders add expenses, they remain in "Pending" status. Project admins can then review and either approve or reject expenses.',
            ),
            _buildFAQItem(
              context,
              question: 'What is two-factor authentication (2FA)?',
              answer:
                  '2FA adds an extra security layer. When enabled, you\'ll need to enter a code sent to your email each time you sign in.',
            ),
            const SizedBox(height: AppTheme.spaceLg),
            // Contact info
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
                    'Still need help?',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceSm),
                  Text(
                    'Our support team is here to help you with any questions or issues.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceMd),
                  PrimaryButton(
                    text: AppStrings.contactUs,
                    icon: Icons.email,
                    onPressed: () => _launchEmail(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spaceXl),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spaceMd),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceContainerDark : Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          boxShadow: AppColors.softShadow,
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spaceSm),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: Icon(icon, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: AppTheme.spaceSm),
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFAQItem(
    BuildContext context, {
    required String question,
    required String answer,
  }) {
    return ExpansionTile(
      title: Text(
        question,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: AppTheme.spaceMd,
            right: AppTheme.spaceMd,
            bottom: AppTheme.spaceMd,
          ),
          child: Text(
            answer,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      ],
    );
  }

  Future<void> _launchEmail() async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'support@costify.app',
      query: 'subject=Costify Support Request',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _showReportDialog(BuildContext context, {required bool isBug}) {
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isBug ? AppStrings.reportBug : AppStrings.featureRequest),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isBug
                  ? 'Please describe the bug you encountered:'
                  : 'What feature would you like to see?',
            ),
            const SizedBox(height: AppTheme.spaceMd),
            CustomTextField(
              controller: descriptionController,
              hint: 'Describe here...',
              maxLines: 4,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    isBug ? 'Bug report submitted!' : 'Feature request submitted!',
                  ),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }
}

