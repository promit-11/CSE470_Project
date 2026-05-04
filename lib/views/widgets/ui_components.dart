import 'package:flutter/material.dart';

const double _sectionRadius = 18;
const double _controlRadius = 12;

/// Reusable card section with consistent styling and heading
class SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final IconData? icon;
  final List<Widget>? actions;
  final EdgeInsets padding;

  const SectionCard({
    required this.title,
    required this.child,
    this.icon,
    this.actions,
    this.padding = const EdgeInsets.all(16),
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_sectionRadius),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.14)),
      ),
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      if (icon != null) ...<Widget>[
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            icon,
                            size: 18,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
                if (actions != null)
                  Row(mainAxisSize: MainAxisSize.min, children: actions!),
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

/// Consistent band score display
class BandScoreCard extends StatelessWidget {
  final String label;
  final double score;
  final bool isHighlight;

  const BandScoreCard({
    required this.label,
    required this.score,
    this.isHighlight = false,
    super.key,
  });

  Color _getScoreColor(double score) {
    if (score >= 8.0) return Colors.green;
    if (score >= 7.0) return Colors.blue;
    if (score >= 6.0) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: isHighlight
          ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.35)
          : Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_controlRadius),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.14)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              score.toStringAsFixed(1),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: _getScoreColor(score),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Consistent info row (e.g., "Label: value")
class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;

  const InfoRow({
    required this.label,
    required this.value,
    this.icon,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 18),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// Consistent empty state view
class EmptyStateView extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final Widget? action;

  const EmptyStateView({
    required this.title,
    required this.message,
    this.icon = Icons.inbox,
    this.action,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            elevation: 0,
            color: Theme.of(context).colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_sectionRadius),
              side: BorderSide(color: Colors.grey.withValues(alpha: 0.14)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      size: 40,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                  if (action != null) ...<Widget>[
                    const SizedBox(height: 20),
                    action!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Consistent stat card for dashboards - responsive design
class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? backgroundColor;

  const StatCard({
    required this.label,
    required this.value,
    required this.icon,
    this.backgroundColor,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_controlRadius),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.14)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Responsive design based on available height - aggressive ultra-compact
          final isUltraCompact = constraints.maxHeight < 90;
          final isCompact = constraints.maxHeight < 140;

          final cardPadding = isUltraCompact ? 6.0 : (isCompact ? 12.0 : 16.0);
          final iconSize = isUltraCompact ? 14.0 : (isCompact ? 20.0 : 24.0);
          final iconPadding = isUltraCompact ? 3.0 : (isCompact ? 6.0 : 10.0);
          final spacingAfterIcon = isUltraCompact
              ? 3.0
              : (isCompact ? 8.0 : 12.0);
          final spacingAfterValue = isUltraCompact
              ? 0.5
              : (isCompact ? 2.0 : 4.0);

          return Container(
            decoration: BoxDecoration(
              color: backgroundColor ?? Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(_controlRadius),
            ),
            padding: EdgeInsets.all(cardPadding),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Container(
                  padding: EdgeInsets.all(iconPadding),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    size: iconSize,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                SizedBox(height: spacingAfterIcon),
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: isUltraCompact ? 16 : (isCompact ? 22 : null),
                    height: isUltraCompact ? 1.0 : null,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: spacingAfterValue),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.grey[600],
                    fontSize: isUltraCompact ? 8 : (isCompact ? 11 : null),
                    height: isUltraCompact ? 1.0 : null,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Consistent section progress indicator
class SectionProgress extends StatelessWidget {
  final List<String> sections;
  final int currentIndex;
  final bool completed;

  const SectionProgress({
    required this.sections,
    required this.currentIndex,
    this.completed = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_sectionRadius),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.14)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: List.generate(sections.length, (i) {
                final isCompleted = i < currentIndex;
                final isCurrent = i == currentIndex;
                final color = isCompleted
                    ? Colors.green
                    : isCurrent
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey[300]!;
                return Expanded(
                  child: Column(
                    children: <Widget>[
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color,
                        ),
                        child: Center(
                          child: Text(
                            (i + 1).toString(),
                            style: TextStyle(
                              color: isCompleted || isCurrent
                                  ? Colors.white
                                  : Colors.grey[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        sections[i].toUpperCase(),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: isCurrent
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey[600],
                          fontWeight: isCurrent
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

/// Consistent form input field with better styling
class FormInputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? Function(String?)? validator;
  final TextInputType keyboardType;
  final bool obscureText;
  final int maxLines;
  final IconData? prefixIcon;

  const FormInputField({
    required this.controller,
    required this.label,
    this.hint,
    this.validator,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.maxLines = 1,
    this.prefixIcon,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      maxLines: obscureText ? 1 : maxLines,
      style: Theme.of(context).textTheme.bodyMedium,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_controlRadius),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_controlRadius),
          borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.18)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_controlRadius),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 1.4,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        prefixIconColor: Theme.of(context).colorScheme.primary,
      ),
      validator: validator,
    );
  }
}

/// Consistent button styles
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isLoading;
  final bool isEnabled;
  final IconData? icon;
  final bool fullWidth;

  const PrimaryButton({
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.isEnabled = true,
    this.icon,
    this.fullWidth = true,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final buttonStyle = FilledButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_controlRadius),
      ),
      textStyle: Theme.of(
        context,
      ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
    );
    final button = icon != null
        ? FilledButton.icon(
            style: buttonStyle,
            onPressed: isEnabled && !isLoading ? onPressed : null,
            icon: Icon(icon, size: 18),
            label: Text(label),
          )
        : FilledButton(
            style: buttonStyle,
            onPressed: isEnabled && !isLoading ? onPressed : null,
            child: Text(label),
          );

    if (fullWidth) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }
}

/// Consistent secondary button
class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isEnabled;
  final IconData? icon;
  final bool fullWidth;

  const SecondaryButton({
    required this.label,
    required this.onPressed,
    this.isEnabled = true,
    this.icon,
    this.fullWidth = true,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final buttonStyle = FilledButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_controlRadius),
      ),
      textStyle: Theme.of(
        context,
      ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
    );
    final button = icon != null
        ? FilledButton.tonalIcon(
            style: buttonStyle,
            onPressed: isEnabled ? onPressed : null,
            icon: Icon(icon, size: 18),
            label: Text(label),
          )
        : FilledButton.tonal(
            style: buttonStyle,
            onPressed: isEnabled ? onPressed : null,
            child: Text(label),
          );

    if (fullWidth) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }
}
