import 'package:flutter/material.dart';

/// Costify app logo widget - uses the app icon image
class CostifyLogo extends StatelessWidget {
  final double size;
  final bool showText;
  final bool darkBackground;

  const CostifyLogo({
    super.key,
    this.size = 80,
    this.showText = false,
    this.darkBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(size * 0.25),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          padding: EdgeInsets.all(size * 0.12),
          child: Image.asset('assets/icons/app_icon.png', fit: BoxFit.contain),
        ),
        if (showText) ...[
          SizedBox(height: size * 0.2),
          Text(
            'COSTIFY',
            style: TextStyle(
              fontSize: size * 0.22,
              fontWeight: FontWeight.w800,
              color: darkBackground ? Colors.white : const Color(0xFF1A365D),
              letterSpacing: 3,
            ),
          ),
        ],
      ],
    );
  }
}

/// Simple icon-only logo (for small displays)
class CostifyIcon extends StatelessWidget {
  final double size;

  const CostifyIcon({super.key, this.size = 48});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.all(size * 0.1),
      child: Image.asset('assets/icons/app_icon.png', fit: BoxFit.contain),
    );
  }
}

/// Logo with text below - for splash and login screens
class CostifyLogoFull extends StatelessWidget {
  final double logoSize;
  final bool darkBackground;

  const CostifyLogoFull({
    super.key,
    this.logoSize = 120,
    this.darkBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: logoSize,
          height: logoSize,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(logoSize * 0.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 25,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: EdgeInsets.all(logoSize * 0.12),
          child: Image.asset('assets/icons/app_icon.png', fit: BoxFit.contain),
        ),
        const SizedBox(height: 24),
        Text(
          'COSTIFY',
          style: TextStyle(
            fontSize: logoSize * 0.18,
            fontWeight: FontWeight.w800,
            color: darkBackground ? Colors.white : const Color(0xFF1A365D),
            letterSpacing: 4,
          ),
        ),
      ],
    );
  }
}
