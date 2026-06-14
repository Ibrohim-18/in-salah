import 'dart:ui' show ImageFilter, FontFeature;

import 'package:flutter/material.dart';

/// iOS-style numeric content transition (à la `.contentTransition(.numericText())`).
///
/// Renders a number/string as one animated slot per character. Only the
/// characters that actually change slide + blur as they swap; unchanged
/// characters stay rock-steady. Slots are keyed by their distance from the
/// right, so place values keep a stable identity as the number grows/shrinks.
///
///   AnimatedDigits(value: '42', style: ...)            // auto direction
///   AnimatedDigits(value: '12', direction: -1, ...)    // always roll down
class AnimatedDigits extends StatefulWidget {
  final String value;
  final TextStyle style;
  final Duration duration;

  /// +1 = incoming char enters from below (count up), -1 = from above
  /// (count down). When null, derived from the numeric delta between values.
  final int? direction;

  const AnimatedDigits({
    super.key,
    required this.value,
    required this.style,
    this.duration = const Duration(milliseconds: 450),
    this.direction,
  });

  @override
  State<AnimatedDigits> createState() => _AnimatedDigitsState();
}

class _AnimatedDigitsState extends State<AnimatedDigits> {
  double? _prevNum;
  int _dir = 1;

  double? _numeric(String s) {
    final digits = s.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.isEmpty ? null : double.tryParse(digits);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.direction != null) {
      _dir = widget.direction!;
    } else {
      final n = _numeric(widget.value);
      if (n != null && _prevNum != null && n != _prevNum) {
        _dir = n < _prevNum! ? -1 : 1;
      }
      if (n != null) _prevNum = n;
    }

    final chars = widget.value.split('');
    final len = chars.length;
    final style = widget.style.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < len; i++)
          _CharSlot(
            // Keyed by distance from the right so each place value keeps its slot.
            key: ValueKey(len - 1 - i),
            char: chars[i],
            style: style,
            duration: widget.duration,
            direction: _dir,
          ),
      ],
    );
  }
}

class _CharSlot extends StatefulWidget {
  final String char;
  final TextStyle style;
  final Duration duration;
  final int direction;

  const _CharSlot({
    super.key,
    required this.char,
    required this.style,
    required this.duration,
    required this.direction,
  });

  @override
  State<_CharSlot> createState() => _CharSlotState();
}

class _CharSlotState extends State<_CharSlot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late String _cur;
  String? _out;

  @override
  void initState() {
    super.initState();
    _cur = widget.char;
    _c = AnimationController(vsync: this, duration: widget.duration)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed && mounted) {
          setState(() => _out = null);
        }
      });
  }

  @override
  void didUpdateWidget(covariant _CharSlot old) {
    super.didUpdateWidget(old);
    if (widget.duration != old.duration) _c.duration = widget.duration;
    if (widget.char != _cur) {
      _out = _cur;
      _cur = widget.char;
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _text(String ch) => Text(
        ch.isEmpty ? '​' : ch,
        style: widget.style,
        softWrap: false,
        maxLines: 1,
      );

  Widget _layer(Widget child, double dy, double opacity, double blur) {
    Widget c = child;
    if (blur > 0.05) {
      c = ImageFiltered(
        imageFilter: ImageFilter.blur(
          sigmaX: blur,
          sigmaY: blur,
          tileMode: TileMode.decal,
        ),
        child: c,
      );
    }
    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Transform.translate(offset: Offset(0, dy), child: c),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_out == null) {
      // Resting: plain text, no layers / filters.
      return _text(_cur);
    }

    final fontSize = widget.style.fontSize ?? 14;
    final dist = fontSize * 0.6;
    final maxBlur = fontSize * 0.22;
    final dir = widget.direction;

    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        final inT = Curves.easeOutCubic.transform(t);
        final outT = Curves.easeIn.transform(t);

        // Incoming: slides from (dir * dist) to 0, fades in, blur clears.
        final inLayer = _layer(
          _text(_cur),
          (1 - inT) * dir * dist,
          inT,
          (1 - inT) * maxBlur,
        );
        // Outgoing: slides away to (-dir * dist), fades out, blur grows.
        final outLayer = _layer(
          _text(_out!),
          outT * -dir * dist,
          1 - outT,
          outT * maxBlur,
        );

        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            inLayer, // sizes the slot
            Positioned.fill(child: Center(child: outLayer)),
          ],
        );
      },
    );
  }
}
