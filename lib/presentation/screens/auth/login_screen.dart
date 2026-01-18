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

    if (_isLoading) return; // Prevent multiple simultaneous login attempts

    setState(() => _isLoading = true);

    try {
      final success = await ref
          .read(authNotifierProvider.notifier)
          .signInWithEmail(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );

      if (!mounted) return;

      setState(() => _isLoading = false);

      if (success) {
        // Clear any previous errors
        ref.read(authNotifierProvider.notifier).clearError();
        context.go(AppRoutes.dashboard);
      } else {
        final authState = ref.read(authNotifierProvider);
        final email = _emailController.text.trim();
        
        // Check if user exists but email is not verified
        if (authState.user != null && !authState.user!.isEmailVerified) {
          // Show popup first, then navigate
          _showEmailNotVerifiedDialog(email);
        } else if (authState.errorMessage != null) {
          // Check if it's a user-not-found error
          final errorMessage = authState.errorMessage!;
          if (errorMessage.toLowerCase().contains('no user found') || 
              errorMessage.toLowerCase().contains('user-not-found')) {
            // Check if email exists in Firestore (user signed up but didn't verify)
            await _checkAndHandleUnregisteredUser(email);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(errorMessage),
                backgroundColor: AppColors.error,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('An unexpected error occurred. Please try again.'),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _handleGoogleLogin() async {
    if (!mounted) return;
    if (_isGoogleLoading) return; // Prevent multiple simultaneous login attempts

    setState(() => _isGoogleLoading = true);

    try {
      final success = await ref
          .read(authNotifierProvider.notifier)
          .signInWithGoogle();

      if (!mounted) return;
      setState(() => _isGoogleLoading = false);

      if (success) {
        // Clear any previous errors
        ref.read(authNotifierProvider.notifier).clearError();
        context.go(AppRoutes.dashboard);
      } else {
        final authState = ref.read(authNotifierProvider);
        // Check if user exists but email is not verified
        if (authState.user != null && !authState.user!.isEmailVerified) {
          final email = authState.user!.email;
          context.go('${AppRoutes.emailVerification}?email=${Uri.encodeComponent(email)}');
        } else if (authState.errorMessage != null) {
          // Don't show error for cancelled sign-in
          final errorMessage = authState.errorMessage!;
          if (!errorMessage.toLowerCase().contains('cancelled') && 
              !errorMessage.toLowerCase().contains('canceled')) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(errorMessage),
                backgroundColor: AppColors.error,
                duration: const Duration(seconds: 4),
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
      if (!errorMessage.toLowerCase().contains('cancelled') && 
          !errorMessage.toLowerCase().contains('canceled')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to sign in with Google. Please try again.'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Calculate spacing to fill available height
            // Account for padding (AppTheme.spaceLg * 2 = top + bottom)
            final paddingHeight = AppTheme.spaceLg * 2;
            final availableHeight = constraints.maxHeight - paddingHeight;
            // Estimate fixed content height (logo + text + fields + buttons)
            // Logo: 100 + spaceMd + text height (~30) = ~150
            // Welcome text: ~60
            // Email field: ~60
            // Password field: ~60
            // Forgot password: ~30
            // Login button: ~56
            // Divider: ~20
            // Google button: ~56
            // Sign up link: ~30
            // Spacing between elements: ~200
            final fixedContentHeight = 700.0;
            final extraSpace = availableHeight > fixedContentHeight 
                ? (availableHeight - fixedContentHeight) 
                : 0.0;
            // Only add spacing if there's extra space, otherwise use minimal spacing
            final topSpacing = extraSpace > 0 
                ? (extraSpace * 0.3).clamp(20.0, 100.0) 
                : 20.0;
            final middleSpacing = extraSpace > 0 
                ? (extraSpace * 0.5).clamp(30.0, 120.0) 
                : 30.0;
            final bottomSpacing = extraSpace > 0 
                ? (extraSpace * 0.2).clamp(20.0, 80.0) 
                : 20.0;
            
            return SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spaceLg),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        SizedBox(height: topSpacing),
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
                        SizedBox(height: middleSpacing),
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
                        SizedBox(height: bottomSpacing),
                      ],
                    ),
                  ),
                ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _checkAndHandleUnregisteredUser(String email) async {
    try {
      // Check if email exists in Firestore
      final userModel = await ref.read(authNotifierProvider.notifier).checkEmailExists(email);
      
      if (userModel != null) {
        // User exists in Firestore but email not verified
        // Show verification dialog
        _showEmailNotVerifiedDialog(email);
      } else {
        // User doesn't exist at all - show signup prompt
        _showSignUpPromptDialog(email);
      }
    } catch (e) {
      // If check fails, show generic signup prompt
      _showSignUpPromptDialog(email);
    }
  }

  Future<void> _showSignUpPromptDialog(String email) async {
    if (!mounted) return;
    
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: Row(
            children: [
              Icon(Icons.person_add_outlined, color: AppColors.info),
              const SizedBox(width: AppTheme.spaceSm),
              const Text('Account Not Found'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'No account found with this email address.',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: AppTheme.spaceMd),
              Container(
                padding: const EdgeInsets.all(AppTheme.spaceMd),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: Row(
                  children: [
                    Icon(Icons.email, color: AppColors.info, size: 20),
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
                'Would you like to create a new account?',
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                if (mounted) {
                  context.push(AppRoutes.register);
                }
              },
              child: const Text('Sign Up'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEmailNotVerifiedDialog(String email) async {
    if (!mounted) return;
    
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false, // Prevent back button from closing
        child: AlertDialog(
          title: Row(
            children: [
              Icon(Icons.email_outlined, color: AppColors.warning),
              const SizedBox(width: AppTheme.spaceSm),
              const Text('Email Not Verified'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your email address has not been verified yet.',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: AppTheme.spaceMd),
              Container(
                padding: const EdgeInsets.all(AppTheme.spaceMd),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: Row(
                  children: [
                    Icon(Icons.email, color: AppColors.warning, size: 20),
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
                'Please check your inbox and click the verification link to activate your account before signing in.',
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
                        'Don\'t see the email? Check your spam folder or click "Resend" on the verification screen.',
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
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                if (mounted) {
                  context.go('${AppRoutes.emailVerification}?email=${Uri.encodeComponent(email)}');
                }
              },
              child: const Text('Verify Email'),
            ),
          ],
        ),
      ),
    );
  }
}
