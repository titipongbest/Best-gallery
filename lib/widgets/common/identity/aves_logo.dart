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
          backgroundColor: const Color(0xfffbf6ee),
          radius: size / 2 - AvesBorder.curvedBorderWidth(context),
          child: child,
        ),
      ),
    );
  }
}

// Best gallery logo: a champagne gold picture frame with a sun and mountain peaks
class AvesLogoPainter extends CustomPainter {
  static const _gold = [Color(0xffe9d29e), Color(0xffc9a363), Color(0xffa9823f)];
  static const _goldStops = [0.0, 0.55, 1.0];

  @override
  void paint(Canvas canvas, Size size) {
    // drawing is defined in a 108x108 viewport (same as the launcher icon),
    // and the logo content fits within [30, 78]
    const origin = 30.0;
    const extent = 48.0;
    final scale = size.width / extent;

    canvas.save();
    canvas.scale(scale);
    canvas.translate(-origin, -origin);

    final shader = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: _gold,
      stops: _goldStops,
    ).createShader(const Rect.fromLTRB(32, 31, 76, 77));

    Paint stroke(double width) => Paint()
      ..style = PaintingStyle.stroke
      ..shader = shader
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // outer frame
    canvas.drawRRect(
      RRect.fromLTRBR(32, 32, 76, 76, const Radius.circular(9)),
      stroke(2),
    );
    // inner mat
    canvas.drawRRect(
      RRect.fromLTRBR(37, 37, 71, 71, const Radius.circular(5)),
      stroke(.6),
    );
    // sun
    canvas.drawCircle(
      const Offset(61, 47),
      3,
      Paint()
        ..style = PaintingStyle.fill
        ..shader = shader,
    );
    // peaks
    final peaks = Path()
      ..moveTo(42.5, 64)
      ..lineTo(50.5, 53.5)
      ..lineTo(56, 60)
      ..lineTo(59.5, 56.2)
      ..lineTo(65.5, 64);
    canvas.drawPath(peaks, stroke(1.6));

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
