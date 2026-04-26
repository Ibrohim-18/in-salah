import 'dart:ui';

import 'package:flutter/material.dart';

import '../utils/theme.dart';

class LiquidGlassContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final double blurSigma;
  final double opacity;
  final bool borderHighlight;
  final Color? baseColor;
  final double height;
  final double width;

  const LiquidGlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 24,
    this.padding,
    this.margin,
    this.onTap,
    this.blurSigma = 20,
    this.opacity = 0.06,
    this.borderHighlight = true,
    this.baseColor,
    this.height = double.nan,
    this.width = double.nan,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = baseColor ?? AppTheme.primary;
    final tint = (opacity + 0.10).clamp(0.04, 0.22);

    final decoration = BoxDecoration(
      borderRadius: BorderRadius.circular(borderRadius),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.lerp(AppTheme.surfaceRaised, Colors.white, 0.08)!
              .withValues(alpha: 0.96),
          Color.lerp(AppTheme.surfaceRaised, accentColor, 0.12)!
              .withValues(alpha: 0.97),
          AppTheme.surfaceRaised.withValues(alpha: 0.98),
        ],
        stops: const [0.0, 0.45, 1.0],
      ),
      border: Border.all(
        color: Colors.white.withValues(alpha: borderHighlight ? 0.16 : 0.09),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.28),
          blurRadius: 20,
          spreadRadius: -8,
          offset: const Offset(0, 10),
        ),
        if (borderHighlight)
          BoxShadow(
            color: accentColor.withValues(alpha: 0.10),
            blurRadius: 14,
            spreadRadius: -6,
            offset: const Offset(0, 4),
          ),
      ],
    );

    final content = Container(
      decoration: decoration,
      child: Stack(
        children: [
          // Top highlight shine
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Container(
                height: borderRadius * 0.9,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(borderRadius),
                    topRight: Radius.circular(borderRadius),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.10),
                      accentColor.withValues(alpha: tint),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Top edge light
          Positioned(
            top: 1,
            left: borderRadius * 0.6,
            right: borderRadius * 0.6,
            child: IgnorePointer(
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.white.withValues(alpha: 0.35),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Content
          Material(
            color: Colors.transparent,
            child: onTap != null
                ? InkWell(
                    onTap: onTap,
                    hoverColor: accentColor.withValues(alpha: 0.04),
                    highlightColor: accentColor.withValues(alpha: 0.06),
                    splashColor: accentColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(borderRadius - 1),
                    child: Padding(
                      padding: padding ?? EdgeInsets.zero,
                      child: child,
                    ),
                  )
                : Padding(padding: padding ?? EdgeInsets.zero, child: child),
          ),
        ],
      ),
    );

    return Container(
      width: width.isNaN ? null : width,
      height: height.isNaN ? null : height,
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: content,
        ),
      ),
    );
  }
}
