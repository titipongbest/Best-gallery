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

  static const _ink = Color(0xff2e2210);
  static const _muted = Color(0xff6b5838);
  static const _gold = Color(0xffb8730a);
  static const _cellFill = Color(0xfff8f0e0);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cellShadow = [
      BoxShadow(color: const Color(0xff9a6410).withValues(alpha: .10), blurRadius: 10, offset: const Offset(3, 4)),
      const BoxShadow(color: Colors.white, blurRadius: 8, offset: Offset(-3, -3)),
    ];
    return Material(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xfffdf9f1), Color(0xfff8efdc), Color(0xfff3e6c9)],
            stops: [0, .6, 1],
          ),
        ),
        child: Stack(
          children: [
            // decorative rings and glass orbs
            const Positioned(left: -110, top: -90, child: _GlassRing(size: 230)),
            const Positioned(right: -40, top: 220, child: _GlassOrb(size: 110)),
            const Positioned(right: -90, bottom: -80, child: _GlassOrb(size: 210)),
            const Positioned(left: -90, bottom: -110, child: _GlassRing(size: 190)),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 132,
                          height: 132,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.all(Radius.circular(38)),
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xfffffdf8), Color(0xfff6ecd8)],
                            ),
                            border: Border.all(color: Colors.white.withValues(alpha: .9)),
                            boxShadow: [
                              BoxShadow(color: const Color(0xff9a6410).withValues(alpha: .16), blurRadius: 22, offset: const Offset(8, 10)),
                              const BoxShadow(color: Colors.white, blurRadius: 16, offset: Offset(-6, -6)),
                            ],
                          ),
                          child: const CustomPaint(
                            size: Size(72, 84),
                            painter: ShieldLogoPainter(),
                          ),
                        ),
                        const SizedBox(height: 26),
                        const Text(
                          'Best gallery',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: _ink, fontSize: 30, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'SECURE BY NORTHX',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: _muted, fontSize: 12, letterSpacing: 3),
                        ),
                        const SizedBox(height: 40),
                        Text(
                          _error ? l10n.appLockWrongPin : l10n.pinDialogEnter,
                          style: TextStyle(
                            color: _error ? const Color(0xffd32f2f) : const Color(0xff5a4a2e),
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 16),
                        MaterialPinField(
                          length: 4,
                          pinController: _controller,
                          keyboardType: TextInputType.number,
                          autoFocus: true,
                          obscureText: true,
                          theme: MaterialPinTheme(
                            shape: MaterialPinShape.outlined,
                            cellSize: const Size(56, 64),
                            spacing: 14,
                            borderRadius: const BorderRadius.all(Radius.circular(18)),
                            fillColor: _cellFill,
                            focusedFillColor: _cellFill,
                            filledFillColor: _cellFill,
                            borderColor: Colors.white,
                            focusedBorderColor: const Color(0xfff2b530),
                            filledBorderColor: Colors.white,
                            textStyle: const TextStyle(color: _gold, fontSize: 24, fontWeight: FontWeight.w700),
                            cursorColor: _gold,
                            boxShadows: cellShadow,
                            focusedBoxShadows: cellShadow,
                          ),
                          onChanged: (v) {
                            if (_error && v.isNotEmpty) setState(() => _error = false);
                          },
                          onCompleted: _submit,
                        ),
                        const SizedBox(height: 56),
                        const Text(
                          'REFINE BY NORTHXBAR',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: _muted, fontSize: 10, letterSpacing: 3),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
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

// glossy gold shield with a keyhole
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
        ..color = const Color(0x559a6410)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    // gold bezel
    canvas.drawPath(
      outer,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(w, h),
          const [Color(0xffffe08a), Color(0xfff2b530), Color(0xffb8730a), Color(0xff8a5208)],
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
          const [Color(0xfff5c04a), Color(0xffc27a0e)],
        ),
    );
    // keyhole
    final keyPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(w * .4, h * .35),
        Offset(w * .6, h * .7),
        const [Color(0xffffffff), Color(0xfffff3d6)],
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

class const _GlassOrb({required final double size}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          center: Alignment(-.3, -.4),
          colors: [Colors.white, Color(0xfff8e2b0), Color(0xffefc56a)],
          stops: [0, .55, 1],
        ),
        boxShadow: [
          BoxShadow(color: const Color(0xffc9850f).withValues(alpha: .15), blurRadius: 24, offset: const Offset(0, 10)),
        ],
      ),
    );
  }
}

class const _GlassRing({required final double size}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xffe0a42a).withValues(alpha: .35), width: 10),
      ),
    );
  }
}
