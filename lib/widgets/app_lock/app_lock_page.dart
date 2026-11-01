import 'dart:async';
import 'dart:ui' as ui;

import 'package:aves/model/app_lock.dart';
import 'package:aves/widgets/common/extensions/build_context.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

class const AppLockPage({super.key}) extends StatefulWidget {
  @override
  State<AppLockPage> createState() => _AppLockPageState();
}

class _AppLockPageState extends State<AppLockPage> {
  final _controller = PinInputController();
  bool _error = false;

  static const _gold = Color(0xff8e6a2e);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Material(
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(-.3, -.5),
              radius: 1.3,
              colors: [Color(0xfff3e6cf), Color(0xffe2cca6), Color(0xffc9ab7c)],
              stops: [0, .55, 1],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CustomPaint(
                        size: Size(96, 112),
                        painter: ShieldLogoPainter(),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Secure by NorthX',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _gold,
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        _error ? l10n.appLockWrongPin : l10n.pinDialogEnter,
                        style: TextStyle(
                          color: _error ? const Color(0xffb3261e) : const Color(0xff4a3a22),
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 16),
                      MaterialPinField(
                        length: 4,
                        pinController: _controller,
                        keyboardType: TextInputType.number,
                        autoFocus: true,
                        obscureText: true,
                        onChanged: (v) {
                          if (_error && v.isNotEmpty) setState(() => _error = false);
                        },
                        onCompleted: _submit,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
    );
  }

  void _submit(String pin) {
    if (appLock.unlock(pin)) return;
    unawaited(HapticFeedback.heavyImpact());
    _controller.clear();
    setState(() => _error = true);
  }
}

// shield with a keyhole, in champagne gold
class const ShieldLogoPainter() extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    Path shield(double inset) {
      final l = inset, r = w - inset, t = inset, b = h - inset;
      final cx = w / 2;
      return Path()
        ..moveTo(cx, t)
        ..cubicTo(cx + (r - cx) * .45, t + (b - t) * .08, r - (r - cx) * .1, t + (b - t) * .1, r, t + (b - t) * .14)
        ..lineTo(r, t + (b - t) * .48)
        ..cubicTo(r, t + (b - t) * .74, cx + (r - cx) * .5, b - (b - t) * .08, cx, b)
        ..cubicTo(cx - (cx - l) * .5, b - (b - t) * .08, l, t + (b - t) * .74, l, t + (b - t) * .48)
        ..lineTo(l, t + (b - t) * .14)
        ..cubicTo(l + (cx - l) * .1, t + (b - t) * .1, cx - (cx - l) * .45, t + (b - t) * .08, cx, t)
        ..close();
    }

    final outer = shield(0);
    // soft shadow
    canvas.drawPath(
      outer.shift(const Offset(0, 4)),
      Paint()
        ..color = const Color(0x335a3e12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    // gold bezel
    canvas.drawPath(
      outer,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(w, h),
          const [Color(0xfff5e3b5), Color(0xffd8b677), Color(0xffb8904e), Color(0xffe2c68c)],
          const [0, .35, .7, 1],
        ),
    );
    // inner face
    canvas.drawPath(
      shield(w * .09),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, h * .1),
          Offset(0, h * .9),
          const [Color(0xfffffdf8), Color(0xfff6e7c9)],
        ),
    );
    // keyhole
    final keyPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(w * .4, h * .35),
        Offset(w * .6, h * .7),
        const [Color(0xffd3ae6a), Color(0xff9c7333)],
      );
    final cx = w / 2;
    canvas.drawCircle(Offset(cx, h * .42), w * .1, keyPaint);
    canvas.drawPath(
      Path()
        ..moveTo(cx - w * .045, h * .45)
        ..lineTo(cx + w * .045, h * .45)
        ..lineTo(cx + w * .075, h * .66)
        ..lineTo(cx - w * .075, h * .66)
        ..close(),
      keyPaint,
    );
    // top gloss
    canvas.save();
    canvas.clipPath(outer);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h * .18),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(0, h * .18),
          const [Color(0x99ffffff), Color(0x00ffffff)],
        ),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
