import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:transignition/view/Login/signup_page.dart';
import 'package:transignition/service/translate_service.dart';
import 'package:transignition/view/Login/forgot_password_page.dart';
import 'package:transignition/view/Dashboard/dashboard_page.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  bool _obscurePassword = true;
  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _emailController;
  late TextEditingController _passwordController;

  @override
  void initState() {
    super.initState();
    // Enable fullscreen (hide system UI) for this page
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    // Restore system UI when leaving this page
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  /// Sign in to Firebase using the Google user's idToken
  Future<void> _firebaseSignInWithGoogleAccount(
    GoogleSignInAccount googleUser,
  ) async {
    try {
      final GoogleSignInAuthentication authentication =
          googleUser.authentication;
      final String? idToken = authentication.idToken;
      if (idToken == null) {
        throw Exception('No ID token received from Google Sign-In');
      }
      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: idToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      // Success: Navigation is handled by StreamBuilder in main.dart
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Masuk Firebase gagal: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const DashboardPage()),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message ?? 'Masuk gagal')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final googleSignIn = GoogleSignIn.instance;

      // Force logout first to ensure account picker shows up
      await googleSignIn.signOut();

      final GoogleSignInAccount? googleUser = await googleSignIn.authenticate();

      if (googleUser != null) {
        await _firebaseSignInWithGoogleAccount(googleUser);
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (e is GoogleSignInException &&
          (e.code == GoogleSignInExceptionCode.canceled ||
              e.code == GoogleSignInExceptionCode.interrupted)) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Masuk Google gagal: $e')));
      }
    }
  }

  Widget _buildTextField(
    BuildContext context, {
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
    TextInputType keyboardType = TextInputType.text,
    TextInputAction? action,
    String? Function(String?)? validator,
    Widget? suffix,
  }) {
    final theme = Theme.of(context);

    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      textInputAction: action,
      style: GoogleFonts.roboto(),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.roboto(),
        prefixIcon: Icon(icon),
        suffixIcon: suffix,
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.r),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.r),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.r),
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 2.w),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.r),
          borderSide: BorderSide(color: theme.colorScheme.error, width: 2.w),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.r),
          borderSide: BorderSide(color: theme.colorScheme.error, width: 2.w),
        ),
      ),
      validator: validator,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = min(constraints.maxWidth * 0.92, 420.w);
            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 20.w,
                  right: 20.w,
                  top: 32.h,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24.h,
                ),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: SizedBox(
                      width: cardWidth,
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Minimalist Material You Icon
                            Align(
                              alignment: Alignment.center,
                              child: Container(
                                width: 88.r,
                                height: 88.r,
                                decoration: BoxDecoration(
                                  color: colorScheme.primaryContainer,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Icon(
                                    Icons.lock_rounded,
                                    color: colorScheme.onPrimaryContainer,
                                    size: 40.r,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: 24.h),
                            // Welcome Text
                            Text(
                              TranslateService.tr('Welcome Back'),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.roboto(
                                fontSize: 28.sp,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            SizedBox(height: 8.h),
                            Text(
                              TranslateService.tr(
                                'Enter your details to proceed',
                              ),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.roboto(
                                fontSize: 16.sp,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            SizedBox(height: 32.h),

                            // Email
                            _buildTextField(
                              context,
                              controller: _emailController,
                              label: TranslateService.tr('Email Address'),
                              icon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                              action: TextInputAction.next,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return '${TranslateService.tr('Please enter your ')}Email';
                                }
                                if (!value.contains('@')) {
                                  return 'Masukkan email yang valid';
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: 16.h),

                            // Password
                            _buildTextField(
                              context,
                              controller: _passwordController,
                              label: TranslateService.tr('Password'),
                              icon: Icons.lock_outline,
                              obscure: _obscurePassword,
                              action: TextInputAction.done,
                              suffix: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Silakan masukkan kata sandi Anda';
                                }
                                if (value.length < 6) {
                                  return 'Kata sandi minimal 6 karakter';
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: 8.h),

                            // Forgot Password Link
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const ForgotPasswordPage(),
                                    ),
                                  );
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: colorScheme.primary,
                                ),
                                child: Text(
                                  TranslateService.tr('Forgot Password?'),
                                  style: GoogleFonts.roboto(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: 24.h),

                            // Login Button
                            FilledButton(
                              onPressed: _isLoading ? null : _login,
                              style: FilledButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 16.h),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    100.r,
                                  ), // Fully rounded corner for M3
                                ),
                              ),
                              child: _isLoading
                                  ? SizedBox(
                                      height: 20.r,
                                      width: 20.r,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.w,
                                      ),
                                    )
                                  : Text(
                                      TranslateService.tr('Login'),
                                      style: GoogleFonts.roboto(
                                        fontSize: 16.sp,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                            SizedBox(height: 16.h),

                            // Google Sign-in Button using OutlinedButton
                            OutlinedButton.icon(
                              onPressed: _isLoading ? null : _signInWithGoogle,
                              icon: Image.network(
                                'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/120px-Google_%22G%22_logo.svg.png',
                                height: 20,
                                errorBuilder: (context, _, __) {
                                  return const Icon(
                                    Icons.g_mobiledata,
                                    size: 24,
                                  );
                                },
                              ),
                              label: Text(
                                TranslateService.tr('Continue with Google'),
                                style: GoogleFonts.roboto(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 16.h),
                                foregroundColor: colorScheme.onSurface,
                                side: BorderSide(color: colorScheme.outline),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(100.r),
                                ),
                              ),
                            ),
                            SizedBox(height: 24.h),

                            // Sign up prompt
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  TranslateService.tr(
                                    "Don't have an account? ",
                                  ),
                                  style: GoogleFonts.roboto(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const SignupPage(),
                                      ),
                                    );
                                  },
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    foregroundColor: colorScheme.primary,
                                  ),
                                  child: Text(
                                    TranslateService.tr('Sign Up'),
                                    style: GoogleFonts.roboto(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
