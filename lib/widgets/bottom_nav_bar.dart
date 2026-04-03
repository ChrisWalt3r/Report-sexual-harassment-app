import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../screens/my_reports_screen.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                context,
                0,
                Icons.home_outlined,
                Icons.home,
                'Home',
              ),
              _buildNavItem(
                context,
                1,
                Icons.description_outlined,
                Icons.description,
                'My Reports',
              ),
              _buildNavItem(
                context,
                2,
                Icons.help_outline,
                Icons.help,
                'Support',
              ),
              _buildNavItem(
                context,
                3,
                Icons.settings_outlined,
                Icons.settings,
                'Settings',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    int index,
    IconData icon,
    IconData activeIcon,
    String label,
  ) {
    final isSelected = currentIndex == index;

    return GestureDetector(
      onTap: () {
        if (index == 1) {
          // My Reports - navigate to My Reports screen
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const MyReportsScreen()),
          );
        } else {
          onTap(index);
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? AppColors.primaryBlue : AppColors.textGray,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? AppColors.primaryBlue : AppColors.textGray,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
