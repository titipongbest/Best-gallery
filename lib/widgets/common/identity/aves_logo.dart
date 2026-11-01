import 'dart:math';
import 'dart:ui' as ui;

import 'package:aves/model/settings/settings.dart';
import 'package:aves/widgets/common/extensions/build_context.dart';
import 'package:aves/widgets/common/fx/borders.dart';
import 'package:aves/widgets/common/fx/colors.dart';
import 'package:aves_model/aves_model.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

class const AvesLogo({
  super.key,
  required final double size,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget child = CustomPaint(
      size: Size(size / 1.4, size / 1.4),
      painter: AvesLogoPainter(),
    );
    if (context.select<Settings, bool>((v) => v.themeColorMode == AvesThemeColorMode.monochrome)) {
      final tint = Color.lerp(theme.colorScheme.primary, Colors.white, .5)!;
      child = ColorFiltered(
        colorFilter: ColorFilter.mode(tint, BlendMode.modulate),
        child: ColorFiltered(
          colorFilter: MatrixColorFilters.greyscale,
          child: child,
        ),
      );
    }

    return Transform.flip(
      flipX: context.isRtl,
      child: CircleAvatar(
        backgroundColor: theme.dividerColor,
        radius: size / 2,
        child: CircleAvatar(
          backgroundColor: const Color(0xff2e2a26),
          radius: size / 2 - AvesBorder.curvedBorderWidth(context),
          child: child,
        ),
      ),
    );
  }
}

// Best gallery logo: stacked photo cards with a champagne gold bezel,
// matching the launcher icon (drawn in the same 108x108 viewport)
class AvesLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // logo content fits within [25, 83] of the viewport
    const origin = 25.0;
    const extent = 58.0;
    final scale = size.width / extent;

    canvas.save();
    canvas.scale(scale);
    canvas.translate(-origin, -origin);

    Shader linear(Offset from, Offset to, List<Color> colors, [List<double>? stops]) => ui.Gradient.linear(from, to, colors, stops);
    Paint fill(Color color) => Paint()..color = color;

    void rotated(Offset pivot, double degrees, VoidCallback draw) {
      canvas.save();
      canvas.translate(pivot.dx, pivot.dy);
      canvas.rotate(degrees * pi / 180);
      canvas.translate(-pivot.dx, -pivot.dy);
      draw();
      canvas.restore();
    }

    // back card
    rotated(const Offset(52, 54), -14, () {
      final back = RRect.fromLTRBR(31, 32, 73, 74, const Radius.circular(7));
      canvas.drawRRect(back.shift(const Offset(1.6, 3)), fill(const Color(0x126b4e1f)));
      canvas.drawRRect(back.shift(const Offset(.8, 1.5)), fill(const Color(0x126b4e1f)));
      canvas.drawRRect(
        back,
        Paint()..shader = linear(const Offset(30, 30), const Offset(78, 78), const [Color(0xffffffff), Color(0xffe6d6ba)]),
      );
      canvas.drawRRect(
        back,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = .8
          ..color = const Color(0xffd2b67e),
      );
    });

    // front card
    rotated(const Offset(54, 54), 4, () {
      final front = RRect.fromLTRBR(34, 33, 76, 75, const Radius.circular(7));
      final photo = RRect.fromLTRBR(38.5, 37, 71.5, 71, const Radius.circular(4));
      canvas.drawRRect(front.shift(const Offset(2, 4)), fill(const Color(0x145a3e12)));
      canvas.drawRRect(front.shift(const Offset(1, 2)), fill(const Color(0x1a5a3e12)));
      canvas.drawRRect(
        front,
        Paint()
          ..shader = linear(
            const Offset(32, 30),
            const Offset(76, 80),
            const [Color(0xfff5e3b5), Color(0xffd8b677), Color(0xffb8904e), Color(0xffe2c68c)],
            const [0, .35, .7, 1],
          ),
      );

      canvas.save();
      canvas.clipRRect(photo);
      canvas.drawRRect(
        photo,
        Paint()..shader = linear(const Offset(0, 37), const Offset(0, 71), const [Color(0xfffffdf8), Color(0xfff6e7c9)]),
      );
      canvas.drawCircle(
        const Offset(61.5, 45.5),
        4.6,
        Paint()
          ..shader = ui.Gradient.radial(
            const Offset(61.5, 45.5),
            4.6,
            const [Color(0xfffff8e2), Color(0xfff0d594), Color(0xffd9b064)],
            const [0, .6, 1],
          ),
      );
      canvas.drawPath(
        Path()
          ..moveTo(38.5, 62)
          ..lineTo(47, 52)
          ..lineTo(55, 60)
          ..lineTo(60, 55.5)
          ..lineTo(71.5, 66)
          ..lineTo(71.5, 71)
          ..lineTo(38.5, 71)
          ..close(),
        Paint()..shader = linear(const Offset(0, 50), const Offset(0, 71), const [Color(0xffead5a8), Color(0xffd6b67c)]),
      );
      final frontPeaks = Paint()..shader = linear(const Offset(40, 54), const Offset(70, 72), const [Color(0xffd3ae6a), Color(0xff9c7333)]);
      canvas.drawPath(
        Path()
          ..moveTo(38.5, 66)
          ..lineTo(48.5, 56)
          ..lineTo(60, 71)
          ..lineTo(38.5, 71)
          ..close(),
        frontPeaks,
      );
      canvas.drawPath(
        Path()
          ..moveTo(52, 71)
          ..lineTo(61.5, 60)
          ..lineTo(71.5, 69)
          ..lineTo(71.5, 71)
          ..close(),
        frontPeaks,
      );
      canvas.restore();

      canvas.drawRRect(
        photo,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = .5
          ..color = const Color(0x598e6a2e),
      );

      // gloss on top bezel
      canvas.save();
      canvas.clipRect(const Rect.fromLTRB(34, 33, 76, 41));
      canvas.drawRRect(
        RRect.fromLTRBR(34.6, 33.6, 75.4, 74.4, const Radius.circular(6.4)),
        Paint()..shader = linear(const Offset(0, 33), const Offset(0, 42), const [Color(0xb3ffffff), Color(0x00ffffff)]),
      );
      canvas.restore();
    });

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
