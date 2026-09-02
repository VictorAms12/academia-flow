import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'motion.dart';

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return MotionEntrance(
      duration: MotionSpec.fast,
      offset: const Offset(0, .02),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.4,
                  ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class SoftCard extends StatefulWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  State<SoftCard> createState() => _SoftCardState();
}

class _SoftCardState extends State<SoftCard> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final translateY = reduceMotion ? 0.0 : (_hovered ? -2.0 : 0.0);
    final scale = reduceMotion ? 1.0 : (_pressed ? .985 : 1.0);

    final card = AnimatedScale(
      scale: scale,
      duration: MotionSpec.micro,
      curve: MotionSpec.spring,
      child: AnimatedContainer(
        duration: MotionSpec.fast,
        curve: MotionSpec.curve,
        transform: Matrix4.translationValues(0, translateY, 0),
        padding: widget.padding,
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _hovered
                ? AppColors.gold.withValues(alpha: dark ? .22 : .18)
                : dark
                    ? Colors.white.withValues(alpha: .06)
                    : Colors.black.withValues(alpha: .05),
          ),
          boxShadow: dark
              ? (_hovered
                  ? [BoxShadow(blurRadius: 28, offset: const Offset(0, 10), color: Colors.black.withValues(alpha: .16))]
                  : null)
              : [
                  BoxShadow(
                    blurRadius: _hovered ? 28 : 22,
                    offset: Offset(0, _hovered ? 12 : 8),
                    color: Colors.black.withValues(alpha: _hovered ? .055 : .035),
                  ),
                ],
        ),
        child: widget.child,
      ),
    );

    return MotionEntrance(
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() {
          _hovered = false;
          _pressed = false;
        }),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            onHighlightChanged: widget.onTap == null ? null : (v) => setState(() => _pressed = v),
            borderRadius: BorderRadius.circular(16),
            child: card,
          ),
        ),
      ),
    );
  }
}

class GoldBadge extends StatelessWidget {
  const GoldBadge(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: MotionSpec.fast,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gold.withValues(alpha: .22)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.gold,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 22),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Column(
              children: [
                MotionEntrance(
                  duration: MotionSpec.emphasized,
                  offset: const Offset(0, .10),
                  child: Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(icon, size: 30, color: Theme.of(context).colorScheme.primary),
                  ),
                ),
                const SizedBox(height: 15),
                Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5)),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: onAction,
                    icon: const Icon(Icons.add_rounded),
                    label: Text(actionLabel!),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PageHeader extends StatelessWidget {
  const PageHeader({super.key, required this.title, required this.subtitle, this.action});
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return MotionEntrance(
      duration: MotionSpec.normal,
      offset: const Offset(0, .04),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                      ),
                ),
                const SizedBox(height: 5),
                Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

String formatDate(DateTime date) {
  const months = ['JAN', 'FEV', 'MAR', 'ABR', 'MAI', 'JUN', 'JUL', 'AGO', 'SET', 'OUT', 'NOV', 'DEZ'];
  return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]}';
}

String dayName(int day) {
  const days = ['', 'Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado', 'Domingo'];
  return day >= 1 && day <= 7 ? days[day] : '';
}
