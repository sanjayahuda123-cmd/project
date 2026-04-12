import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:camera/camera.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:transignition/service/translate_service.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:transignition/constants/api_config.dart';

class FaceRegistrationPage extends StatefulWidget {
  const FaceRegistrationPage({super.key});

  @override
  State<FaceRegistrationPage> createState() => _FaceRegistrationPageState();
}

class _FaceRegistrationPageState extends State<FaceRegistrationPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _scanController;
  late Animation<double> _scanAnimation;
  bool _isRegistered = false;
  int _progress = 0;
  String _currentInstruction = TranslateService.tr('Look straight...');

  CameraController? _cameraController;
  bool _isCameraInitialized = false;

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _scanAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanController, curve: Curves.easeInOut),
    );

    _initCameraAndRegister();
  }

  Future<void> _initCameraAndRegister() async {
    try {
      final cameras = await availableCameras();

      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      if (!mounted) return;

      setState(() {
        _isCameraInitialized = true;
      });

      final List<String> instructions = [
        TranslateService.tr('Look straight...'),
        TranslateService.tr('Turn left slowly...'),
        TranslateService.tr('Turn right slowly...'),
        TranslateService.tr('Look up slightly...'),
        TranslateService.tr('Look down slightly...'),
      ];

      final List<XFile> capturedFaces = [];

      for (int i = 0; i < 5; i++) {
        if (!mounted) return;
        setState(() {
          _currentInstruction = instructions[i];
          _progress = (i + 1) * 20;
        });
        await Future.delayed(const Duration(milliseconds: 1000));
        final XFile file = await _cameraController!.takePicture();
        capturedFaces.add(file);
      }

      if (!mounted) return;
      setState(() {
        _currentInstruction = TranslateService.tr('Uploading and Training...');
      });

      // Send to FastAPI Backend
      final user = FirebaseAuth.instance.currentUser;
      final username = user?.uid ?? 'unknown_user';

      final request = http.MultipartRequest(
        'POST',
        Uri.parse(ApiConfig.registerEndpoint),
      );
      request.fields['username'] = username;

      for (var file in capturedFaces) {
        request.files.add(
          await http.MultipartFile.fromPath('files', file.path),
        );
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200) {
        throw Exception('API Error: ${response.body}');
      }

      if (!mounted) return;
      setState(() {
        _isRegistered = true;
      });
      _scanController.stop();

      // Flash valid color, then go back or proceed
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;

      // We pop to the first route (dashboard) when done.
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              TranslateService.tr('Face registration failed: $e'),
              style: GoogleFonts.roboto(),
            ),
          ),
        );
        Navigator.of(context).pop();
      }
    }
  }

  @override
  void dispose() {
    _scanController.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          TranslateService.tr('Face Registration'),
          style: GoogleFonts.roboto(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(height: 40.h),
            Text(
              _isRegistered
                  ? TranslateService.tr('Registration Complete')
                  : "${TranslateService.tr('Scanning face...')} $_progress%",
              style: GoogleFonts.roboto(
                color: _isRegistered ? Colors.greenAccent : Colors.white70,
                fontSize: 18.sp,
                fontWeight: _isRegistered ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            SizedBox(height: 12.h),
            if (!_isRegistered)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 40.w),
                child: LinearProgressIndicator(
                  value: _progress / 100,
                  backgroundColor: Colors.grey.shade800,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    colorScheme.primary,
                  ),
                  minHeight: 6.h,
                  borderRadius: BorderRadius.circular(3.r),
                ),
              ),
            SizedBox(height: 40.h),

            // Camera scanner implementation
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Camera Feed (Circularly Clipped)
                  Container(
                    width: 280.r,
                    height: 280.r,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey.shade900,
                      border: Border.all(
                        color: _isRegistered
                            ? Colors.greenAccent
                            : colorScheme.primary,
                        width: 4.r,
                      ),
                    ),
                    child: ClipOval(
                      child: _isCameraInitialized && _cameraController != null
                          ? SizedBox(
                              width: 280.r,
                              height: 280.r,
                              child: Transform.scale(
                                scale: 1.3,
                                child: Center(
                                  child: CameraPreview(_cameraController!),
                                ),
                              ),
                            )
                          : Center(
                              child: Icon(
                                _isRegistered
                                    ? Icons.check_circle_outline_rounded
                                    : Icons.face_retouching_natural_rounded,
                                size: 80.r,
                                color: _isRegistered
                                    ? Colors.greenAccent
                                    : Colors.white24,
                              ),
                            ),
                    ),
                  ),

                  // Holographic Scanning Line
                  if (!_isRegistered && _isCameraInitialized)
                    AnimatedBuilder(
                      animation: _scanAnimation,
                      builder: (context, child) {
                        return Positioned(
                          top: 280.r * _scanAnimation.value,
                          child: child!,
                        );
                      },
                      child: Container(
                        width: 260.w,
                        height: 4.h,
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          borderRadius: BorderRadius.circular(2.r),
                          boxShadow: [
                            BoxShadow(
                              color: colorScheme.primary.withOpacity(0.6),
                              blurRadius: 10.r,
                              spreadRadius: 2.r,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const Spacer(),

            if (_isRegistered)
              Padding(
                padding: EdgeInsets.only(bottom: 60.h),
                child: Text(
                  TranslateService.tr('Face data successfully saved!'),
                  style: GoogleFonts.roboto(
                    color: Colors.greenAccent,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            else
              Padding(
                padding: EdgeInsets.only(bottom: 60.h),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 24.r,
                      height: 24.r,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white54,
                      ),
                    ),
                    SizedBox(width: 16.w),
                    Flexible(
                      child: Text(
                        _isCameraInitialized
                            ? _currentInstruction
                            : TranslateService.tr('Preparing camera...'),
                        style: GoogleFonts.roboto(
                          color: Colors.white54,
                          fontSize: 16.sp,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
