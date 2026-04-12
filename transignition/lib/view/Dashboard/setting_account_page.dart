import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import 'package:transignition/main.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:transignition/view/Dashboard/face_registration_page.dart';
import 'package:transignition/service/translate_service.dart';

class SettingAccountPage extends StatefulWidget {
  const SettingAccountPage({super.key});

  @override
  State<SettingAccountPage> createState() => _SettingAccountPageState();
}

class _SettingAccountPageState extends State<SettingAccountPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _usernameController;
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isUploadingPhoto = false;

  // Local selected image before upload
  File? _selectedImage;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    _usernameController = TextEditingController(text: user?.displayName ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ──────────────────────────────────────────────
  // PHOTO PICKER
  // ──────────────────────────────────────────────

  Future<void> _pickAndUploadPhoto(ImageSource source) async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (picked == null) return;

    setState(() {
      _selectedImage = File(picked.path);
      _isUploadingPhoto = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Upload to Firebase Storage: profile_photos/<uid>.jpg
      final ref = FirebaseStorage.instance
          .ref()
          .child('profile_photos')
          .child('${user.uid}.jpg');

      await ref.putFile(
        _selectedImage!,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final downloadUrl = await ref.getDownloadURL();
      await user.updatePhotoURL(downloadUrl);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              TranslateService.tr('Profile photo updated!'),
              style: GoogleFonts.roboto(),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        // Refresh UI
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${TranslateService.tr('Failed to upload photo:')} $e',
              style: GoogleFonts.roboto(),
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (ctx) {
        final colorScheme = Theme.of(context).colorScheme;
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 24.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                ),
                SizedBox(height: 20.h),
                Text(
                  TranslateService.tr('Change Profile Photo'),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.roboto(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                SizedBox(height: 20.h),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: colorScheme.primaryContainer,
                    child: Icon(
                      Icons.photo_library_rounded,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                  title: Text(
                    TranslateService.tr('Choose from Gallery'),
                    style: GoogleFonts.roboto(fontWeight: FontWeight.w500),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAndUploadPhoto(ImageSource.gallery);
                  },
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: colorScheme.secondaryContainer,
                    child: Icon(
                      Icons.camera_alt_rounded,
                      color: colorScheme.onSecondaryContainer,
                    ),
                  ),
                  title: Text(
                    TranslateService.tr('Take Photo'),
                    style: GoogleFonts.roboto(fontWeight: FontWeight.w500),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAndUploadPhoto(ImageSource.camera);
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  // ──────────────────────────────────────────────
  // SAVE PROFILE
  // ──────────────────────────────────────────────

  Future<void> _saveProfile() async {
    if (_formKey.currentState?.validate() ?? false) {
      FocusScope.of(context).unfocus();
      setState(() => _isLoading = true);

      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          if (_usernameController.text.trim() != user.displayName) {
            await user.updateDisplayName(_usernameController.text.trim());
          }
          if (_emailController.text.trim() != user.email) {
            await user.verifyBeforeUpdateEmail(_emailController.text.trim());
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    TranslateService.tr(
                      'A verification email has been sent. Please verify your new email.',
                    ),
                    style: GoogleFonts.roboto(),
                  ),
                ),
              );
            }
          }
          if (_passwordController.text.isNotEmpty) {
            await user.updatePassword(_passwordController.text);
            _passwordController.clear();
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  TranslateService.tr('Profile updated successfully'),
                  style: GoogleFonts.roboto(),
                ),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      } on FirebaseAuthException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                e.message ?? TranslateService.tr('An error occurred'),
                style: GoogleFonts.roboto(),
              ),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  // ──────────────────────────────────────────────
  // HELPERS
  // ──────────────────────────────────────────────

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffix,
    String? Function(String?)? validator,
  }) {
    final theme = Theme.of(context);
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: GoogleFonts.roboto(),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.roboto(),
        prefixIcon: Icon(icon),
        suffixIcon: suffix,
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.4,
        ),
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
      ),
      validator:
          validator ??
          (value) {
            if (value == null || value.trim().isEmpty) {
              return '${TranslateService.tr('Please enter your ')}$label';
            }
            return null;
          },
    );
  }

  // ──────────────────────────────────────────────
  // BUILD
  // ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final user = FirebaseAuth.instance.currentUser;

    // Determine avatar widget: local file > Firebase photoURL > icon placeholder
    Widget avatarChild;
    if (_selectedImage != null && _isUploadingPhoto == false) {
      avatarChild = ClipOval(
        child: Image.file(
          _selectedImage!,
          width: 100.r,
          height: 100.r,
          fit: BoxFit.cover,
        ),
      );
    } else if (user?.photoURL != null && user!.photoURL!.isNotEmpty) {
      avatarChild = ClipOval(
        child: Image.network(
          user.photoURL!,
          width: 100.r,
          height: 100.r,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Icon(
            Icons.person_rounded,
            size: 60.r,
            color: colorScheme.onPrimaryContainer,
          ),
        ),
      );
    } else {
      avatarChild = Icon(
        Icons.person_rounded,
        size: 60.r,
        color: colorScheme.onPrimaryContainer,
      );
    }

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          TranslateService.tr('Settings & Profile'),
          style: GoogleFonts.roboto(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Profile Avatar ──
              Center(
                child: GestureDetector(
                  onTap: _isUploadingPhoto ? null : _showPhotoOptions,
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        width: 100.r,
                        height: 100.r,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colorScheme.primaryContainer,
                          border: Border.all(
                            color: colorScheme.primary,
                            width: 2.5.w,
                          ),
                        ),
                        child: _isUploadingPhoto
                            ? Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5.w,
                                  color: colorScheme.primary,
                                ),
                              )
                            : avatarChild,
                      ),
                      Container(
                        padding: EdgeInsets.all(6.r),
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: colorScheme.surface,
                            width: 2.w,
                          ),
                        ),
                        child: Icon(
                          Icons.camera_alt_rounded,
                          size: 18.r,
                          color: colorScheme.onPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 8.h),
              Center(
                child: Text(
                  TranslateService.tr('Tap to change photo'),
                  style: GoogleFonts.roboto(
                    fontSize: 12.sp,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              SizedBox(height: 32.h),

              // ── Edit Profile ──
              Text(
                TranslateService.tr('Edit Profile'),
                style: GoogleFonts.roboto(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildTextField(
                      controller: _usernameController,
                      label: TranslateService.tr('Username'),
                      icon: Icons.person_outline,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _emailController,
                      label: TranslateService.tr('Email Address'),
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _passwordController,
                      label: TranslateService.tr('New Password (Optional)'),
                      icon: Icons.lock_outline,
                      obscureText: _obscurePassword,
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
                        if (value != null &&
                            value.isNotEmpty &&
                            value.length < 6) {
                          return TranslateService.tr(
                            'Password must be at least 6 characters',
                          );
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 24.h),
                    FilledButton(
                      onPressed: _isLoading ? null : _saveProfile,
                      style: FilledButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16.h),
                        minimumSize: Size.fromHeight(50.h),
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
                              TranslateService.tr('Save Changes'),
                              style: GoogleFonts.roboto(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 48),

              // ── Face Registration ──
              Text(
                TranslateService.tr('Face Registration'),
                style: GoogleFonts.roboto(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: EdgeInsets.all(8.r),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.face_retouching_natural_rounded,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                title: Text(
                  TranslateService.tr('Register Face Data'),
                  style: GoogleFonts.roboto(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  TranslateService.tr('Add or update your face data'),
                  style: GoogleFonts.roboto(),
                ),
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: colorScheme.onSurface,
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const FaceRegistrationPage(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),

              // ── Appearance ──
              Text(
                TranslateService.tr('Appearance'),
                style: GoogleFonts.roboto(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: ValueListenableBuilder<ThemeMode>(
                  valueListenable: themeNotifier,
                  builder: (context, currentTheme, _) {
                    return Column(
                      children: [
                        _buildThemeOption(
                          title: TranslateService.tr('System Default'),
                          icon: Icons.brightness_auto_rounded,
                          value: ThemeMode.system,
                          groupValue: currentTheme,
                        ),
                        Divider(
                          height: 1,
                          indent: 64,
                          color: colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.2,
                          ),
                        ),
                        _buildThemeOption(
                          title: TranslateService.tr('Light Mode'),
                          icon: Icons.light_mode_rounded,
                          value: ThemeMode.light,
                          groupValue: currentTheme,
                        ),
                        Divider(
                          height: 1,
                          indent: 64,
                          color: colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.2,
                          ),
                        ),
                        _buildThemeOption(
                          title: TranslateService.tr('Dark Mode'),
                          icon: Icons.dark_mode_rounded,
                          value: ThemeMode.dark,
                          groupValue: currentTheme,
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 32),

              // ── Language ──
              Text(
                TranslateService.tr('Language'),
                style: GoogleFonts.roboto(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: ValueListenableBuilder<String>(
                  valueListenable: languageNotifier,
                  builder: (context, currentLang, _) {
                    return Column(
                      children: [
                        _buildLanguageOption(
                          title: 'English',
                          icon: Icons.language_rounded,
                          value: 'en',
                          groupValue: currentLang,
                        ),
                        Divider(
                          height: 1,
                          indent: 64,
                          color: colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.2,
                          ),
                        ),
                        _buildLanguageOption(
                          title: 'Bahasa Indonesia',
                          icon: Icons.chat_bubble_outline_rounded,
                          value: 'id',
                          groupValue: currentLang,
                        ),
                      ],
                    );
                  },
                ),
              ),
              SizedBox(height: 32.h),

              // ── Logout ──
              FilledButton.icon(
                onPressed: () => _confirmLogout(context),
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.errorContainer,
                  foregroundColor: colorScheme.onErrorContainer,
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  minimumSize: Size.fromHeight(50.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(100.r),
                  ),
                ),
                icon: Icon(Icons.logout_rounded, size: 24.r),
                label: Text(
                  TranslateService.tr('Sign Out'),
                  style: GoogleFonts.roboto(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(height: 48.h),
            ],
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // RADIO OPTIONS
  // ──────────────────────────────────────────────

  Widget _buildThemeOption({
    required String title,
    required IconData icon,
    required ThemeMode value,
    required ThemeMode groupValue,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return RadioListTile<ThemeMode>(
      value: value,
      groupValue: groupValue,
      onChanged: (ThemeMode? newTheme) {
        if (newTheme != null) themeNotifier.value = newTheme;
      },
      title: Text(
        title,
        style: GoogleFonts.roboto(
          fontWeight: groupValue == value ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      secondary: Icon(
        icon,
        color: groupValue == value
            ? colorScheme.primary
            : colorScheme.onSurfaceVariant,
      ),
      activeColor: colorScheme.primary,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    );
  }

  Widget _buildLanguageOption({
    required String title,
    required IconData icon,
    required String value,
    required String groupValue,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return RadioListTile<String>(
      value: value,
      groupValue: groupValue,
      onChanged: (String? newLang) {
        if (newLang != null && newLang != groupValue) {
          languageNotifier.value = newLang;
          _showRestartDialog();
        }
      },
      title: Text(
        title,
        style: GoogleFonts.roboto(
          fontWeight: groupValue == value ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      secondary: Icon(
        icon,
        color: groupValue == value
            ? colorScheme.primary
            : colorScheme.onSurfaceVariant,
      ),
      activeColor: colorScheme.primary,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    );
  }

  // ──────────────────────────────────────────────
  // DIALOGS
  // ──────────────────────────────────────────────

  void _showRestartDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: Text(
            TranslateService.tr('Restart Required'),
            style: GoogleFonts.roboto(fontWeight: FontWeight.bold),
          ),
          content: Text(
            TranslateService.tr(
              'The app needs to be restarted for the language changes to take effect. Do you want to restart now?',
            ),
            style: GoogleFonts.roboto(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                TranslateService.tr('Later'),
                style: GoogleFonts.roboto(),
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              child: Text(
                TranslateService.tr('Restart Now'),
                style: GoogleFonts.roboto(),
              ),
            ),
          ],
        );
      },
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        final colorScheme = Theme.of(context).colorScheme;
        return AlertDialog(
          title: Text(
            TranslateService.tr('Logout'),
            style: GoogleFonts.roboto(fontWeight: FontWeight.bold),
          ),
          content: Text(
            TranslateService.tr(
              'Are you sure you want to sign out of your account?',
            ),
            style: GoogleFonts.roboto(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                TranslateService.tr('Cancel'),
                style: GoogleFonts.roboto(),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: colorScheme.error),
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await FirebaseAuth.instance.signOut();
                  // For GoogleSignIn v7.x, we should also sign out
                  final googleSignIn = GoogleSignIn.instance;
                  await googleSignIn.signOut();

                  // Instead of pushing, we pop until the root.
                  // The StreamBuilder in main.dart will then automatically
                  // switch from DashboardPage to LoginPage.
                  if (mounted) {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Logout failed: $e')),
                    );
                  }
                }
              },
              child: Text(
                'Logout',
                style: GoogleFonts.roboto(color: colorScheme.onError),
              ),
            ),
          ],
        );
      },
    );
  }
}
