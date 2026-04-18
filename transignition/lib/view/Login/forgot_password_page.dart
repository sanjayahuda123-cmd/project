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
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Stack(
        children: [
          // Background subtle gradient/blob for Material You feel
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300.r,
              height: 300.r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.primaryContainer.withOpacity(0.2),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 20.h),
                  IconButton.filledTonal(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back),
                    style: IconButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.only(
                          bottom: MediaQuery.of(context).viewInsets.bottom + 20.h,
                        ),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: 400.w),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: EdgeInsets.all(24.r),
                                decoration: BoxDecoration(
                                  color: colorScheme.secondaryContainer,
                                  borderRadius: BorderRadius.circular(28.r),
                                ),
                                child: Icon(
                                  Icons.lock_reset_rounded,
                                  color: colorScheme.onSecondaryContainer,
                                  size: 48.r,
                                ),
                              ),
                              SizedBox(height: 32.h),
                              Text(
                                TranslateService.tr('Forgot Password?'),
                                style: theme.textTheme.displaySmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 12.h),
                              Text(
                                TranslateService.tr(
                                  'No worries! Enter your email address and we will send you a reset link.',
                                ),
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  height: 1.5,
                                ),
                              ),
                              SizedBox(height: 40.h),
                              Form(
                                key: _formKey,
                                child: Column(
                                  children: [
                                    TextFormField(
                                      controller: _emailCtrl,
                                      keyboardType: TextInputType.emailAddress,
                                      textInputAction: TextInputAction.done,
                                      decoration: InputDecoration(
                                        labelText: TranslateService.tr('Email Address'),
                                        hintText: 'example@email.com',
                                        prefixIcon: const Icon(Icons.email_outlined),
                                        filled: true,
                                        fillColor: colorScheme.surfaceVariant.withOpacity(0.3),
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
                                          borderSide: BorderSide(
                                            color: colorScheme.primary,
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                      validator: (v) {
                                        if (v == null || v.trim().isEmpty) {
                                          return '${TranslateService.tr('Please enter your ')}email';
                                        }
                                        if (!RegExp(
                                          r'^[^@]+@[^@]+\.[^@]+',
                                        ).hasMatch(v.trim())) {
                                          return TranslateService.tr('Please enter a valid email');
                                        }
                                        return null;
                                      },
                                    ),
                                    SizedBox(height: 32.h),
                                    SizedBox(
                                      width: double.infinity,
                                      height: 56.h,
                                      child: FilledButton(
                                        onPressed: _sending ? null : _sendReset,
                                        style: FilledButton.styleFrom(
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(16.r),
                                          ),
                                        ),
                                        child: _sending
                                            ? SizedBox(
                                                width: 24.r,
                                                height: 24.r,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 3.w,
                                                  color: colorScheme.onPrimary,
                                                ),
                                              )
                                            : Text(
                                                TranslateService.tr('Send Reset Link'),
                                                style: GoogleFonts.roboto(
                                                  fontSize: 16.sp,
                                                  fontWeight: FontWeight.bold,
                                                ),
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

