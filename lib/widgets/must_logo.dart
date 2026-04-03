import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class MustLogo extends StatelessWidget {
  final double size;
  final Color? backgroundColor;
  final Color? borderColor;
  
  const MustLogo({
    super.key,
    this.size = 80,
    this.backgroundColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: borderColor ?? AppColors.primaryGreen,
          width: 3,
        ),
      ),
      child: ClipOval(
        child: CustomPaint(
          size: Size(size, size),
          painter: MustLogoPainter(),
        ),
      ),
    );
  }
}

class MustLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    
    // Draw outer green circle
    final greenPaint = Paint()
      ..color = AppColors.primaryGreen
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    
    canvas.drawCircle(center, radius - 6, greenPaint);
    
    // Draw yellow/orange ring
    final yellowPaint = Paint()
      ..color = AppColors.secondaryOrange
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    
    canvas.drawCircle(center, radius - 10, yellowPaint);
    
    // Draw blue ring
    final bluePaint = Paint()
      ..color = AppColors.royalBlue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    
    canvas.drawCircle(center, radius - 14, bluePaint);
    
    // Draw central shield/crest
    final shieldPath = Path();
    final shieldCenter = center;
    final shieldWidth = size.width * 0.4;
    final shieldHeight = size.height * 0.4;
    
    // Create shield shape
    shieldPath.moveTo(shieldCenter.dx - shieldWidth / 2, shieldCenter.dy - shieldHeight / 2);
    shieldPath.lineTo(shieldCenter.dx + shieldWidth / 2, shieldCenter.dy - shieldHeight / 2);
    shieldPath.lineTo(shieldCenter.dx + shieldWidth / 2, shieldCenter.dy + shieldHeight / 4);
    shieldPath.lineTo(shieldCenter.dx, shieldCenter.dy + shieldHeight / 2);
    shieldPath.lineTo(shieldCenter.dx - shieldWidth / 2, shieldCenter.dy + shieldHeight / 4);
    shieldPath.close();
    
    // Fill shield with white background
    final shieldFillPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    
    canvas.drawPath(shieldPath, shieldFillPaint);
    
    // Draw shield border
    final shieldBorderPaint = Paint()
      ..color = AppColors.royalBlue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    
    canvas.drawPath(shieldPath, shieldBorderPaint);
    
    // Draw quadrants inside shield
    final quadrantSize = shieldWidth / 2.5;
    final quadrantOffset = quadrantSize / 2;
    
    // Top-left quadrant (blue with book)
    final topLeftRect = Rect.fromCenter(
      center: Offset(shieldCenter.dx - quadrantOffset / 2, shieldCenter.dy - quadrantOffset / 2),
      width: quadrantOffset,
      height: quadrantOffset,
    );
    
    final topLeftPaint = Paint()..color = AppColors.royalBlue;
    canvas.drawRect(topLeftRect, topLeftPaint);
    
    // Top-right quadrant (yellow with atom)
    final topRightRect = Rect.fromCenter(
      center: Offset(shieldCenter.dx + quadrantOffset / 2, shieldCenter.dy - quadrantOffset / 2),
      width: quadrantOffset,
      height: quadrantOffset,
    );
    
    final topRightPaint = Paint()..color = AppColors.secondaryOrange;
    canvas.drawRect(topRightRect, topRightPaint);
    
    // Bottom-left quadrant (yellow with compass)
    final bottomLeftRect = Rect.fromCenter(
      center: Offset(shieldCenter.dx - quadrantOffset / 2, shieldCenter.dy + quadrantOffset / 2),
      width: quadrantOffset,
      height: quadrantOffset,
    );
    
    final bottomLeftPaint = Paint()..color = AppColors.secondaryOrange;
    canvas.drawRect(bottomLeftRect, bottomLeftPaint);
    
    // Bottom-right quadrant (blue with medical symbol)
    final bottomRightRect = Rect.fromCenter(
      center: Offset(shieldCenter.dx + quadrantOffset / 2, shieldCenter.dy + quadrantOffset / 2),
      width: quadrantOffset,
      height: quadrantOffset,
    );
    
    final bottomRightPaint = Paint()..color = AppColors.royalBlue;
    canvas.drawRect(bottomRightRect, bottomRightPaint);
    
    // Draw simple symbols in quadrants (simplified for mobile display)
    final symbolPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    
    // Book symbol (top-left)
    final bookRect = Rect.fromCenter(
      center: topLeftRect.center,
      width: topLeftRect.width * 0.6,
      height: topLeftRect.height * 0.4,
    );
    canvas.drawRect(bookRect, symbolPaint);
    
    // Atom symbol (top-right) - simplified as circle with dots
    canvas.drawCircle(topRightRect.center, topRightRect.width * 0.2, symbolPaint);
    
    // Compass symbol (bottom-left) - simplified as cross
    canvas.drawLine(
      Offset(bottomLeftRect.center.dx - bottomLeftRect.width * 0.2, bottomLeftRect.center.dy),
      Offset(bottomLeftRect.center.dx + bottomLeftRect.width * 0.2, bottomLeftRect.center.dy),
      symbolPaint,
    );
    canvas.drawLine(
      Offset(bottomLeftRect.center.dx, bottomLeftRect.center.dy - bottomLeftRect.height * 0.2),
      Offset(bottomLeftRect.center.dx, bottomLeftRect.center.dy + bottomLeftRect.height * 0.2),
      symbolPaint,
    );
    
    // Medical symbol (bottom-right) - simplified as cross
    canvas.drawLine(
      Offset(bottomRightRect.center.dx - bottomRightRect.width * 0.15, bottomRightRect.center.dy),
      Offset(bottomRightRect.center.dx + bottomRightRect.width * 0.15, bottomRightRect.center.dy),
      symbolPaint,
    );
    canvas.drawLine(
      Offset(bottomRightRect.center.dx, bottomRightRect.center.dy - bottomRightRect.height * 0.15),
      Offset(bottomRightRect.center.dx, bottomRightRect.center.dy + bottomRightRect.height * 0.15),
      symbolPaint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}