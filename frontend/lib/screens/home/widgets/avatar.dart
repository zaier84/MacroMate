import 'package:flutter/material.dart';
import '../../../theme/colors.dart';

class AvatarWidget extends StatelessWidget {
  final String? imageUrl;
  final double size;
  final IconData fallbackIcon;
  final Color backgroundColor;

  const AvatarWidget({
    super.key,
    this.imageUrl,
    this.size = 40, // same as h-10 w-10 in Tailwind (~40px)
    this.fallbackIcon = Icons.person,
    this.backgroundColor = AppColors.neutral100,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size / 2),
      child: Container(
        height: size,
        width: size,
        color: backgroundColor,
        child: imageUrl != null && imageUrl!.isNotEmpty
            ? Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _buildFallback();
                },
              )
            : _buildFallback(),
      ),
    );
  }

  Widget _buildFallback() {
    return Container(
      height: size,
      width: size,
      color: backgroundColor,
      child: Icon(fallbackIcon, color: AppColors.neutral600, size: size * 0.5),
    );
  }
}
