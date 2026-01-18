import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../../providers/auth_provider.dart';
import '../../../router/app_router.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _agreedToTerms = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please agree to the Terms of Service'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final success = await ref.read(authNotifierProvider.notifier).signUpWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          name: _nameController.text.trim(),
          phoneNumber: _phoneController.text.trim().isEmpty
              ? null
              : _phoneController.text.trim(),
        );

    if (success && mounted) {
      final email = _emailController.text.trim();
      setState(() => _isLoading = false);
      
      print('✅ [Register] Signup successful, showing dialog for: $email');
      
      // Show dialog immediately - don't wait for post frame callback
      // This ensures it shows before any router redirects
      await _showVerificationDialog(email);
    } else {
      setState(() => _isLoading = false);
      if (mounted) {
        final error = ref.read(authNotifierProvider).errorMessage;
        if (error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _handleGoogleSignUp() async {
    if (!mounted) return;
    setState(() => _isGoogleLoading = true);

    try {
      final success = await ref
          .read(authNotifierProvider.notifier)
          .signInWithGoogle();

      if (!mounted) return;
      setState(() => _isGoogleLoading = false);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account created successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        context.go(AppRoutes.dashboard);
      } else {
        final authState = ref.read(authNotifierProvider);
        if (authState.errorMessage != null) {
          // Don't show error for cancelled sign-in
          final errorMessage = authState.errorMessage!;
          if (!errorMessage.contains('cancelled') && !errorMessage.contains('canceled')) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(authState.errorMessage!),
                backgroundColor: AppColors.error,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isGoogleLoading = false);
      final errorMessage = e.toString();
      if (!errorMessage.contains('cancelled') && !errorMessage.contains('canceled')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to sign up with Google. Please try again.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spaceLg),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    AppStrings.createAccount,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceXs),
                  Text(
                    AppStrings.signUpSubtitle,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceXl),
                  // Name field
                  CustomTextField(
                    label: AppStrings.fullName,
                    hint: 'Enter your full name',
                    controller: _nameController,
                    prefixIcon: const Icon(Icons.person_outline),
                    textCapitalization: TextCapitalization.words,
                    validator: Validators.validateName,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: AppTheme.spaceMd),
                  // Email field
                  EmailTextField(
                    controller: _emailController,
                    validator: Validators.validateEmail,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: AppTheme.spaceMd),
                  // Phone field (optional)
                  CustomTextField(
                    label: '${AppStrings.phoneNumber} (Optional)',
                    hint: '+92 300 1234567',
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    prefixIcon: const Icon(Icons.phone_outlined),
                    validator: Validators.validatePhone,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: AppTheme.spaceMd),
                  // Password field
                  PasswordTextField(
                    controller: _passwordController,
                    validator: Validators.validatePassword,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: AppTheme.spaceMd),
                  // Confirm password field
                  PasswordTextField(
                    label: AppStrings.confirmPassword,
                    hint: 'Re-enter your password',
                    controller: _confirmPasswordController,
                    validator: (value) => Validators.validateConfirmPassword(
                      value,
                      _passwordController.text,
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _handleRegister(),
                  ),
                  const SizedBox(height: AppTheme.spaceMd),
                  // Terms checkbox
                  Row(
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Checkbox(
                          value: _agreedToTerms,
                          onChanged: (value) {
                            setState(() => _agreedToTerms = value ?? false);
                          },
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppTheme.spaceSm),
                      Expanded(
                        child: Wrap(
                          children: [
                            Text(
                              'I agree to the ',
                              style: theme.textTheme.bodySmall,
                            ),
                            GestureDetector(
                              onTap: () {
                                // TODO: Show terms of service
                              },
                              child: Text(
                                'Terms of Service',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              ' and ',
                              style: theme.textTheme.bodySmall,
                            ),
                            GestureDetector(
                              onTap: () {
                                // TODO: Show privacy policy
                              },
                              child: Text(
                                'Privacy Policy',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spaceLg),
                  // Register button
                  PrimaryButton(
                    text: AppStrings.signUp,
                    onPressed: _handleRegister,
                    isLoading: _isLoading,
                    isEnabled: _agreedToTerms,
                  ),
                  const SizedBox(height: AppTheme.spaceLg),
                  // Divider
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spaceMd,
                        ),
                        child: Text(
                          AppStrings.orContinueWith,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spaceLg),
                  // Google sign up
                  GoogleSignInButton(
                    onPressed: _handleGoogleSignUp,
                    isLoading: _isGoogleLoading,
                  ),
                  const SizedBox(height: AppTheme.spaceLg),
                  // Sign in link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        AppStrings.alreadyHaveAccount,
                        style: theme.textTheme.bodyMedium,
                      ),
                      CustomTextButton(
                        text: AppStrings.signIn,
                        onPressed: () => context.pop(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showVerificationDialog(String email) async {
    if (!mounted) return;
    
    print('✅ [Register] Showing verification dialog for: $email');
    
    final result = await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false, // Prevent back button from closing
        child: AlertDialog(
        title: Row(
          children: [
            Icon(Icons.email_outlined, color: AppColors.primary),
            const SizedBox(width: AppTheme.spaceSm),
            const Text('Check Your Inbox'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'We\'ve sent a verification link to your email address.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: AppTheme.spaceMd),
            Container(
              padding: const EdgeInsets.all(AppTheme.spaceMd),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: Row(
                children: [
                  Icon(Icons.email, color: AppColors.primary, size: 20),
                  const SizedBox(width: AppTheme.spaceSm),
                  Expanded(
                    child: Text(
                      email,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spaceMd),
            const Text(
              'Please check your inbox and click the verification link to activate your account. Then you can sign in.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: AppTheme.spaceSm),
            Container(
              padding: const EdgeInsets.all(AppTheme.spaceSm),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: AppColors.info, size: 18),
                  const SizedBox(width: AppTheme.spaceSm),
                  Expanded(
                    child: Text(
                      'Don\'t see the email? Check your spam folder or click "Resend" on the next screen.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.info,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop('ok');
            },
            child: const Text('OK'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop('continue');
            },
            child: const Text('Continue'),
          ),
        ],
        ),
      ),
    );
    
    // Navigate based on dialog result
    if (mounted && result != null) {
      if (result == 'continue') {
        context.go('${AppRoutes.emailVerification}?email=${Uri.encodeComponent(email)}');
      } else {
        context.go(AppRoutes.login);
      }
    }
  }
}

