import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:transignition/service/translate_service.dart';

class FisherfaceStatsPage extends StatelessWidget {
  const FisherfaceStatsPage({super.key});

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
      ),
      body: SafeArea(
        child: SingleChildScrollView(
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
                      value: "96.5%",
                      icon: Icons.check_circle_outline_rounded,
                      color: Colors.green,
                    ),
                  ),
                  SizedBox(width: 16.w),
                  Expanded(
                    child: _buildStatCard(
                      context: context,
                      title: TranslateService.tr('Error Rate'),
                      value: "3.5%",
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
                      value: "1.2s",
                      icon: Icons.speed_rounded,
                      color: Colors.blueAccent,
                    ),
                  ),
                  SizedBox(width: 16.w),
                  Expanded(
                    child: _buildStatCard(
                      context: context,
                      title: TranslateService.tr('Threshold'),
                      value: "3500",
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
                "45",
                Icons.verified_user_rounded,
              ),
              const SizedBox(height: 12),
              _buildMatrixRow(
                context,
                TranslateService.tr('True Negatives (TN)'),
                "42",
                Icons.gpp_good_rounded,
              ),
              const SizedBox(height: 12),
              _buildMatrixRow(
                context,
                TranslateService.tr('False Positives (FP)'),
                "2",
                Icons.warning_amber_rounded,
              ),
              const SizedBox(height: 12),
              _buildMatrixRow(
                context,
                TranslateService.tr('False Negatives (FN)'),
                "1",
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
                0.95,
              ),
              const SizedBox(height: 12),
              _buildProgressIndicator(
                context,
                TranslateService.tr('Recall'),
                0.97,
              ),
              const SizedBox(height: 12),
              _buildProgressIndicator(
                context,
                TranslateService.tr('F1 Score'),
                0.96,
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
