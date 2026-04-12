import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:transignition/view/Dashboard/fisherface_stats_page.dart';
import 'package:transignition/view/Dashboard/setting_account_page.dart';
import 'package:transignition/view/Dashboard/face_scan_page.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:transignition/service/translate_service.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with SingleTickerProviderStateMixin {
  bool _isEngineOn = false;
  bool _isLocked = true;
  bool _isEspConnected = false;
  final TextEditingController _simController = TextEditingController();

  // Animation controller for the power button glowing/breathing effect
  late AnimationController _breathingController;
  late Animation<double> _breathingAnimation;

  @override
  void initState() {
    super.initState();
    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _breathingAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _breathingController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _breathingController.dispose();
    _simController.dispose();
    super.dispose();
  }

  void _toggleEngine() {
    if (_isLocked && !_isEngineOn) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            TranslateService.tr('Unlock your motorcycle first!'),
            style: GoogleFonts.roboto(),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() {
      _isEngineOn = !_isEngineOn;
    });
  }

  void _toggleLock() async {
    if (_isEngineOn) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            TranslateService.tr('Turn off the engine to lock the motorcycle.'),
            style: GoogleFonts.roboto(),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_isLocked) {
      // Trying to unlock, require Face Scan!
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const FaceScanPage()),
      );

      // If face scan is successful
      if (result == true) {
        setState(() {
          _isLocked = false;
          _isEngineOn = true; // explicitly "maka engine on"
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              TranslateService.tr('Face Recognized. Unlocked & Engine On.'),
              style: GoogleFonts.roboto(),
            ),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      // Locking is instant without camera scan validation
      setState(() {
        _isLocked = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            TranslateService.tr('Motorcycle structure Locked.'),
            style: GoogleFonts.roboto(),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    final user = FirebaseAuth.instance.currentUser;
    final name = (user?.displayName ?? "").split(' ').first;
    final greeting = _getTimeGreeting(hour);

    return name.isEmpty ? greeting : "$greeting, $name";
  }

  String _getTimeGreeting(int hour) {
    if (hour >= 3 && hour < 11) {
      return TranslateService.tr('Good Morning');
    } else if (hour >= 11 && hour < 15) {
      return TranslateService.tr('Good Afternoon');
    } else if (hour >= 15 && hour < 18) {
      return TranslateService.tr('Good Evening');
    } else {
      return TranslateService.tr('Good Night');
    }
  }

  void _showEspConnectionBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final colorScheme = Theme.of(context).colorScheme;
        return Container(
          padding: EdgeInsets.only(
            top: 24.h,
            left: 24.w,
            right: 24.w,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24.h,
          ),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              SizedBox(height: 24.h),
              Icon(
                Icons.sim_card_rounded,
                size: 48.r,
                color: colorScheme.primary,
              ),
              SizedBox(height: 16.h),
              Text(
                TranslateService.tr('Connect to ESP32'),
                style: GoogleFonts.roboto(
                  fontSize: 22.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                TranslateService.tr(
                  "Enter the SIM card number or Device ID to establish a connection with the motorcycle's module.",
                ),
                textAlign: TextAlign.center,
                style: GoogleFonts.roboto(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _simController,
                keyboardType: TextInputType.phone,
                style: GoogleFonts.roboto(),
                decoration: InputDecoration(
                  labelText: TranslateService.tr('SIM Number / ESP32 ID'),
                  prefixIcon: const Icon(Icons.dialpad_rounded),
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest.withOpacity(
                    0.5,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16.r),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              SizedBox(height: 24.h),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    // Simulate connection logic
                    Navigator.pop(ctx);
                    setState(() {
                      _isEspConnected = true;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          TranslateService.tr(
                            'Connected to TransIgnition GSM module',
                          ),
                          style: GoogleFonts.roboto(),
                        ),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  style: FilledButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 16.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100.r),
                    ),
                  ),
                  child: Text(
                    TranslateService.tr('Connect Device'),
                    style: GoogleFonts.roboto(
                      fontWeight: FontWeight.bold,
                      fontSize: 16.sp,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickActionCard({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24.r),
          child: Ink(
            padding: EdgeInsets.symmetric(vertical: 20.h, horizontal: 8.w),
            decoration: BoxDecoration(
              color: isActive
                  ? colorScheme.primaryContainer
                  : colorScheme.surfaceContainerHighest.withOpacity(0.5),
              borderRadius: BorderRadius.circular(24.r),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: isActive
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurfaceVariant,
                  size: 28.r,
                ),
                SizedBox(height: 12.h),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.roboto(
                    color: isActive
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    fontSize: 13.sp,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIgnitionButton(ColorScheme colorScheme) {
    Color glowColor = _isEngineOn
        ? colorScheme.primary.withOpacity(0.4)
        : Colors.transparent;
    Color buttonColor = _isEngineOn
        ? colorScheme.primary
        : colorScheme.surfaceContainerHighest;
    Color iconColor = _isEngineOn
        ? colorScheme.onPrimary
        : colorScheme.onSurfaceVariant;

    return GestureDetector(
      onTap: _toggleEngine,
      child: AnimatedBuilder(
        animation: _breathingAnimation,
        child: Container(
          width: 180.r,
          height: 180.r,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: buttonColor,
            boxShadow: _isEngineOn
                ? [
                    BoxShadow(
                      color: glowColor,
                      blurRadius: 30.r,
                      spreadRadius: 10.r,
                    ),
                  ]
                : const [],
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.power_settings_new_rounded,
                  size: 64.r,
                  color: iconColor,
                ),
                SizedBox(height: 8.h),
                Text(
                  _isEngineOn
                      ? TranslateService.tr('ENGINE ON')
                      : TranslateService.tr('START'),
                  style: GoogleFonts.roboto(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: iconColor,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
        builder: (context, child) {
          return RepaintBoundary(
            child: Transform.scale(
              scale: _isEngineOn ? _breathingAnimation.value : 1.0,
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Padding(
          padding: EdgeInsets.only(left: 20.w),
          child: Center(
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SettingAccountPage(),
                  ),
                );
              },
              child: CircleAvatar(
                radius: 20,
                backgroundColor: colorScheme.primaryContainer,
                backgroundImage:
                    (FirebaseAuth.instance.currentUser?.photoURL != null &&
                        FirebaseAuth.instance.currentUser!.photoURL!.isNotEmpty)
                    ? NetworkImage(FirebaseAuth.instance.currentUser!.photoURL!)
                    : null,
                child:
                    (FirebaseAuth.instance.currentUser?.photoURL == null ||
                        FirebaseAuth.instance.currentUser!.photoURL!.isEmpty)
                    ? Icon(
                        Icons.person_rounded,
                        color: colorScheme.onPrimaryContainer,
                        size: 22,
                      )
                    : null,
              ),
            ),
          ),
        ),
        title: Text(
          _getGreeting(),
          style: GoogleFonts.roboto(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.settings_rounded, color: colorScheme.onSurface),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingAccountPage(),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 16.h),
              // Status Card (Now clickable for ESP32 Connection)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _showEspConnectionBottomSheet,
                  borderRadius: BorderRadius.circular(24.r),
                  child: Ink(
                    padding: EdgeInsets.all(20.r),
                    decoration: BoxDecoration(
                      color: _isEspConnected
                          ? colorScheme.secondaryContainer
                          : colorScheme.errorContainer.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(24.r),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(12.r),
                          decoration: BoxDecoration(
                            color: _isEspConnected
                                ? colorScheme.onSecondaryContainer.withOpacity(
                                    0.1,
                                  )
                                : colorScheme.onErrorContainer.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _isEspConnected
                                ? Icons.cell_tower_rounded
                                : Icons
                                      .signal_cellular_connected_no_internet_0_bar_rounded,
                            color: _isEspConnected
                                ? colorScheme.onSecondaryContainer
                                : colorScheme.onErrorContainer,
                          ),
                        ),
                        SizedBox(width: 16.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                TranslateService.tr('Status'),
                                style: GoogleFonts.roboto(
                                  fontSize: 14.sp,
                                  color:
                                      (_isEspConnected
                                              ? colorScheme.onSecondaryContainer
                                              : colorScheme.onErrorContainer)
                                          .withOpacity(0.8),
                                ),
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                _isEspConnected
                                    ? TranslateService.tr('Connected to ESP32')
                                    : TranslateService.tr('Tap to connect'),
                                style: GoogleFonts.roboto(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.bold,
                                  color: _isEspConnected
                                      ? colorScheme.onSecondaryContainer
                                      : colorScheme.onErrorContainer,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Battery indicator
                        if (_isEspConnected)
                          Column(
                            children: [
                              Icon(
                                Icons.battery_5_bar_rounded,
                                color: colorScheme.onSecondaryContainer,
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                "85%",
                                style: GoogleFonts.roboto(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSecondaryContainer,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const Spacer(),

              // Giant Ignition Button
              Center(child: _buildIgnitionButton(colorScheme)),

              const Spacer(),

              // Action Cards (Lock/Unlock, Algorithm Stats)
              Row(
                children: [
                  _buildQuickActionCard(
                    context: context,
                    icon: _isLocked
                        ? Icons.lock_rounded
                        : Icons.lock_open_rounded,
                    label: _isLocked
                        ? TranslateService.tr('Locked')
                        : TranslateService.tr('Unlocked'),
                    isActive: !_isLocked,
                    onTap: _toggleLock,
                  ),
                  const SizedBox(width: 16),
                  _buildQuickActionCard(
                    context: context,
                    icon: Icons.analytics_rounded,
                    label: TranslateService.tr('Evaluation'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const FisherfaceStatsPage(),
                        ),
                      );
                    },
                  ),
                ],
              ),
              SizedBox(height: 40.h),
            ],
          ),
        ),
      ),
    );
  }
}
