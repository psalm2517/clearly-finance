import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/categories.dart';
import '../theme/catppuccin.dart';

export '../util/streams.dart' show combineLatest;

/// A dollar figure with the cents de-emphasized — smaller and more muted
/// than the whole-dollar part ("$664,735" full weight, ".94" small and
/// gray). Expects [fmtCents]'s own output shape (a single trailing ".NN").
class MoneyText extends StatelessWidget {
  const MoneyText(this.formatted, {super.key, this.style, this.centsColor});

  final String formatted;
  final TextStyle? style;
  final Color? centsColor;

  @override
  Widget build(BuildContext context) {
    final dot = formatted.lastIndexOf('.');
    if (dot == -1) return Text(formatted, style: style);
    final whole = formatted.substring(0, dot);
    final cents = formatted.substring(dot);
    final base = (style ?? DefaultTextStyle.of(context).style).copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final mutedColor =
        centsColor ??
        (base.color ?? Theme.of(context).colorScheme.onSurface).withValues(
          alpha: 0.55,
        );
    return RichText(
      text: TextSpan(
        style: base,
        children: [
          TextSpan(text: whole),
          TextSpan(
            text: cents,
            style: TextStyle(
              color: mutedColor,
              fontSize: (base.fontSize ?? 14) * 0.7,
            ),
          ),
        ],
      ),
    );
  }
}

/// A colored pill — filled background rather than plain colored text — for
/// a delta or a category label, badging every change and every category
/// this way instead of just tinting text.
class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, required this.color, this.fontSize = 12});

  final String text;
  final Color color;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Shared layout constants so every screen lines up. Sized for generous
/// breathing room between sections, rather than packing content edge-to-edge.
const kPagePadding = EdgeInsets.fromLTRB(28, 28, 28, 96);
const kSectionGap = SizedBox(height: 32);

/// Consistent empty state: icon, headline, one line of guidance. Always
/// centered in the content area, never floating at the top of a list.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: scheme.outline),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurface.withValues(alpha: 0.7)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small (i) button that opens a plain-language explanation. Use it wherever
/// a term or threshold isn't self-evident.
class InfoButton extends StatelessWidget {
  const InfoButton({super.key, required this.title, required this.body});

  final String title;

  /// Paragraphs, shown in order.
  final List<String> body;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.info_outline, size: 16),
      tooltip: title,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      padding: EdgeInsets.zero,
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
      onPressed: () => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.info_outline),
          title: Text(title),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final paragraph in body)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      paragraph,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Got it'),
            ),
          ],
        ),
      ),
    );
  }
}

/// The plain translucent surface used by cards, for containers that are not
/// a [Card] (a hand-built panel, a tab pill).
BoxDecoration glassDecoration(BuildContext context, {double radius = 20}) {
  final theme = Theme.of(context);
  final dark = theme.colorScheme.brightness == Brightness.dark;
  return BoxDecoration(
    color: theme.cardTheme.color,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: (dark ? Colors.white : Colors.black).withValues(
        alpha: dark ? 0.09 : 0.08,
      ),
    ),
  );
}

/// A compact pill-shaped tab switcher that is only as wide as its labels.
/// Drives a [TabController], so it replaces a TabBar one for one.
class PillTabs extends StatelessWidget {
  const PillTabs({super.key, required this.controller, required this.labels});

  final TabController controller;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    // Opaque, so nothing behind it shows through unevenly.
    final fill = Color.alphaBlend(
      (dark ? Colors.white : Colors.black).withValues(
        alpha: dark ? 0.07 : 0.05,
      ),
      Theme.of(context).scaffoldBackgroundColor,
    );
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: (dark ? Colors.white : Colors.black).withValues(alpha: 0.09),
        ),
      ),
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < labels.length; i++)
              InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => controller.animateTo(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: i == controller.index
                        ? scheme.primary.withValues(alpha: 0.18)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: i == controller.index
                          ? scheme.onSurface
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Choice between the two kinds of profile, made once when it is created.
class SyncModePicker extends StatelessWidget {
  const SyncModePicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
              value: 'manual',
              icon: Icon(Icons.edit_note),
              label: Text('Manual'),
            ),
            ButtonSegment(
              value: 'synced',
              icon: Icon(Icons.sync),
              label: Text('Synced'),
            ),
          ],
          selected: {value},
          onSelectionChanged: (s) => onChanged(s.first),
        ),
        const SizedBox(height: 8),
        Text(
          value == 'synced'
              ? 'Accounts and transactions come from your bank through '
                    'SimpleFIN. Nothing is typed in by hand.'
              : 'You enter transactions and balances yourself, or import a '
                    'CSV. Nothing connects to a bank.',
          style: TextStyle(color: muted, fontSize: 12.5, height: 1.4),
        ),
        const SizedBox(height: 4),
        Text(
          'This is fixed once the profile is made.',
          style: TextStyle(color: muted, fontSize: 12.5),
        ),
      ],
    );
  }
}

/// The soft colour glow behind the page. Cards are translucent, so this is
/// what gives them something to sit on. Static gradients only (no blur), so
/// it costs nothing while scrolling.
class AmbientBackground extends StatelessWidget {
  const AmbientBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    final glow = dark ? 0.16 : 0.12;
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.9, -1.1),
                  radius: 1.1,
                  colors: [
                    scheme.primary.withValues(alpha: glow),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(1.1, 1.0),
                  radius: 1.0,
                  colors: [
                    scheme.secondary.withValues(alpha: glow * 0.75),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// A hero surface: a tinted gradient fill with a lit top edge. Meant for the
/// one or two cards on a screen that should lead, not for every row.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.tint,
    this.padding = const EdgeInsets.all(24),
  });

  final Widget child;

  /// Colours the fill; defaults to the theme's primary accent.
  final Color? tint;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    final color = tint ?? scheme.primary;
    final radius = BorderRadius.circular(20);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: dark ? 0.22 : 0.16),
            color.withValues(alpha: dark ? 0.05 : 0.04),
          ],
        ),
        border: Border.all(
          color: (dark ? Colors.white : Colors.black).withValues(
            alpha: dark ? 0.12 : 0.08,
          ),
        ),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Section label with an icon, used above every card group.
class SectionHeader extends StatelessWidget {
  const SectionHeader(
    this.title, {
    super.key,
    required this.icon,
    this.action,
    this.info,
    this.iconColor,
  });

  final String title;
  final IconData icon;
  final Widget? action;

  /// Optional (i) explanation shown next to the title.
  final InfoButton? info;

  /// Defaults to the theme's primary accent — override for a section that
  /// represents a specific category/type with its own stable color.
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: iconColor ?? Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
            ),
          ),
          if (info != null) ...[const SizedBox(width: 4), info!],
          if (action != null) ...[const Spacer(), action!],
        ],
      ),
    );
  }
}

/// Headline number tile used on the dashboard and budget screens.
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.note,
    this.info,
    this.width = 260,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? note;
  final InfoButton? info;

  /// Fixed by default so a `Wrap` row of these lines up evenly; pass
  /// `double.infinity` inside an `Expanded` to fill a row instead.
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: GlassCard(
        tint: color,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 28,
              child: Row(
                children: [
                  Icon(icon, size: 16, color: color),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      label.toUpperCase(),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        letterSpacing: 0.9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  ?info,
                ],
              ),
            ),
            const SizedBox(height: 6),
            // Bigger and bolder than the label above it — a clear weight
            // difference between a headline figure and its caption,
            // rather than everything at similar weight.
            MoneyText(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w300,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            // The note line is always reserved, so a row of tiles stays one
            // height whether or not each has a note.
            SizedBox(
              height: 18,
              child: note == null
                  ? null
                  : Text(
                      note!,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: color),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Label/value line used inside detail panes.
class DetailRow extends StatelessWidget {
  const DetailRow(this.label, this.value, {super.key, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface
                    .withValues(alpha: 0.7),
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Text field with consistent spacing for dialogs. Pressing Enter submits
/// the dialog — by default that means the same thing as clicking Save.
class DialogField extends StatelessWidget {
  const DialogField(
    this.controller,
    this.label, {
    super.key,
    this.obscure = false,
    this.autofocus = false,
    this.helper,
    this.onSubmitted,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String label;
  final bool obscure;
  final bool autofocus;
  final String? helper;

  /// False shows the value but does not let it be edited.
  final bool enabled;

  /// Runs on Enter. Defaults to closing the dialog with a `true` result,
  /// which every edit dialog treats as "save".
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        enabled: enabled,
        obscureText: obscure,
        autofocus: autofocus,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) =>
            (onSubmitted ?? () => Navigator.of(context).pop(true))(),
        decoration: InputDecoration(
          labelText: label,
          helperText: helper,
          helperMaxLines: 2,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}

/// Makes Enter trigger [onSubmit] anywhere inside [child], so a dialog can
/// be saved from a dropdown or checkbox, not just from a text field.
class SubmitOnEnter extends StatelessWidget {
  const SubmitOnEnter({super.key, required this.onSubmit, required this.child});

  final VoidCallback onSubmit;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter): onSubmit,
        const SingleActivator(LogicalKeyboardKey.numpadEnter): onSubmit,
      },
      child: FocusScope(child: child),
    );
  }
}

/// Tells the user why a dialog's contents were not saved. Dialogs used to
/// close and silently discard when a required field was missing, which is
/// indistinguishable from the save being broken.
void warnNotSaved(BuildContext context, String reason) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Not saved — $reason'),
      backgroundColor: Theme.of(context).colorScheme.error,
    ),
  );
}

/// Confirm button for something destructive. Red so it reads differently
/// from an ordinary Save at the moment it matters — the point of no return
/// in a delete dialog.
class DangerButton extends StatelessWidget {
  const DangerButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.error,
        foregroundColor: scheme.onError,
      ),
      onPressed: onPressed,
      child: Text(label),
    );
  }
}

/// A stable color for a free-form category name (budget categories, tags),
/// hashed to a fixed index so the same word always draws the same color —
/// no lookup table to maintain as categories are freely typed.
Color categoryColor(BuildContext context, String category) {
  final colors = Theme.of(context).extension<CategoryColors>()!;
  // The built-in categories each get their own colour, in list order, so no
  // two of them ever share one by hash accident. Anything else is hashed.
  final builtIn = defaultSpendingCategories.indexOf(category);
  if (category == Cat.other) {
    return Theme.of(context).colorScheme.onSurfaceVariant;
  }
  return colors.forIndex(builtIn >= 0 ? builtIn : category.hashCode);
}

/// A small colored circle marking a category, matching [categoryColor].
class CategoryDot extends StatelessWidget {
  const CategoryDot(this.category, {super.key, this.size = 10});

  final String category;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: categoryColor(context, category),
      ),
    );
  }
}

/// A small inline trend line, for showing an account's recent balance
/// history without the weight of a full chart. Flat or empty history draws
/// a flat line rather than nothing, so the space doesn't look broken.
class Sparkline extends StatelessWidget {
  const Sparkline({
    super.key,
    required this.values,
    this.width = 64,
    this.height = 24,
    this.color,
  });

  final List<int> values;
  final double width;
  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rising = values.length < 2 || values.last >= values.first;
    final lineColor = color ?? (rising ? scheme.primary : scheme.error);
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _SparklinePainter(values: values, color: lineColor),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.values, required this.color});

  final List<int> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    if (values.length == 1) {
      final y = size.height / 2;
      final flat = Paint()
        ..color = color
        ..strokeWidth = 1.5;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), flat);
      return;
    }

    final minValue = values.reduce((a, b) => a < b ? a : b);
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final range = (maxValue - minValue) == 0 ? 1 : (maxValue - minValue);

    double yFor(int v) =>
        size.height - ((v - minValue) / range) * (size.height - 4) - 2;
    double xFor(int i) => i * size.width / (values.length - 1);

    final path = Path()..moveTo(xFor(0), yFor(values[0]));
    for (var i = 1; i < values.length; i++) {
      path.lineTo(xFor(i), yFor(values[i]));
    }

    final fill = Path.from(path)
      ..lineTo(xFor(values.length - 1), size.height)
      ..lineTo(xFor(0), size.height)
      ..close();
    canvas.drawPath(fill, Paint()..color = color.withValues(alpha: 0.12));

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.values != values || old.color != color;
}
