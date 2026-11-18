import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Arabic / Islamic arabesque pattern: a girih lattice of TRUE
/// eight-pointed stars (pointed star polygons, NOT squares — the old
/// version drew two overlapping squares, which read as a box grid),
/// interlaced with rays that meet between stars, and a small
/// eight-petal rosette in every gap. Drawn as thin lines, so text on
/// top stays readable. Used for headers, splash, login, card
/// backgrounds and the app-wide scaffold background.
class IslamicPatternPainter extends CustomPainter {
  final Color color;
  final double tile; // tile size in logical pixels
  final double stroke;

  const IslamicPatternPainter({
    this.color = Colors.white,
    this.tile = 56,
    this.stroke = 1.2,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    final dot = Paint()..color = color;
    final r = tile * 0.36;
    var row = 0;
    for (var y = -tile; y < size.height + tile; y += tile) {
      row++;
      for (var x = -tile; x < size.width + tile; x += tile) {
        final cx = x + (row.isOdd ? tile / 2 : 0);
        _girihStar(canvas, paint, Offset(cx, y), r);
      }
    }
    // Rosettes in the gaps (tile corners): a ring + 8 petals.
    final rosetteR = tile * 0.10;
    for (var y = -tile; y < size.height + tile; y += tile) {
      for (var x = -tile; x < size.width + tile; x += tile) {
        _rosette(canvas, paint, dot, Offset(x, y), rosetteR);
      }
    }
  }

  /// A true 8-pointed star: 16-vertex polygon (outer radius [r],
  /// inner radius 0.55r), a smaller inner star rotated half a step,
  /// and 8 short rays reaching toward the neighbouring stars so the
  /// stars interlace into a girih lattice.
  void _girihStar(Canvas canvas, Paint paint, Offset c, double r) {
    canvas.drawPath(_starPath(c, r, r * 0.55, 0), paint);
    canvas.drawPath(_starPath(c, r * 0.52, r * 0.30, math.pi / 8), paint);
    // Rays: from each outer point outward past the midpoint of the
    // gap, so rays from neighbouring stars meet and interlace.
    final reach = r + (tile - 2 * r) / 2 + 1;
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      final p1 = Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a));
      final p2 = Offset(
        c.dx + reach * math.cos(a),
        c.dy + reach * math.sin(a),
      );
      canvas.drawLine(p1, p2, paint);
    }
    // Centre dot.
    canvas.drawCircle(
      c,
      1.5,
      Paint()..color = paint.color,
    );
  }

  /// 16-vertex star polygon centred at [c]: 8 outer points at radius
  /// [outer], 8 inner points at radius [inner], rotated by [rot].
  Path _starPath(Offset c, double outer, double inner, double rot) {
    final path = Path();
    for (var i = 0; i < 16; i++) {
      final a = rot + i * math.pi / 8;
      final rad = i.isEven ? outer : inner;
      final p = Offset(c.dx + rad * math.cos(a), c.dy + rad * math.sin(a));
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    return path;
  }

  /// Small eight-petal rosette: a ring with 8 dots around it.
  void _rosette(Canvas canvas, Paint paint, Paint dot, Offset c, double r) {
    canvas.drawCircle(c, r, paint);
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      canvas.drawCircle(
        Offset(
          c.dx + r * 1.9 * math.cos(a),
          c.dy + r * 1.9 * math.sin(a),
        ),
        1.2,
        dot,
      );
    }
  }

  @override
  bool shouldRepaint(covariant IslamicPatternPainter old) =>
      old.color != color || old.tile != tile || old.stroke != stroke;
}

/// A background layer: solid colour + VISIBLE Islamic pattern +
/// optional soft radial glow. Put the content on top via [child].
/// Default opacity 0.22: the old 0.10 was nearly invisible on a real
/// phone, which made the whole app look plain white.
///
/// LAYERING (Run 7, user feedback "background overlaps the features"):
/// the pattern is painted FIRST, then a translucent wash of the base
/// colour ([scrimAlpha]) is painted OVER the pattern but UNDER [child].
/// That wash is the cheap "frosted / slightly blurry" look: it softens
/// the pattern so it can never clash with text, while the pattern
/// stays visible around the cards. A full-screen BackdropFilter blur
/// was deliberately NOT used — on the low-end Tecno KL7 it would jank
/// every scroll frame; this wash costs one flat fill. Cards themselves
/// are fully opaque (white / nightCard in the theme), so the pattern
/// never shows through any text.
class PatternBackground extends StatelessWidget {
  final Widget? child;
  final Color base;
  final Color patternColor;
  final double patternOpacity;
  final Color? glowColor;

  /// Opacity of the base-colour wash over the pattern (0 = pattern at
  /// full strength, 1 = pattern fully hidden). 0.5 app-wide, lower
  /// (0.30) on rich emerald cards so the colour stays deep.
  final double scrimAlpha;

  const PatternBackground({
    super.key,
    this.child,
    required this.base,
    this.patternColor = Colors.white,
    this.patternOpacity = 0.22,
    this.glowColor,
    this.scrimAlpha = 0.5,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: base,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // In a scrollable list the height is UNBOUNDED (maxHeight =
          // Infinity). StackFit.expand there forces the Stack to fill an
          // infinite height and the layout throws "BoxConstraints forces
          // an infinite height" on the very first frame (pinned from the
          // flutter run log 2026-11-17: pattern.dart:155, the Home
          // countdown card inside a ListView). So: expand only when the
          // height is bounded; otherwise size to the content and let the
          // background layers follow it via Positioned.fill.
          final bounded = constraints.hasBoundedHeight;
          return Stack(
            fit: bounded ? StackFit.expand : StackFit.loose,
            children: [
              if (glowColor != null)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.topCenter,
                        radius: 1.1,
                        colors: [
                          glowColor!.withValues(alpha: 0.35),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              Positioned.fill(
                child: Opacity(
                  opacity: patternOpacity,
                  child: CustomPaint(
                    painter: IslamicPatternPainter(color: patternColor),
                  ),
                ),
              ),
              // Frosted wash: softens the pattern (blurred look) and
              // guarantees contrast for everything painted above it.
              // The pattern is strictly BEHIND content — never on top.
              if (scrimAlpha > 0)
                Positioned.fill(
                  child: Container(color: base.withValues(alpha: scrimAlpha)),
                ),
              if (child != null) child!,
            ],
          );
        },
      ),
    );
  }
}
