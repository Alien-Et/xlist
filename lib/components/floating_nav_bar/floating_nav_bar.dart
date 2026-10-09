import 'dart:ui' show ImageFilter;

import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

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

/// 底部悬浮圆角矩形导航栏
/// 半透明毛玻璃背景 + 大圆角 + 阴影，悬浮于内容之上
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
    final navHeight = height ?? (Get.width < 400 ? 120.h : 140.h);
    final isDark = Get.isDarkMode;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 40.w),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(50.r),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: navHeight,
            decoration: BoxDecoration(
              color: (isDark ? Colors.black : Colors.white).withOpacity(0.82),
              borderRadius: BorderRadius.circular(50.r),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.12)
                    : Colors.black.withOpacity(0.06),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                for (final item in items)
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: item.onTap,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            item.icon,
                            size: Get.width < 400 ? 44.sp : 56.sp,
                            color: item.active
                                ? Get.theme.primaryColor
                                : (isDark ? Colors.white70 : Colors.black54),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Get.textTheme.bodySmall?.copyWith(
                              fontSize: 20.sp,
                              color: item.active
                                  ? Get.theme.primaryColor
                                  : (isDark ? Colors.white60 : Colors.black45),
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
