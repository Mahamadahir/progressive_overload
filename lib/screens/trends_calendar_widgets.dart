part of 'trends_calendar_page.dart';

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _Stat(this.label, this.value, this.icon);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
          Text(value),
        ],
      ),
    );
  }
}

class _Wd extends StatelessWidget {
  final String t;
  const _Wd(this.t);
  @override
  Widget build(BuildContext context) => Expanded(
    child: Center(
      child: Text(t, style: const TextStyle(fontWeight: FontWeight.w600)),
    ),
  );
}

class _DayCell extends StatelessWidget {
  final DateTime? date;
  final Color? background;
  final bool stepsOk;
  final VoidCallback? onTap;
  final _DaySummary? summary;
  final bool enabled;

  const _DayCell({
    this.date,
    this.background,
    this.stepsOk = false,
    this.onTap,
    this.summary,
    this.enabled = true,
  });

  const _DayCell.empty()
    : date = null,
      background = null,
      stepsOk = false,
      onTap = null,
      summary = null,
      enabled = false;

  @override
  Widget build(BuildContext context) {
    if (date == null) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(8),
        ),
      );
    }

    final text = Text(
      '${date!.day}',
      style: TextStyle(
        fontWeight: FontWeight.w600,
        color: enabled ? null : Colors.grey,
      ),
    );

    return Material(
      color:
          background ?? Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Stack(
            children: [
              Align(alignment: Alignment.topLeft, child: text),
              if (summary != null)
                Align(
                  alignment: Alignment.bottomLeft,
                  child: Text(
                    // tiny preview: net kcal
                    summary!.netKcal.toStringAsFixed(0),
                    style: TextStyle(
                      fontSize: 11,
                      color: enabled
                          ? Colors.black.withValues(alpha: 0.7)
                          : Colors.grey.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              if (stepsOk && enabled)
                const Align(
                  alignment: Alignment.topRight,
                  child: Icon(Icons.directions_walk, size: 14),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DaySummary {
  final DateTime date;
  final double kcalIn;
  final double kcalOut;
  final double netKcal; // out - in
  final List<MealLog> meals;
  final int? steps;
  final double? weightKg;
  final int workoutsCount;
  final int workoutsKcal;

  _DaySummary({
    required this.date,
    this.kcalIn = 0,
    this.kcalOut = 0,
    this.netKcal = 0,
    this.meals = const [],
    this.steps,
    this.weightKg,
    this.workoutsCount = 0,
    this.workoutsKcal = 0,
  });
}
