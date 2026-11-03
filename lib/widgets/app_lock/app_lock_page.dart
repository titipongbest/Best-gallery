import 'dart:async';
import 'dart:ui' as ui;

import 'package:aves/model/app_lock.dart';
import 'package:aves/services/common/services.dart';
import 'package:aves/widgets/common/extensions/build_context.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:material_ui/material_ui.dart';

class const AppLockPage({
  super.key,
  // defaults to the app lock
  final bool Function(String pin)? unlock,
  final VoidCallback? onSystemAuth,
  // shows a close button when provided
  final VoidCallback? onCancel,
  final String? title,
}) extends StatefulWidget {
  @override
  State<AppLockPage> createState() => _AppLockPageState();
}

class _AppLockPageState extends State<AppLockPage> {
  static const _pinLength = 4;

  String _pin = '';
  bool _error = false;
  bool _canUseBiometrics = false;

  static const _ink = Color(0xff2e2210);
  static const _muted = Color(0xff6b5838);
  static const _keyInk = Color(0xff5a4a2e);
  static const _gold = Color(0xffb8730a);
  static const _cellFill = Color(0xfff8f0e0);
  static const _shadow = Color(0xff9a6410);

  @override
  void initState() {
    super.initState();
    unawaited(_checkBiometrics());
  }

  Future<void> _checkBiometrics() async {
    try {
      final can = await deviceService.canAuthenticateUser();
      if (mounted) setState(() => _canUseBiometrics = can);
    } catch (_) {
      // biometrics unavailable, keep the keypad only
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
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
                          width: 120,
                          height: 120,
                          alignment: Alignment.center,
                          decoration: _raisedDecoration(radius: 36),
                          child: const CustomPaint(
                            size: Size(64, 76),
                            painter: ShieldLogoPainter(),
                          ),
                        ),
                        const SizedBox(height: 22),
                        Text(
                          widget.title ?? 'Best gallery',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: _ink, fontSize: 28, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'SECURE BY NORTHX',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: _muted, fontSize: 12, letterSpacing: 3),
                        ),
                        const SizedBox(height: 28),
                        Text(
                          _error ? l10n.appLockWrongPin : l10n.pinDialogEnter,
                          style: TextStyle(
                            color: _error ? const Color(0xffd32f2f) : const Color(0xff5a4a2e),
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(_pinLength, _buildCell),
                        ),
                        const SizedBox(height: 26),
                        _buildKeypad(),
                        const SizedBox(height: 22),
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
            if (widget.onCancel != null)
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: IconButton(
                    icon: const Icon(Icons.close, color: _keyInk),
                    tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                    onPressed: widget.onCancel,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static BoxDecoration _raisedDecoration({required double radius}) => BoxDecoration(
    borderRadius: BorderRadius.all(Radius.circular(radius)),
    gradient: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xfffffdf8), Color(0xfff6ecd8)],
    ),
    border: Border.all(color: Colors.white.withValues(alpha: .95)),
    boxShadow: [
      BoxShadow(color: _shadow.withValues(alpha: .16), blurRadius: 18, offset: const Offset(6, 8)),
      const BoxShadow(color: Colors.white, blurRadius: 12, offset: Offset(-5, -5)),
    ],
  );

  Widget _buildCell(int index) {
    final filled = index < _pin.length;
    final focused = index == _pin.length;
    return Container(
      width: 54,
      height: 62,
      margin: const EdgeInsets.symmetric(horizontal: 7),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _cellFill,
        borderRadius: const BorderRadius.all(Radius.circular(18)),
        border: Border.all(
          color: _error
              ? const Color(0xffd32f2f)
              : focused
              ? const Color(0xfff2b530)
              : Colors.white,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(color: _shadow.withValues(alpha: .10), blurRadius: 8, offset: const Offset(3, 4)),
        ],
      ),
      child: filled
          ? Container(
              width: 13,
              height: 13,
              decoration: BoxDecoration(
                color: const Color(0xffc27a0e),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: const Color(0xfff2b530).withValues(alpha: .8), blurRadius: 10),
                ],
              ),
            )
          : null,
    );
  }

  Widget _buildKeypad() {
    Widget key({required Widget child, required VoidCallback? onTap, String? semanticsLabel}) {
      return Padding(
        padding: const EdgeInsets.all(7),
        child: Semantics(
          button: true,
          label: semanticsLabel,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onTap,
              customBorder: const StadiumBorder(),
              child: Ink(
                width: 68,
                height: 54,
                decoration: _raisedDecoration(radius: 27),
                child: Center(child: child),
              ),
            ),
          ),
        ),
      );
    }

    Widget digit(String d) => key(
      onTap: () => _onDigit(d),
      child: Text(
        d,
        style: const TextStyle(color: _keyInk, fontSize: 22, fontWeight: FontWeight.w600),
      ),
    );

    final rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...rows.map((row) => Row(mainAxisSize: MainAxisSize.min, children: row.map(digit).toList())),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _canUseBiometrics
                ? key(
                    onTap: _authenticate,
                    semanticsLabel: 'Fingerprint',
                    child: const Icon(Icons.fingerprint, color: _gold, size: 28),
                  )
                : const SizedBox(width: 82, height: 68),
            digit('0'),
            key(
              onTap: _pin.isEmpty ? null : _onBackspace,
              semanticsLabel: 'Backspace',
              child: const Icon(Icons.backspace_outlined, color: _keyInk, size: 22),
            ),
          ],
        ),
      ],
    );
  }

  void _onDigit(String d) {
    if (_pin.length >= _pinLength) return;
    unawaited(HapticFeedback.selectionClick());
    setState(() {
      _error = false;
      _pin += d;
    });
    if (_pin.length == _pinLength) _submit(_pin);
  }

  void _onBackspace() {
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _authenticate() async {
    try {
      final confirmed = await LocalAuthentication().authenticate(
        localizedReason: 'Best gallery',
      );
      if (confirmed) (widget.onSystemAuth ?? appLock.unlockWithSystemAuth)();
    } on PlatformException catch (_) {
      // authentication cancelled or not available, keep the keypad
    }
  }

  void _submit(String pin) {
    if ((widget.unlock ?? appLock.unlock)(pin)) return;
    unawaited(HapticFeedback.heavyImpact());
    setState(() {
      _pin = '';
      _error = true;
    });
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
