import 'package:flutter/material.dart';

/// Text that scales down to fit its width but never below a readable
/// minimum; when the text would shrink past [minScale] it wraps to two
/// lines instead. Used for money amounts, which must always stay fully
/// readable (never ellipsized, never microscopic).
class ReadableFitText extends StatelessWidget {
  const ReadableFitText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.minScale = 0.6,
  });

  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;

  /// Fraction of the original font size below which the text wraps to
  /// two lines instead of shrinking further.
  final double minScale;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final effectiveStyle = style ?? DefaultTextStyle.of(context).style;
        final painter = TextPainter(
          text: TextSpan(text: text, style: effectiveStyle),
          maxLines: 1,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout();
        final fits = painter.width <= constraints.maxWidth;
        final shrinkEnough = painter.width * minScale <= constraints.maxWidth;
        if (fits || shrinkEnough) {
          return FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              text,
              maxLines: 1,
              softWrap: false,
              style: style,
              textAlign: textAlign,
            ),
          );
        }
        // Would shrink below the readable minimum: wrap to two lines.
        return Text(text, style: style, textAlign: textAlign, maxLines: 2);
      },
    );
  }
}
