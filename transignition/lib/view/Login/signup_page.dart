import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:transignition/view/Dashboard/face_registration_page.dart';
import 'package:transignition/service/translate_service.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameC;
  late TextEditingController _emailC;
  late TextEditingController _passwordC;
  late TextEditingController _confirmC;
  late TextEditingController _usernameC;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    // match login page: immersive sticky
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

    _nameC = TextEditingController();
    _usernameC = TextEditingController();
    _emailC = TextEditingController();
    _passwordC = TextEditingController();
    _confirmC = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    _nameC.dispose();
    _usernameC.dispose();
    _emailC.dispose();
    _passwordC.dispose();
    _confirmC.dispose();
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
      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );
      final isNewUser = userCredential.additionalUserInfo?.isNewUser ?? false;

      if (mounted) {
        if (isNewUser) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const FaceRegistrationPage(),
            ),
          );
        } else {
          // If not a new user, StreamBuilder in main.dart will push Dashboard,
          // but we pop the signup page out of the stack so we don't end up with an unneeded back stack
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      }
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

  Widget _buildTextField({
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailC.text.trim(),
        password: _passwordC.text.trim(),
      );
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const FaceRegistrationPage()),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message ?? 'Daftar gagal')));
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
            final cardWidth = min(constraints.maxWidth * 0.92, 520.w);
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
                                    Icons.person_add_rounded,
                                    color: colorScheme.onPrimaryContainer,
                                    size: 40.r,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: 24.h),
                            // Welcome Text
                            Text(
                              TranslateService.tr('Create Account'),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.roboto(
                                fontSize: 28.sp,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            SizedBox(height: 8.h),
                            Text(
                              TranslateService.tr('Register below to start'),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.roboto(
                                fontSize: 16.sp,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            SizedBox(height: 32.h),

                            _buildTextField(
                              controller: _nameC,
                              label: "Nama Lengkap",
                              icon: Icons.person_outline,
                              action: TextInputAction.next,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Silakan masukkan nama Anda';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            _buildTextField(
                              controller: _usernameC,
                              label: TranslateService.tr('Username'),
                              icon: Icons.person_outline,
                              action: TextInputAction.next,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Silakan masukkan nama pengguna';
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: 16.h),

                            _buildTextField(
                              controller: _emailC,
                              label: TranslateService.tr('Email Address'),
                              icon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                              action: TextInputAction.next,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return '${TranslateService.tr('Please enter your ')}email';
                                }
                                if (!value.contains('@')) {
                                  return 'Masukkan email yang valid';
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: 16.h),

                            _buildTextField(
                              controller: _passwordC,
                              label: TranslateService.tr('Password'),
                              icon: Icons.lock_outline,
                              obscure: _obscurePassword,
                              action: TextInputAction.next,
                              suffix: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
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
                            SizedBox(height: 16.h),

                            _buildTextField(
                              controller: _confirmC,
                              label: TranslateService.tr('Confirm Password'),
                              icon: Icons.lock,
                              obscure: _obscureConfirm,
                              action: TextInputAction.done,
                              suffix: IconButton(
                                icon: Icon(
                                  _obscureConfirm
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                                onPressed: () => setState(
                                  () => _obscureConfirm = !_obscureConfirm,
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Konfirmasi kata sandi Anda';
                                }
                                if (value != _passwordC.text) {
                                  return TranslateService.tr(
                                    'Passwords do not match',
                                  );
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: 32.h),

                            FilledButton(
                              onPressed: _isLoading ? null : _submit,
                              style: FilledButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 16.h),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(100.r),
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
                                      "Daftar",
                                      style: GoogleFonts.roboto(
                                        fontSize: 16.sp,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                            const SizedBox(height: 16),

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
                                "Lanjutkan dengan Google",
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

                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  TranslateService.tr(
                                    'Already have an account? ',
                                  ),
                                  style: GoogleFonts.roboto(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    foregroundColor: colorScheme.primary,
                                  ),
                                  child: Text(
                                    TranslateService.tr('Sign In'),
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
