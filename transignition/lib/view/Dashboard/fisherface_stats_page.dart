import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:transignition/service/translate_service.dart';
import 'package:transignition/constants/api_config.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class FisherfaceStatsPage extends StatefulWidget {
  const FisherfaceStatsPage({super.key});

  @override
  State<FisherfaceStatsPage> createState() => _FisherfaceStatsPageState();
}

class _FisherfaceStatsPageState extends State<FisherfaceStatsPage> {
  bool _isLoading = true;
  Map<String, dynamic>? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchEvaluationData();
  }

  Future<void> _fetchEvaluationData() async {
    try {
      final response = await http.get(Uri.parse(ApiConfig.evaluationEndpoint));
      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['status'] == 'success') {
          setState(() {
            _data = result;
            _isLoading = false;
          });
        } else {
          setState(() {
            _error = result['message'];
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _error = "Server Error: ${response.statusCode}";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = "Connection Error: $e";
        _isLoading = false;
      });
    }
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
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        title: Text(
          TranslateService.tr('Fisherface Evaluation'),
          style: GoogleFonts.roboto(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _isLoading ? null : () {
              setState(() => _isLoading = true);
              _fetchEvaluationData();
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.roboto(color: colorScheme.error),
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    padding: EdgeInsets.all(24.r),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          TranslateService.tr('Algorithm Performance'),
                          style: GoogleFonts.roboto(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        SizedBox(height: 16.h),
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                context: context,
                                title: TranslateService.tr('Accuracy'),
                                value: _data?['accuracy'] ?? "0%",
                                icon: Icons.check_circle_outline_rounded,
                                color: Colors.green,
                              ),
                            ),
                            SizedBox(width: 16.w),
                            Expanded(
                              child: _buildStatCard(
                                context: context,
                                title: TranslateService.tr('Error Rate'),
                                value: _data?['error_rate'] ?? "0%",
                                icon: Icons.error_outline_rounded,
                                color: Colors.redAccent,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16.h),
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                context: context,
                                title: TranslateService.tr('Avg Time'),
                                value: _data?['avg_time'] ?? "0s",
                                icon: Icons.speed_rounded,
                                color: Colors.blueAccent,
                              ),
                            ),
                            SizedBox(width: 16.w),
                            Expanded(
                              child: _buildStatCard(
                                context: context,
                                title: TranslateService.tr('Threshold'),
                                value: _data?['threshold'] ?? "0",
                                icon: Icons.tune_rounded,
                                color: Colors.orangeAccent,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 32.h),
                        Text(
                          TranslateService.tr('Confusion Matrix Details'),
                          style: GoogleFonts.roboto(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildMatrixRow(
                          context,
                          TranslateService.tr('True Positives (TP)'),
                          "${_data?['tp'] ?? 0}",
                          Icons.verified_user_rounded,
                        ),
                        const SizedBox(height: 12),
                        _buildMatrixRow(
                          context,
                          TranslateService.tr('True Negatives (TN)'),
                          "${_data?['tn'] ?? 0}",
                          Icons.gpp_good_rounded,
                        ),
                        const SizedBox(height: 12),
                        _buildMatrixRow(
                          context,
                          TranslateService.tr('False Positives (FP)'),
                          "${_data?['fp'] ?? 0}",
                          Icons.warning_amber_rounded,
                        ),
                        const SizedBox(height: 12),
                        _buildMatrixRow(
                          context,
                          TranslateService.tr('False Negatives (FN)'),
                          "${_data?['fn'] ?? 0}",
                          Icons.highlight_off_rounded,
                        ),
                        SizedBox(height: 32.h),
                        Text(
                          TranslateService.tr('Metric Scores'),
                          style: GoogleFonts.roboto(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        SizedBox(height: 16.h),
                        _buildProgressIndicator(
                          context,
                          TranslateService.tr('Precision'),
                          (_data?['precision'] ?? 0).toDouble(),
                        ),
                        const SizedBox(height: 12),
                        _buildProgressIndicator(
                          context,
                          TranslateService.tr('Recall'),
                          (_data?['recall'] ?? 0).toDouble(),
                        ),
                        const SizedBox(height: 12),
                        _buildProgressIndicator(
                          context,
                          TranslateService.tr('F1 Score'),
                          (_data?['f1_score'] ?? 0).toDouble(),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildStatCard({
    required BuildContext context,
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28.r),
          SizedBox(height: 12.h),
          Text(
            value,
            style: GoogleFonts.roboto(
              fontSize: 24.sp,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            title,
            style: GoogleFonts.roboto(
              fontSize: 13.sp,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatrixRow(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 20.r, color: colorScheme.primary),
              SizedBox(width: 12.w),
              Text(
                label,
                style: GoogleFonts.roboto(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          Text(
            value,
            style: GoogleFonts.roboto(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(
    BuildContext context,
    String label,
    double value,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: GoogleFonts.roboto(
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              "${(value * 100).toStringAsFixed(1)}%",
              style: GoogleFonts.roboto(
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        SizedBox(height: 8.h),
        LinearProgressIndicator(
          value: value,
          backgroundColor: colorScheme.surfaceContainerHighest,
          color: colorScheme.primary,
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }
}
