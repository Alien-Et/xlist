import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// 通用空状态组件
/// 用于目录为空、搜索无结果、未配置服务器等场景
class EmptyState extends StatelessWidget {
  /// 主图标（CupertinoIcons 或 Material Icons）
  final IconData icon;

  /// 标题
  final String title;

  /// 描述文字
  final String? description;

  /// 底部操作按钮（可选）
  final Widget? action;

  /// 是否紧凑模式（在列表内嵌显示时使用）
  final bool compact;

  const EmptyState({
    Key? key,
    required this.icon,
    required this.title,
    this.description,
    this.action,
    this.compact = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: compact ? 120.r : 160.r,
          height: compact ? 120.r : 160.r,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: compact ? 56.r : 72.r,
            color: theme.disabledColor,
          ),
        ),
        SizedBox(height: compact ? 16.r : 28.r),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        if (description != null) ...[
          SizedBox(height: 8.r),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 48.w),
            child: Text(
              description!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.disabledColor,
              ),
            ),
          ),
        ],
        if (action != null) ...[
          SizedBox(height: 24.r),
          action!,
        ],
      ],
    );
  }
}
