import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class AvatarWidget extends StatelessWidget {
  final String? imageUrl;
  final String nickname;
  final double size;
  final bool isActive;
  final bool isCurrentTurn;

  const AvatarWidget({
    super.key,
    this.imageUrl,
    required this.nickname,
    this.size = 40,
    this.isActive = true,
    this.isCurrentTurn = false,
  });

  Color _getColorFromNickname(String name) {
    final colors = [
      AppColors.chipRed,
      AppColors.chipBlue,
      AppColors.chipGreen,
      AppColors.primary,
      Colors.purple,
      Colors.orange,
      Colors.teal,
      Colors.indigo,
    ];
    return colors[name.hashCode.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: isCurrentTurn
            ? Border.all(color: AppColors.warning, width: 3)
            : null,
        boxShadow: isCurrentTurn
            ? [BoxShadow(color: AppColors.warning.withOpacity(0.5), blurRadius: 8)]
            : null,
      ),
      child: CircleAvatar(
        radius: size / 2,
        backgroundColor: isActive
            ? _getColorFromNickname(nickname)
            : Colors.grey,
        child: Text(
          nickname.isNotEmpty ? nickname[0].toUpperCase() : '?',
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.4,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
