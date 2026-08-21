import 'package:flutter/material.dart';
import 'package:delwaqty/core/theme/app_text_styles.dart';
import 'sidebar_theme.dart';
import 'animations.dart';

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
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 2),
          child: StaggerAnimation(
            controller: controller,
            index: startIndex,
            child: Text(
              title.toUpperCase(),
              style: AppTextStyles.labelSmall.copyWith(
                color: st.sectionTitleColor,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
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
            colors: [st.dividerColor, st.dividerColor.withValues(alpha: 0.0)],
          ),
        ),
      ),
    );
  }
}

class CollapsibleSidebarSection extends StatefulWidget {
  const CollapsibleSidebarSection({
    super.key,
    required this.title,
    required this.items,
    required this.controller,
    required this.collapseTooltip,
    required this.expandTooltip,
    this.startIndex = 0,
    this.initialExpanded = false,
  });

  final String title;
  final List<Widget> items;
  final Animation<double> controller;
  final String collapseTooltip;
  final String expandTooltip;
  final int startIndex;
  final bool initialExpanded;

  @override
  State<CollapsibleSidebarSection> createState() =>
      _CollapsibleSidebarSectionState();
}

class _CollapsibleSidebarSectionState extends State<CollapsibleSidebarSection> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initialExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final st = Theme.of(context).extension<SidebarTheme>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 2),
          child: GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title.toUpperCase(),
                    style: AppTextStyles.labelSmall.copyWith(
                      color: st.sectionTitleColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                Tooltip(
                  message: _expanded
                      ? widget.collapseTooltip
                      : widget.expandTooltip,
                  child: AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: st.iconColor.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 280),
          sizeCurve: Curves.easeOutCubic,
          crossFadeState: _expanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: const SizedBox(width: double.infinity, height: 0),
          secondChild: Column(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(widget.items.length, (i) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: StaggerAnimation(
                  controller: widget.controller,
                  index: widget.startIndex + 1 + i,
                  child: widget.items[i],
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 4),
      ],
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
