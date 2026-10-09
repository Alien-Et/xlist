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

/// 液态玻璃悬浮圆角导航栏
/// 高透明毛玻璃 + 顶部高光渐变 + 渐变描边 + 柔和阴影 + 图标胶囊底
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
    final navHeight = height ?? (Get.width < 400 ? 88.0 : 96.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(34),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: Container(
            height: navHeight,
            decoration: BoxDecoration(
              // 液态玻璃：半透明渐变 + 顶部高光
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? const [Color(0x59FFFFFF), Color(0x21FFFFFF)]
                    : const [Color(0xB8FFFFFF), Color(0x73FFFFFF)],
              ),
              borderRadius: BorderRadius.circular(34),
              // 玻璃描边
              border: Border.all(
                color: isDark
                    ? const Color(0x40FFFFFF)
                    : const Color(0xE6FFFFFF),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.16),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                for (final item in items)
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(30),
                      onTap: item.onTap,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // 图标：圆形胶囊渐变底 + 大图标
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: item.active
                                    ? [
                                        Get.theme.primaryColor
                                            .withValues(alpha: 0.35),
                                        Get.theme.primaryColor
                                            .withValues(alpha: 0.10),
                                      ]
                                    : isDark
                                        ? const [
                                            Color(0x33FFFFFF),
                                            Color(0x0DFFFFFF),
                                          ]
                                        : [
                                            Colors.white
                                                .withValues(alpha: 0.80),
                                            Colors.white
                                                .withValues(alpha: 0.30),
                                          ],
                              ),
                              border: Border.all(
                                color: item.active
                                    ? Get.theme.primaryColor
                                        .withValues(alpha: 0.55)
                                    : isDark
                                        ? const Color(0x26FFFFFF)
                                        : Colors.white
                                            .withValues(alpha: 0.95),
                              ),
                            ),
                            child: Icon(
                              item.icon,
                              size: 27,
                              color: item.active
                                  ? Get.theme.primaryColor
                                  : (isDark ? Colors.white : Colors.black87),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: item.active
                                  ? Get.theme.primaryColor
                                  : (isDark ? Colors.white : Colors.black87),
                            ),
                          ),
                        ],
                      ),
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
