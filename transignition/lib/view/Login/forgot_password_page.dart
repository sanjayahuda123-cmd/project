import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:transignition/service/translate_service.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendReset() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _sending = true);
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() => _sending = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${TranslateService.tr('Password reset email sent!')} ${_emailCtrl.text.trim()}',
        ),
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = theme.scaffoldBackgroundColor;
    final accent = const Color(0xFF1DB954);

    return Scaffold(
      backgroundColor: bgColor,
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? const [Color(0xFF0F1111), Color(0xFF121212)]
                : [Colors.white, Colors.grey.shade100],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: 20.w,
                vertical: MediaQuery.of(context).viewInsets.bottom + 28.h,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 420.w),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 88.r,
                      height: 88.r,
                      decoration: BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Icon(
                          Icons.lock_reset,
                          color: Colors.black,
                          size: 36.r,
                        ),
                      ),
                    ),
                    SizedBox(height: 18.h),
                    Text(
                      TranslateService.tr('Reset Password'),
                      style: GoogleFonts.roboto(
                        fontSize: 26.sp,
                        fontWeight: FontWeight.bold,
                        color: theme.textTheme.headlineSmall?.color,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      TranslateService.tr(
                        'Enter your email to receive a password reset link',
                      ),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.roboto(
                        color: theme.textTheme.bodyMedium?.color?.withOpacity(
                          0.8,
                        ),
                      ),
                    ),
                    SizedBox(height: 20.h),
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.done,
                            style: GoogleFonts.roboto(),
                            decoration: InputDecoration(
                              labelText: TranslateService.tr('Email Address'),
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return '${TranslateService.tr('Please enter your ')}email';
                              }
                              if (!RegExp(
                                r'^[^@]+@[^@]+\.[^@]+',
                              ).hasMatch(v.trim())) {
                                return 'Masukkan email yang valid';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 18.h),
                          SizedBox(
                            width: double.infinity,
                            height: 50.h,
                            child: ElevatedButton(
                              onPressed: _sending ? null : _sendReset,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                                elevation: 2,
                              ),
                              child: _sending
                                  ? SizedBox(
                                      width: 20.r,
                                      height: 20.r,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.w,
                                      ),
                                    )
                                  : Text(
                                      TranslateService.tr('Send Reset Link'),
                                      style: GoogleFonts.roboto(
                                        fontSize: 16.sp,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black,
                                      ),
                                    ),
                            ),
                          ),
                          SizedBox(height: 12.h),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(
                              TranslateService.tr('Cancel'),
                              style: GoogleFonts.roboto(
                                color: theme.textTheme.bodyMedium?.color
                                    ?.withOpacity(0.7),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
