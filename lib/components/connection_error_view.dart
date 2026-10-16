import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:xlist/gen/assets.gen.dart';

/// 连接错误统一视图
/// 与空状态页同款风格：纯色背景 + 简约插画 + 简短错误提示 + 重试按钮
/// 用于所有"无法连接服务器/加载失败"场景（不再展示生硬的长报错文本）
class ConnectionErrorView extends StatelessWidget {
  /// 错误描述（兼容保留；界面只展示简短提示）
  final String? message;

  /// 标题（默认"无法连接服务器"，播放等场景可定制）
  final String title;

  /// 简短提示（默认网络/服务器提示，播放等场景可定制）
  final String hint;

  /// 重试回调（可选）
  final VoidCallback? onRetry;

  /// 新建服务器回调（可选；服务器不可用/未配置时提供快捷入口）
  final VoidCallback? onCreateServer;

  const ConnectionErrorView({
    Key? key,
    this.message,
    this.title = '无法连接服务器',
    this.hint = '请检查网络连接或服务器地址，必要时在设置中重新配置',
    this.onRetry,
    this.onCreateServer,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = Get.isDarkMode;

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: isDark ? const Color(0xFF0B0B0F) : const Color(0xFFF7F7FA),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 同款插画（与"没有下载文件"等空状态一致）
            Assets.images.empty.image(width: 560.r),
            SizedBox(height: 32.r),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 10.r),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 64.w),
              child: Text(
                hint,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.disabledColor,
                  height: 1.4,
                ),
              ),
            ),
            if (onRetry != null || onCreateServer != null) ...[
              SizedBox(height: 30.r),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onCreateServer != null)
                    OutlinedButton.icon(
                      onPressed: onCreateServer,
                      icon: const Icon(CupertinoIcons.add, size: 18),
                      label: const Text('新建服务器'),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                            horizontal: 28.w, vertical: 10.h),
                      ),
                    ),
                  if (onCreateServer != null && onRetry != null)
                    SizedBox(width: 16.w),
                  if (onRetry != null)
                    FilledButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(CupertinoIcons.refresh, size: 18),
                      label: const Text('重试'),
                      style: FilledButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                            horizontal: 28.w, vertical: 10.h),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
