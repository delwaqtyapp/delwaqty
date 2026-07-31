import 'package:flutter/material.dart';
import 'package:delwaqty/core/theme/app_text_styles.dart';
import 'sidebar_theme.dart';
import 'animations.dart';
import 'sidebar_item.dart';

class SidebarSection extends StatelessWidget {
  const SidebarSection({
    super.key,
    required this.title,
    required this.items,
    required this.controller,
    this.startIndex = 0,
  });

  final String title;
  final List<Widget> items;
  final Animation<double> controller;
  final int startIndex;

  @override
  Widget build(BuildContext context) {
    final st = Theme.of(context).extension<SidebarTheme>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: StaggerAnimation(
            controller: controller,
            index: startIndex,
            child: Text(
              title.toUpperCase(),
              style: AppTextStyles.labelSmall.copyWith(
                color: st.sectionTitleColor,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
        ...List.generate(items.length, (i) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: StaggerAnimation(
              controller: controller,
              index: startIndex + 1 + i,
              child: items[i],
            ),
          );
        }),
        const SizedBox(height: 4),
      ],
    );
  }
}

class SidebarDivider extends StatelessWidget {
  const SidebarDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final st = Theme.of(context).extension<SidebarTheme>()!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        height: 0.5,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              st.dividerColor,
              st.dividerColor.withValues(alpha: 0.0),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
      ),
    );
  }
}

class SidebarItemWrapper extends StatelessWidget {
  const SidebarItemWrapper({
    super.key,
    required this.controller,
    required this.index,
    required this.child,
  });

  final Animation<double> controller;
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: StaggerAnimation(
        controller: controller,
        index: index,
        child: child,
      ),
    );
  }
}
