import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import '../../core/utils/app_colors.dart';

class BaseModalBottomSheet extends StatelessWidget {
  final String title;
  final IconData? icon;
  final String? subtitle;
  final Widget child;
  final double? maxHeightFactor;
  final EdgeInsetsGeometry padding;
  const BaseModalBottomSheet({
    super.key,
    required this.title,
    this.icon,
    this.subtitle,
    required this.child,
    this.maxHeightFactor = 0.8,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: keyboardHeight),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: screenHeight * maxHeightFactor!,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: AppColor.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: padding,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Center(
                      child: Container(
                        width: 48,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColor.gray200,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                color: AppColor.gray800,
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),

                            if (icon != null && subtitle != null)
                              Row(
                                children: [
                                  Icon(icon, color: AppColor.primary, size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    subtitle!,
                                    style: const TextStyle(
                                      color: AppColor.gray600,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(
                            LucideIcons.x,
                            color: AppColor.gray600,
                            size: 24,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const Divider(
                      height: 33,
                      thickness: 1,
                      color: AppColor.gray200,
                    ),
                    child,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}



Future<T?> showBaseModalBottomSheet<T>({
  required BuildContext context,
  required String title,
  IconData? icon,
  String? subtitle,
  required Widget child,
  double maxHeightFactor = 0.8,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColor.white,
    builder: (context) {
      return BaseModalBottomSheet(
        title: title,
        subtitle: subtitle,
        icon: icon,
        maxHeightFactor: maxHeightFactor,
        child: child,
      );
    },
  );
}
