import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SunriseLogo extends StatelessWidget {
  final double size;
  const SunriseLogo({super.key, this.size = 60});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.wb_sunny_rounded, color: const Color(0xFFFF9800), size: size),
        const SizedBox(height: 4),
        Text(
          'SUNRISE',
          style: GoogleFonts.outfit(
            fontSize: size * 0.35,
            fontWeight: FontWeight.w800,
            color: const Color(0xFFFF9800),
            letterSpacing: 1.5,
          ),
        ),
        Text(
          'EQUIPMENTS',
          style: GoogleFonts.outfit(
            fontSize: size * 0.15,
            fontWeight: FontWeight.w600,
            color: Colors.grey[400],
            letterSpacing: 3.5,
          ),
        ),
      ],
    );
  }
}

class SunriseFooter extends StatelessWidget {
  final String text;
  const SunriseFooter({super.key, this.text = "Powering Your Progress\nEvery Single Day"});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        SizedBox(
          width: double.infinity,
          height: 180,
          child: CustomPaint(
            painter: _WavyPainter(),
          ),
        ),
        Positioned(
          bottom: 24,
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: const Color(0xFFFF9800),
            ),
          ),
        ),
      ],
    );
  }
}

class _WavyPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Back wave (lighter orange)
    final paint1 = Paint()
      ..color = const Color(0xFFFFCC80).withOpacity(0.5)
      ..style = PaintingStyle.fill;
      
    final path1 = Path();
    path1.moveTo(0, size.height * 0.4);
    path1.quadraticBezierTo(size.width * 0.25, size.height * 0.2, size.width * 0.5, size.height * 0.45);
    path1.quadraticBezierTo(size.width * 0.75, size.height * 0.7, size.width, size.height * 0.3);
    path1.lineTo(size.width, size.height);
    path1.lineTo(0, size.height);
    path1.close();
    canvas.drawPath(path1, paint1);

    // Front wave (darker gradient)
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final paint2 = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFFF9800), Color(0xFFFFC107)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(rect)
      ..style = PaintingStyle.fill;
      
    final path2 = Path();
    path2.moveTo(0, size.height * 0.6);
    path2.quadraticBezierTo(size.width * 0.3, size.height * 0.8, size.width * 0.6, size.height * 0.55);
    path2.quadraticBezierTo(size.width * 0.8, size.height * 0.4, size.width, size.height * 0.65);
    path2.lineTo(size.width, size.height);
    path2.lineTo(0, size.height);
    path2.close();
    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class BottomNavBar extends StatelessWidget {
  final int activeIndex;
  final Function(int)? onTap;

  const BottomNavBar({super.key, required this.activeIndex, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          )
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _navItem(Icons.home_rounded, 'Home', 0),
          _navItem(Icons.fingerprint_rounded, 'Attendance', 1),
          _navItem(Icons.receipt_long_rounded, 'Reports', 2),
          _navItem(Icons.person_outline_rounded, 'Profile', 3),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int index) {
    final isActive = activeIndex == index;
    final color = isActive ? const Color(0xFFFF9800) : Colors.grey[400];
    return GestureDetector(
      onTap: () {
        if (onTap != null) onTap!(index);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              color: color,
            ),
          )
        ],
      ),
    );
  }
}
