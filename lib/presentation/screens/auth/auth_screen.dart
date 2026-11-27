import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_logo.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isSignUp = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showForgotPasswordDialog(BuildContext context, AuthProvider auth) {
    final resetEmailController = TextEditingController(text: _emailController.text.trim());
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.lock_reset, color: AppColors.primaryAccent),
            const SizedBox(width: 8),
            Text('Reset Password', style: TextStyle(color: AppColors.textPrimary(context), fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter your registered database email address to receive password reset instructions.',
              style: TextStyle(color: AppColors.textSecondary(context), fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: resetEmailController,
              keyboardType: TextInputType.emailAddress,
              style: TextStyle(color: AppColors.textPrimary(context)),
              decoration: InputDecoration(
                labelText: 'Email Address',
                labelStyle: TextStyle(color: AppColors.textSecondary(context)),
                prefixIcon: const Icon(Icons.email_outlined, color: AppColors.primaryAccent),
                filled: true,
                fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary(context))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final email = resetEmailController.text.trim();
              if (email.isNotEmpty) {
                Navigator.pop(ctx);
                await auth.resetPassword(email);
              }
            },
            child: const Text('Send Reset Link'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final inputFill = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04);
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.2)),
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: AppColors.icon(context)),
          onPressed: () {
            auth.clearMessages();
            Navigator.pop(context);
          },
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const AppLogo(size: 68, showText: true),
              const SizedBox(height: 6),
              Text(
                'Cloud Sync & Personalized Music Experience',
                textAlign: TextAlign.center,
                style: TextStyle(color: secondaryTextColor, fontSize: 13),
              ),
              const SizedBox(height: 16),

              // Firebase Cloud Database Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.06) : AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primaryAccent.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_done_outlined, size: 16, color: AppColors.primaryAccent),
                    const SizedBox(width: 6),
                    Text(
                      'Powered by Firebase & Local Users Table',
                      style: TextStyle(color: isDark ? Colors.white70 : AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Error banner if any
              if (auth.errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          auth.errorMessage!,
                          style: TextStyle(color: primaryTextColor, fontSize: 12),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, size: 16, color: secondaryTextColor),
                        onPressed: () => auth.clearError(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Success banner if any
              if (auth.successMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          auth.successMessage!,
                          style: TextStyle(color: primaryTextColor, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Name Field (Only in Sign Up mode)
              if (_isSignUp) ...[
                TextField(
                  controller: _nameController,
                  keyboardType: TextInputType.name,
                  style: TextStyle(color: primaryTextColor),
                  decoration: InputDecoration(
                    labelText: 'Full Name',
                    labelStyle: TextStyle(color: secondaryTextColor),
                    prefixIcon: const Icon(Icons.person_outline, color: AppColors.primaryAccent),
                    filled: true,
                    fillColor: inputFill,
                    border: inputBorder,
                    enabledBorder: inputBorder,
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Email Field
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: TextStyle(color: primaryTextColor),
                decoration: InputDecoration(
                  labelText: 'Email Address',
                  labelStyle: TextStyle(color: secondaryTextColor),
                  prefixIcon: const Icon(Icons.email_outlined, color: AppColors.primaryAccent),
                  filled: true,
                  fillColor: inputFill,
                  border: inputBorder,
                  enabledBorder: inputBorder,
                ),
              ),
              const SizedBox(height: 14),

              // Password Field
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                style: TextStyle(color: primaryTextColor),
                decoration: InputDecoration(
                  labelText: 'Password',
                  labelStyle: TextStyle(color: secondaryTextColor),
                  prefixIcon: const Icon(Icons.lock_outline, color: AppColors.primaryAccent),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      color: secondaryTextColor,
                    ),
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                  ),
                  filled: true,
                  fillColor: inputFill,
                  border: inputBorder,
                  enabledBorder: inputBorder,
                ),
              ),

              // Forgot Password link (only in Sign In mode)
              if (!_isSignUp) ...[
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => _showForgotPasswordDialog(context, auth),
                    child: const Text(
                      'Forgot Password?',
                      style: TextStyle(color: AppColors.primaryAccent, fontSize: 12),
                    ),
                  ),
                ),
              ] else ...[
                const SizedBox(height: 16),
              ],

              // Main Action Button (Sign In / Sign Up)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                    elevation: 2,
                  ),
                  onPressed: auth.isLoading
                      ? null
                      : () async {
                          final email = _emailController.text.trim();
                          final password = _passwordController.text.trim();
                          final name = _nameController.text.trim();

                          if (_isSignUp) {
                            final success = await auth.registerWithEmail(email, password, name);
                            if (success && context.mounted) {
                              Future.delayed(const Duration(milliseconds: 600), () {
                                if (context.mounted) Navigator.pop(context);
                              });
                            }
                          } else {
                            final success = await auth.signInWithEmail(email, password);
                            if (success && context.mounted) {
                              Future.delayed(const Duration(milliseconds: 600), () {
                                if (context.mounted) Navigator.pop(context);
                              });
                            }
                          }
                        },
                  child: auth.isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          _isSignUp ? 'Create Free Account' : 'Sign In',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                ),
              ),
              const SizedBox(height: 12),

              // Switch between Sign In / Sign Up
              TextButton(
                onPressed: () {
                  auth.clearMessages();
                  setState(() => _isSignUp = !_isSignUp);
                },
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 13),
                    children: [
                      TextSpan(
                        text: _isSignUp ? 'Already have an account? ' : "Don't have an account? ",
                        style: TextStyle(color: secondaryTextColor),
                      ),
                      TextSpan(
                        text: _isSignUp ? 'Sign In' : 'Sign Up',
                        style: const TextStyle(color: AppColors.primaryAccent, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),

              Row(
                children: [
                  Expanded(child: Divider(color: Theme.of(context).dividerColor.withValues(alpha: 0.15))),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('OR', style: TextStyle(color: secondaryTextColor.withValues(alpha: 0.6), fontSize: 11)),
                  ),
                  Expanded(child: Divider(color: Theme.of(context).dividerColor.withValues(alpha: 0.15))),
                ],
              ),
              const SizedBox(height: 18),

              // Google Sign In Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryTextColor,
                    side: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.3)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                  icon: const Icon(Icons.g_mobiledata, size: 28, color: AppColors.primaryAccent),
                  label: const Text('Continue with Google', style: TextStyle(fontWeight: FontWeight.w600)),
                  onPressed: auth.isLoading
                      ? null
                      : () async {
                          await auth.signInWithGoogle();
                          if (context.mounted && auth.isAuthenticated) {
                            Navigator.pop(context);
                          }
                        },
                ),
              ),
              const SizedBox(height: 12),

              // Continue as Guest Button
              TextButton(
                onPressed: auth.isLoading
                    ? null
                    : () async {
                        await auth.signInAsGuest();
                        if (context.mounted) Navigator.pop(context);
                      },
                child: Text(
                  'Continue as Guest (Offline Mode)',
                  style: TextStyle(color: secondaryTextColor, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
