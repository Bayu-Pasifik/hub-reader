import 'package:flutter/material.dart';

/// Tema neo-brutalism: kertas krem, garis hitam tebal, sudut kotak, bayangan keras, warna blok tegas.
class NeoBrutal {
  NeoBrutal._();

  static const double border = 2.5;
  static const double radius = 6;
  static const Offset shadowOffset = Offset(4, 4);

  static const _ink = Color(0xFF111111);
  static const _paper = Color(0xFFFFF4D6);
  static const _yellow = Color(0xFFFFD93D);
  static const _mint = Color(0xFFA7F3D0);

  /// Warna garis & bayangan sesuai kecerahan.
  static Color ink(Brightness b) => b == Brightness.dark ? const Color(0xFFF5F0E1) : _ink;

  static BorderSide side(Brightness b, {double width = border}) => BorderSide(color: ink(b), width: width);

  static RoundedRectangleBorder shape(Brightness b, {double r = radius, double width = border}) =>
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(r), side: side(b, width: width));

  /// Dekorasi kotak bergaris tebal dengan bayangan keras.
  static BoxDecoration box(
    BuildContext context, {
    Color? color,
    double r = radius,
    Offset offset = shadowOffset,
    Color? borderColor,
  }) {
    final b = Theme.of(context).brightness;
    return BoxDecoration(
      color: color ?? Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(r),
      border: Border.all(color: borderColor ?? ink(b), width: border),
      boxShadow: [BoxShadow(color: shadowColor(b), offset: offset)],
    );
  }

  static Color shadowColor(Brightness b) => b == Brightness.dark ? const Color(0xFFF5F0E1) : _ink;

  static ThemeData build({
    required Color accent,
    required Brightness brightness,
    required PageTransitionsTheme transitions,
    bool pureBlack = false,
  }) {
    final dark = brightness == Brightness.dark;
    final line = ink(brightness);
    // Aksen dibuat pekat dan terang supaya terbaca di samping garis hitam.
    final hsl = HSLColor.fromColor(accent);
    final primary = hsl
        .withSaturation(hsl.saturation.clamp(0.65, 1.0))
        .withLightness(dark ? hsl.lightness.clamp(0.62, 0.72) : hsl.lightness.clamp(0.52, 0.62))
        .toColor();
    final onPrimary = ThemeData.estimateBrightnessForColor(primary) == Brightness.dark ? Colors.white : _ink;

    final bg = dark ? (pureBlack ? Colors.black : const Color(0xFF16140F)) : _paper;
    final card = dark ? const Color(0xFF26231B) : Colors.white;
    final soft = dark ? const Color(0xFF332F24) : const Color(0xFFFFE9A8);
    final secondary = dark ? const Color(0xFFE0B82E) : _yellow;
    final tertiary = dark ? const Color(0xFFFF8FB1) : const Color(0xFFC2185B);

    final scheme = ColorScheme.fromSeed(seedColor: primary, brightness: brightness).copyWith(
      primary: primary,
      onPrimary: onPrimary,
      primaryContainer: soft,
      onPrimaryContainer: line,
      secondary: secondary,
      onSecondary: _ink,
      secondaryContainer: secondary,
      onSecondaryContainer: _ink,
      tertiary: tertiary,
      onTertiary: dark ? _ink : Colors.white,
      tertiaryContainer: dark ? const Color(0xFF8A3D57) : _mint,
      onTertiaryContainer: dark ? Colors.white : _ink,
      surface: bg,
      onSurface: line,
      onSurfaceVariant: dark ? const Color(0xFFCFC8B4) : const Color(0xFF3A3A3A),
      surfaceContainerLowest: card,
      surfaceContainerLow: card,
      surfaceContainer: card,
      surfaceContainerHigh: soft,
      surfaceContainerHighest: soft,
      surfaceTint: Colors.transparent,
      outline: line,
      outlineVariant: line.withValues(alpha: 0.35),
      shadow: line,
      error: dark ? const Color(0xFFFF6B6B) : const Color(0xFFE63946),
      onError: _ink,
    );

    final base = ThemeData(brightness: brightness, useMaterial3: true);
    final text = base.textTheme.apply(bodyColor: line, displayColor: line).copyWith(
          headlineLarge: base.textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w900, color: line),
          headlineMedium: base.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900, color: line),
          headlineSmall: base.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900, color: line),
          titleLarge: base.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, color: line),
          titleMedium: base.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: line),
          titleSmall: base.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800, color: line),
          labelLarge: base.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800, color: line),
          labelMedium: base.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700, color: line),
        );

    final rect = shape(brightness);
    final smallRect = shape(brightness, r: 4, width: 2);
    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: BorderSide(color: line, width: 2),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      pageTransitionsTheme: transitions,
      textTheme: text,
      primaryTextTheme: text,
      dividerTheme: DividerThemeData(color: line, thickness: 2, space: 2),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: line,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
        shape: Border(bottom: BorderSide(color: line, width: border)),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: rect,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: line,
        textColor: line,
        titleTextStyle: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
      iconTheme: IconThemeData(color: line),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 68,
        indicatorColor: primary,
        indicatorShape: smallRect,
        iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
              color: s.contains(WidgetState.selected) ? onPrimary : line,
            )),
        labelTextStyle: WidgetStateProperty.all(text.labelMedium?.copyWith(fontWeight: FontWeight.w800)),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: card,
        indicatorColor: primary,
        indicatorShape: smallRect,
        selectedIconTheme: IconThemeData(color: onPrimary),
        unselectedIconTheme: IconThemeData(color: line),
        selectedLabelTextStyle: text.labelMedium?.copyWith(fontWeight: FontWeight.w900),
        unselectedLabelTextStyle: text.labelMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          elevation: 0,
          shape: rect,
          side: side(brightness),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: secondary,
          foregroundColor: _ink,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: rect,
          side: side(brightness),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: line,
          backgroundColor: card,
          shape: rect,
          side: side(brightness),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: line,
          shape: smallRect,
          textStyle: const TextStyle(fontWeight: FontWeight.w800, decoration: TextDecoration.underline),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: line, shape: smallRect),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: rect,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: card,
        selectedColor: secondary,
        disabledColor: soft,
        checkmarkColor: _ink,
        labelStyle: text.labelLarge,
        secondaryLabelStyle: text.labelLarge?.copyWith(color: _ink),
        side: side(brightness, width: 2),
        shape: smallRect,
        elevation: 0,
        pressElevation: 0,
        showCheckmark: true,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: card,
          foregroundColor: line,
          selectedBackgroundColor: secondary,
          selectedForegroundColor: _ink,
          side: side(brightness),
          shape: smallRect,
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        border: fieldBorder,
        enabledBorder: fieldBorder,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: line, width: 3.5),
        ),
        errorBorder: fieldBorder.copyWith(borderSide: BorderSide(color: scheme.error, width: 2.5)),
        focusedErrorBorder: fieldBorder.copyWith(borderSide: BorderSide(color: scheme.error, width: 3.5)),
        labelStyle: TextStyle(color: line, fontWeight: FontWeight.w700),
        hintStyle: TextStyle(color: line.withValues(alpha: 0.55)),
      ),
      searchBarTheme: SearchBarThemeData(
        backgroundColor: WidgetStatePropertyAll(card),
        elevation: const WidgetStatePropertyAll(0),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        shape: WidgetStatePropertyAll(rect),
        side: WidgetStatePropertyAll(side(brightness)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: shape(brightness, r: 8, width: 3),
        titleTextStyle: text.titleLarge,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        showDragHandle: true,
        dragHandleColor: line,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          side: BorderSide(color: line, width: 3),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: rect,
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(card),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(0),
          shape: WidgetStatePropertyAll(rect),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: secondary,
        contentTextStyle: const TextStyle(color: _ink, fontWeight: FontWeight.w800),
        actionTextColor: _ink,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: rect,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: _ink,
        unselectedLabelColor: line,
        labelStyle: const TextStyle(fontWeight: FontWeight.w900),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: line,
        dividerHeight: 2.5,
        indicator: BoxDecoration(
          color: secondary,
          border: Border(
            top: BorderSide(color: line, width: 2.5),
            bottom: BorderSide(color: line, width: 2.5),
            left: BorderSide(color: line, width: 2.5),
            right: BorderSide(color: line, width: 2.5),
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStatePropertyAll(line),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? primary : card),
        trackOutlineColor: WidgetStatePropertyAll(line),
        trackOutlineWidth: const WidgetStatePropertyAll(2.5),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? primary : card),
        checkColor: WidgetStatePropertyAll(onPrimary),
        side: BorderSide(color: line, width: 2.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStatePropertyAll(line),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: line,
        inactiveTrackColor: soft,
        thumbColor: primary,
        overlayColor: primary.withValues(alpha: 0.2),
        trackHeight: 6,
        trackShape: const RectangularSliderTrackShape(),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 11),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: soft,
        circularTrackColor: soft,
        linearMinHeight: 8,
      ),
      badgeTheme: BadgeThemeData(backgroundColor: tertiary, textColor: dark ? _ink : Colors.white),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: secondary,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: line, width: 2),
        ),
        textStyle: const TextStyle(color: _ink, fontWeight: FontWeight.w800),
      ),
    );
  }
}

/// Kotak bergaris tebal dengan bayangan keras; pembungkus umum untuk kartu & baris.
class NeoBox extends StatelessWidget {
  const NeoBox({
    super.key,
    required this.child,
    this.color,
    this.padding,
    this.margin,
    this.radius = NeoBrutal.radius,
    this.offset = const Offset(3, 3),
    this.borderColor,
  });

  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final Offset offset;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) => Container(
        margin: margin,
        padding: padding,
        decoration: NeoBrutal.box(context, color: color, r: radius, offset: offset, borderColor: borderColor),
        child: child,
      );
}

/// Pengganti CircleAvatar: kotak bergaris tebal berwarna blok.
class NeoAvatar extends StatelessWidget {
  const NeoAvatar({super.key, required this.child, this.size = 40});

  final Widget child;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.secondary,
        borderRadius: BorderRadius.circular(NeoBrutal.radius - 2),
        border: Border.all(color: scheme.outline, width: 2),
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: scheme.onSecondary, fontWeight: FontWeight.w900),
        child: IconTheme.merge(data: IconThemeData(color: scheme.onSecondary), child: child),
      ),
    );
  }
}
