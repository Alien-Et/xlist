import 'dart:ui' show ImageFilter;

import 'package:get/get.dart';
import 'package:flutter/material.dart';

/// 悬浮导航栏条目
class FloatingNavItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  const FloatingNavItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });
}

/// Telegram 风格紧凑悬浮导航栏
/// 短胶囊条（自适应宽度居中）+ 毛玻璃 + 选中项圆角高亮
class FloatingNavBar extends StatelessWidget {
  final List<FloatingNavItem> items;
  final double? height;

  const FloatingNavBar({
    Key? key,
    required this.items,
    this.height,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Get.isDarkMode;
    final navHeight = height ?? 50.0;
    final radius = navHeight / 2;

    return Align(
      alignment: Alignment.bottomCenter,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: navHeight,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              // 收敛的玻璃质感：半透明 + 细描边
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? const [Color(0x66FFFFFF), Color(0x2EFFFFFF)]
                    : const [Color(0xE8FFFFFF), Color(0xBFFFFFFF)],
              ),
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: isDark ? const Color(0x33FFFFFF) : Colors.white,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final item in items) _buildItem(item, isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItem(FloatingNavItem item, bool isDark) {
    final color = item.active
        ? Get.theme.primaryColor
        : (isDark ? Colors.white.withValues(alpha: 0.72) : Colors.black54);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: item.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              // 选中项：圆角矩形淡色高亮（Telegram 风格）
              color: item.active
                  ? Get.theme.primaryColor.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  item.icon,
                  size: 19,
                  color: color,
                ),
                const SizedBox(height: 2),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
