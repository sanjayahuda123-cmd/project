import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:camera/camera.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:transignition/service/translate_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:transignition/constants/api_config.dart';
import 'package:screen_brightness/screen_brightness.dart';

class FaceScanPage extends StatefulWidget {
  const FaceScanPage({super.key});

  @override
  State<FaceScanPage> createState() => _FaceScanPageState();
}

class _FaceScanPageState extends State<FaceScanPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _scanController;
  late Animation<double> _scanAnimation;
  bool _isRecognized = false;

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

    _maximizeBrightness();
    _initCameraAndScan();
  }

  Future<void> _maximizeBrightness() async {
    try {
      await ScreenBrightness().setScreenBrightness(1.0);
    } catch (e) {
      debugPrint("Failed to set brightness: $e");
    }
  }

  Future<void> _resetBrightness() async {
    try {
      await ScreenBrightness().resetScreenBrightness();
    } catch (e) {
      debugPrint("Failed to reset brightness: $e");
    }
  }

  Future<void> _initCameraAndScan() async {
    try {
      final cameras = await availableCameras();

      // Attempt to secure the front camera, fallback to first available
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

      // Allow camera to stabilize and focus
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted || _cameraController == null || !_cameraController!.value.isInitialized) {
        debugPrint("Camera not ready or page unmounted.");
        return;
      }

      debugPrint("Attempting to take picture...");
      final XFile image = await _cameraController!.takePicture();
      debugPrint("Picture captured successfully: ${image.path}");

      // Send to FastAPI Backend
      debugPrint("Connecting to API: ${ApiConfig.recognizeEndpoint}");
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(ApiConfig.recognizeEndpoint),
      );
      request.files.add(await http.MultipartFile.fromPath('file', image.path));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200) {
        throw Exception('API Error: ${response.body}');
      }

      final data = json.decode(response.body);
      final user = FirebaseAuth.instance.currentUser;
      final currentUserId = user?.uid ?? '';
      
      // DEBUG LOG untuk melihat hasil deteksi di console
      debugPrint("API Response: $data");
      debugPrint("Current User ID: $currentUserId");

      bool identityMatched = false;
      if (data['status'] == 'success' && data['results'] != null) {
        for (var result in data['results']) {
          debugPrint("Detected Face: ${result['name']} | Confidence: ${result['confidence']}");

          // Fisherface confidence is distance (lower is closer/better)
          // Threshold 1000 adalah standar, bisa disesuaikan berdasarkan hasil tes
          // Kita naikkan nilai toleransinya ke 2500 untuk Fisherface (semakin kecil angkanya semakin mirip, jadi batas toleransi diperlebar)
          if (result['name'] == currentUserId &&
              result['confidence'] < 2500) {
            identityMatched = true;
            break;
          }
        }
      }

      if (!identityMatched) {
        throw Exception(
          TranslateService.tr('Face not recognized or identity mismatch.'),
        );
      }

      if (!mounted) return;
      setState(() {
        _isRecognized = true;
      });
      _scanController.stop();

      // Flash valid color, then jump back to Dashboard successfully
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              TranslateService.tr('Face scanning failed: $e'),
              style: GoogleFonts.roboto(),
            ),
          ),
        );
        Navigator.of(context).pop(false);
      }
    }
  }

  @override
  void dispose() {
    _resetBrightness();
    _scanController.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: Colors.black, // Sleek black backdrop
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          TranslateService.tr('Face Authentication'),
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
              _isRecognized
                  ? TranslateService.tr('Identity Confirmed')
                  : TranslateService.tr('Position your face within the frame'),
              style: GoogleFonts.roboto(
                color: _isRecognized ? Colors.greenAccent : Colors.white70,
                fontSize: 18.sp,
                fontWeight: _isRecognized ? FontWeight.bold : FontWeight.normal,
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
                        color: _isRecognized
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
                                scale:
                                    1.3, // slight zoom to completely cover circle
                                child: Center(
                                  child: CameraPreview(_cameraController!),
                                ),
                              ),
                            )
                          : Center(
                              child: Icon(
                                _isRecognized
                                    ? Icons.check_circle_outline_rounded
                                    : Icons.face_retouching_natural_rounded,
                                size: 80.r,
                                color: _isRecognized
                                    ? Colors.greenAccent
                                    : Colors.white24,
                              ),
                            ),
                    ),
                  ),

                  // Holographic Scanning Line
                  if (!_isRecognized && _isCameraInitialized)
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

            if (_isRecognized)
              Padding(
                padding: EdgeInsets.only(bottom: 60.h),
                child: Text(
                  TranslateService.tr('Opening TransIgnition...'),
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
                    Text(
                      _isCameraInitialized
                          ? TranslateService.tr('Scanning registered face...')
                          : TranslateService.tr('Preparing camera...'),
                      style: GoogleFonts.roboto(
                        color: Colors.white54,
                        fontSize: 16.sp,
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
