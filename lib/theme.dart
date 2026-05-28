import 'package:flutter/material.dart';

// ── Color palette ─────────────────────────────────────────────────────────────
// "Quantum Void" — deep space dark with electric cyan + violet accents.

class AppColors {
  AppColors._();

  // Backgrounds — layers of depth
  static const Color bgBase = Color(0xFF070B12); // deepest background
  static const Color bgSurface = Color(0xFF0D1628); // cards, sheets
  static const Color bgElevated = Color(0xFF132038); // modals, bottom sheets
  static const Color bgInput = Color(0xFF0A1220); // text field fill

  // Accent — primary actions
  static const Color cyan = Color(0xFF00C8FA); // electric cyan
  static const Color cyanDim = Color(0xFF0097C4); // subdued cyan
  static const Color cyanGlow = Color(0x3300C8FA); // glow shadow

  // Accent — secondary / highlights
  static const Color violet = Color(0xFF8B5CF6); // deep violet
  static const Color violetDim = Color(0xFF6D3DD3);
  static const Color violetGlow = Color(0x338B5CF6);

  // Semantic
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFF43F5E);

  // Text
  static const Color textPrimary = Color(0xFFE2EAFF); // near white, slight blue
  static const Color textSecondary = Color(0xFF5B7399); // muted blue-grey
  static const Color textHint = Color(0xFF324060); // very muted

  // Borders
  static const Color borderSubtle = Color(0xFF1A2847); // barely visible
  static const Color borderMid = Color(0xFF243660); // hover/focus

  // File type colors
  static const Color fileImage = cyan;
  static const Color fileVideo = violet;
  static const Color filePdf = Color(0xFFF59E0B); // amber
  static const Color fileGeneric = Color(0xFF5B7399); // muted
}

// ── Theme ─────────────────────────────────────────────────────────────────────

class AppTheme {
  AppTheme._();

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.bgBase,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.cyan,
        secondary: AppColors.violet,
        surface: AppColors.bgSurface,
        error: AppColors.error,
        onPrimary: AppColors.bgBase,
        onSurface: AppColors.textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bgBase,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.bgElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.bgElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.bgInput,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.cyan, width: 1.5),
        ),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        hintStyle: const TextStyle(color: AppColors.textHint),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: AppColors.textPrimary, fontSize: 15),
        bodyMedium: TextStyle(color: AppColors.textPrimary, fontSize: 14),
        bodySmall: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        titleLarge: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      iconTheme: const IconThemeData(color: AppColors.textSecondary),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderSubtle,
        thickness: 0.5,
      ),
      listTileTheme: const ListTileThemeData(
        textColor: AppColors.textPrimary,
        iconColor: AppColors.textSecondary,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.bgElevated,
        contentTextStyle: const TextStyle(color: AppColors.textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Reusable gradient — cyan left, violet right
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [AppColors.cyan, AppColors.violet],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  // Card/surface decoration
  static BoxDecoration surfaceCard({
    double radius = 14,
    bool glowCyan = false,
  }) {
    return BoxDecoration(
      color: AppColors.bgSurface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: AppColors.borderSubtle, width: 0.5),
      boxShadow: glowCyan
          ? [
              BoxShadow(
                color: AppColors.cyanGlow,
                blurRadius: 12,
                spreadRadius: 0,
              ),
            ]
          : null,
    );
  }

  // Folder card — subtle cyan tint gradient
  static BoxDecoration folderCard() {
    return BoxDecoration(
      gradient: LinearGradient(
        colors: [AppColors.cyan.withOpacity(0.08), AppColors.bgSurface],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.cyan.withOpacity(0.18), width: 0.5),
    );
  }
}

// ── File type helpers ─────────────────────────────────────────────────────────

class FileTypeHelper {
  FileTypeHelper._();

  static bool isImage(String name) {
    final ext = name.toLowerCase().split('.').last;
    return ['jpg', 'jpeg', 'png', 'gif'].contains(ext);
  }

  static bool isVideo(String name) {
    final ext = name.toLowerCase().split('.').last;
    return ['mp4', 'mov'].contains(ext);
  }

  static bool isPdf(String name) => name.toLowerCase().endsWith('.pdf');

  static bool isPreviewable(String name) =>
      isImage(name) || isVideo(name) || isPdf(name);

  static Color getColor(String name) {
    if (isImage(name)) return AppColors.fileImage;
    if (isVideo(name)) return AppColors.fileVideo;
    if (isPdf(name)) return AppColors.filePdf;
    return AppColors.fileGeneric;
  }

  static IconData getIcon(String name) {
    if (isImage(name)) return Icons.image_outlined;
    if (isVideo(name)) return Icons.videocam_outlined;
    if (isPdf(name)) return Icons.picture_as_pdf_outlined;
    return Icons.insert_drive_file_outlined;
  }
}
