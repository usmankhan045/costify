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

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isGoogleLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final success = await ref
        .read(authNotifierProvider.notifier)
        .signInWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

    setState(() => _isLoading = false);

    if (success && mounted) {
      context.go(AppRoutes.dashboard);
    } else if (mounted) {
      final error = ref.read(authNotifierProvider).errorMessage;
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _handleGoogleLogin() async {
    if (!mounted) return;
    setState(() => _isGoogleLoading = true);

    try {
      final success = await ref
          .read(authNotifierProvider.notifier)
          .signInWithGoogle();

      if (!mounted) return;
      setState(() => _isGoogleLoading = false);

      if (success) {
        context.go(AppRoutes.dashboard);
      } else {
        final authState = ref.read(authNotifierProvider);
        if (authState.requires2FA) {
          context.go(AppRoutes.verify2FA);
        } else if (authState.errorMessage != null) {
          // Don't show error for cancelled sign-in
          final errorCode = authState.errorMessage;
          if (errorCode != 'Google sign in was cancelled') {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(authState.errorMessage!),
                backgroundColor: AppColors.error,
              ),
            );
          }
        }
      }
    } catch (e, stackTrace) {
      print('🔴 [Login Screen] Error in _handleGoogleLogin: $e');
      print('🔴 [Login Screen] Error type: ${e.runtimeType}');
      print('🔴 [Login Screen] Stack trace: $stackTrace');
      if (!mounted) return;
      setState(() => _isGoogleLoading = false);
      // Only show error if it's not a cancellation
      final errorMessage = e.toString();
      if (!errorMessage.contains('cancelled') && !errorMessage.contains('canceled')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to sign in with Google. Please try again.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spaceLg),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: size.height * 0.05),
                  // Logo and title
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: AppColors.mediumShadow,
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Image.asset(
                            'assets/images/splash_logo.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spaceMd),
                        Text(
                          'COSTIFY',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1A365D),
                            letterSpacing: 3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: size.height * 0.06),
                  // Welcome text
                  Text(
                    AppStrings.welcomeBack,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceXs),
                  Text(
                    AppStrings.signInToContinue,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceXl),
                  // Email field
                  EmailTextField(
                    controller: _emailController,
                    validator: Validators.validateEmail,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: AppTheme.spaceMd),
                  // Password field
                  PasswordTextField(
                    controller: _passwordController,
                    validator: Validators.validatePassword,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _handleLogin(),
                  ),
                  const SizedBox(height: AppTheme.spaceSm),
                  // Forgot password
                  Align(
                    alignment: Alignment.centerRight,
                    child: CustomTextButton(
                      text: AppStrings.forgotPassword,
                      onPressed: () => context.push(AppRoutes.forgotPassword),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceLg),
                  // Login button
                  PrimaryButton(
                    text: AppStrings.signIn,
                    onPressed: _handleLogin,
                    isLoading: _isLoading,
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
                  // Google sign in
                  GoogleSignInButton(
                    onPressed: _handleGoogleLogin,
                    isLoading: _isGoogleLoading,
                  ),
                  const SizedBox(height: AppTheme.spaceXl),
                  // Sign up link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        AppStrings.dontHaveAccount,
                        style: theme.textTheme.bodyMedium,
                      ),
                      CustomTextButton(
                        text: AppStrings.signUp,
                        onPressed: () => context.push(AppRoutes.register),
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
}
