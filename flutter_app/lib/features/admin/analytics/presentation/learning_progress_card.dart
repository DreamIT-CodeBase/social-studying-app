import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:social_study_app/core/constants/spacing.dart';
import 'package:social_study_app/core/extensions/context_extensions.dart';
import 'package:social_study_app/features/admin/analytics/data/analytics_repository.dart';
import 'package:social_study_app/features/admin/users/presentation/users_notifier.dart';
import 'package:social_study_app/shared/models/learning_progress.dart';
import 'package:social_study_app/shared/models/user.dart';

class LearningProgressCard extends ConsumerStatefulWidget {
  const LearningProgressCard({required this.workspaceId, super.key});

  final String workspaceId;

  @override
  ConsumerState<LearningProgressCard> createState() =>
      _LearningProgressCardState();
}

class _LearningProgressCardState extends ConsumerState<LearningProgressCard> {
  static const _weekPageCount = 4;

  bool _individual = false;
  bool _compareWorkspace = false;
  String? _studentId;
  late final PageController _weekController;
  final Map<int, Future<LearningProgressTrend>> _weekTrends = {};
  final Map<int, int> _selectedPoints = {};

  @override
  void initState() {
    super.initState();
    _weekController = PageController(initialPage: _weekPageCount - 1);
  }

  @override
  void didUpdateWidget(covariant LearningProgressCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workspaceId != widget.workspaceId) {
      _studentId = null;
      _resetTrends();
    }
  }

  @override
  void dispose() {
    _weekController.dispose();
    super.dispose();
  }

  DateTime _weekStart(int page) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final thisMonday = today.subtract(Duration(days: today.weekday - 1));
    final weeksAgo = _weekPageCount - 1 - page;
    return thisMonday.subtract(Duration(days: weeksAgo * 7));
  }

  DateTime _weekEnd(int page) => _weekStart(page).add(const Duration(days: 6));

  Future<LearningProgressTrend> _trendForPage(int page) =>
      _weekTrends.putIfAbsent(
        page,
        () => ref.read(analyticsRepositoryProvider).fetchLearningProgress(
              workspaceId: widget.workspaceId,
              startDate: _weekStart(page),
              endDate: _weekEnd(page),
              studentId: _individual ? _studentId : null,
              compareWorkspace: _individual && _compareWorkspace,
            ),
      );

  void _resetTrends() {
    _weekTrends.clear();
    _selectedPoints.clear();
  }

  void _apply(VoidCallback update) {
    setState(() {
      update();
      _resetTrends();
    });
  }

  @override
  Widget build(BuildContext context) {
    final roster = ref.watch(workspaceUsersListProvider(widget.workspaceId));
    final students = (roster.valueOrNull ?? const <User>[])
        .where((user) => user.role == UserRole.student && user.isActive)
        .toList()
      ..sort((a, b) => a.displayName.compareTo(b.displayName));

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Learning Progress',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _ScopeMenu(
                  individual: _individual,
                  onSelected: (individual) {
                    _apply(() {
                      _individual = individual;
                      if (individual &&
                          _studentId == null &&
                          students.isNotEmpty) {
                        _studentId = students.first.id;
                      }
                    });
                  },
                ),
              ],
            ),
            if (_individual) ...[
              const SizedBox(height: Spacing.sm),
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: Spacing.sm,
                  runSpacing: Spacing.sm,
                  children: [
                    _StudentMenu(
                      students: students,
                      selectedId: _studentId,
                      loading: roster.isLoading,
                      onSelected: (id) => _apply(() => _studentId = id),
                    ),
                    FilterChip(
                      selected: _compareWorkspace,
                      visualDensity: VisualDensity.compact,
                      avatar:
                          const Icon(Icons.compare_arrows_rounded, size: 16),
                      label: const Text('Compare'),
                      onSelected: (selected) =>
                          _apply(() => _compareWorkspace = selected),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: Spacing.md),
            SizedBox(
              height: _individual ? 216 : 236,
              child: PageView.builder(
                controller: _weekController,
                physics: const BouncingScrollPhysics(),
                itemCount: _weekPageCount,
                itemBuilder: (context, page) => _buildTrendPage(context, page),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendPage(BuildContext context, int page) {
    return FutureBuilder<LearningProgressTrend>(
      future: _trendForPage(page),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _TrendError(
            onRetry: () {
              setState(() {
                _weekTrends.remove(page);
                _selectedPoints.remove(page);
              });
            },
          );
        }
        final data = snapshot.data!;
        return Column(
          children: [
            LayoutBuilder(
              builder: (context, constraints) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: data.points.isEmpty
                    ? null
                    : (details) {
                        const plotLeft = 42.0;
                        const plotRight = 8.0;
                        final plotWidth =
                            constraints.maxWidth - plotLeft - plotRight;
                        final ratio =
                            ((details.localPosition.dx - plotLeft) / plotWidth)
                                .clamp(0.0, 1.0);
                        setState(() {
                          _selectedPoints[page] =
                              (ratio * (data.points.length - 1)).round();
                        });
                      },
                onLongPress: !_individual && data.students.isNotEmpty
                    ? () => _showStudents(data)
                    : null,
                child: SizedBox(
                  height: 212,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: _TrendPainter(
                      points: data.points,
                      comparison: data.workspaceComparison,
                      selectedIndex: _selectedPoints[page],
                      colors: const [
                        Color(0xFF6D5DFB),
                        Color(0xFF22C55E),
                        Color(0xFFF97316),
                      ],
                      gridColor: context.colorScheme.outlineVariant,
                      labelColor: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
            if (!_individual && data.students.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _showStudents(data),
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: const Text('View contributing students'),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _showStudents(LearningProgressTrend data) {
    final rows = data.students;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .65,
          child: Column(
            children: [
              Text(
                'Contributing Students',
                style: context.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: Spacing.sm),
              Expanded(
                child: rows.isEmpty
                    ? const Center(child: Text('No students in this group.'))
                    : ListView.separated(
                        padding: const EdgeInsets.all(Spacing.lg),
                        itemCount: rows.length,
                        separatorBuilder: (_, __) => const Divider(),
                        itemBuilder: (context, index) {
                          final student = rows[index];
                          return ListTile(
                            leading: CircleAvatar(
                              child: Text(student.displayName[0].toUpperCase()),
                            ),
                            title: Text(student.displayName),
                            subtitle: Text(
                              '${student.activityCount} activities · '
                              '${_percent(student.quizAccuracy)} quiz accuracy',
                            ),
                            trailing: Text(
                              _percent(student.overallMastery),
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: student.needsAttention
                                    ? context.colorScheme.error
                                    : context.colorScheme.primary,
                              ),
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              _apply(() {
                                _individual = true;
                                _studentId = student.studentId;
                              });
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudentMenu extends StatelessWidget {
  const _StudentMenu({
    required this.students,
    required this.selectedId,
    required this.loading,
    required this.onSelected,
  });

  final List<User> students;
  final String? selectedId;
  final bool loading;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final selected =
        students.where((user) => user.id == selectedId).firstOrNull;
    return PopupMenuButton<String>(
      enabled: students.isNotEmpty,
      onSelected: onSelected,
      itemBuilder: (_) => [
        for (final student in students)
          PopupMenuItem(value: student.id, child: Text(student.displayName)),
      ],
      child: _MenuSurface(
        icon: Icons.person_outline_rounded,
        label: loading
            ? 'Loading students…'
            : selected?.displayName ?? 'Select student',
      ),
    );
  }
}

class _ScopeMenu extends StatelessWidget {
  const _ScopeMenu({
    required this.individual,
    required this.onSelected,
  });

  final bool individual;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) => PopupMenuButton<bool>(
        onSelected: onSelected,
        itemBuilder: (_) => const [
          PopupMenuItem(
            value: false,
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.groups_rounded),
              title: Text('Class / Workspace'),
            ),
          ),
          PopupMenuItem(
            value: true,
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.person_outline_rounded),
              title: Text('Individual Student'),
            ),
          ),
        ],
        child: _MenuSurface(
          icon:
              individual ? Icons.person_outline_rounded : Icons.groups_rounded,
          label: individual ? 'Individual' : 'Class',
        ),
      );
}

class _MenuSurface extends StatelessWidget {
  const _MenuSurface({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(maxWidth: 190),
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 7,
        ),
        decoration: BoxDecoration(
          border: Border.all(color: context.colorScheme.outline),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
            ),
            const Icon(Icons.arrow_drop_down_rounded, size: 18),
          ],
        ),
      );
}

class _TrendError extends StatelessWidget {
  const _TrendError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 212,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Learning progress could not be loaded.'),
              TextButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      );
}

class _TrendPainter extends CustomPainter {
  _TrendPainter({
    required this.points,
    required this.comparison,
    required this.selectedIndex,
    required this.colors,
    required this.gridColor,
    required this.labelColor,
  });

  final List<LearningTrendPoint> points;
  final List<LearningTrendPoint> comparison;
  final int? selectedIndex;
  final List<Color> colors;
  final Color gridColor;
  final Color labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 40.0;
    const top = 8.0;
    const bottom = 30.0;
    final plot = Rect.fromLTRB(left, top, size.width - 8, size.height - bottom);
    for (final percentage in const [0, 25, 50, 75, 100]) {
      final y = plot.bottom - plot.height * percentage / 100;
      _dashedLine(
        canvas,
        Offset(plot.left, y),
        Offset(plot.right, y),
        Paint()
          ..color = gridColor
          ..strokeWidth = 1,
      );
      _text(
        canvas,
        '$percentage%',
        Offset(0, y - 7),
        color: labelColor,
        fontSize: 10,
      );
    }
    if (points.isEmpty) return;

    final mastery = points.map((point) => point.overallMastery).toList();
    final quiz = points.map((point) => point.quizAccuracy).toList();
    final recall = points.map((point) => point.flashcardRecall).toList();
    _fillUnderLine(canvas, plot, mastery, colors[0]);
    _line(canvas, plot, mastery, colors[0]);
    _line(canvas, plot, quiz, colors[1]);
    _line(canvas, plot, recall, colors[2]);

    if (comparison.isNotEmpty) {
      _line(
        canvas,
        plot,
        comparison.map((point) => point.overallMastery).toList(),
        labelColor.withAlpha(150),
        width: 1.5,
        drawPoints: false,
      );
    }

    for (var index = 0; index < points.length; index++) {
      final label = _weekdayLabel(points[index].date);
      final labelPainter = _textPainter(
        label,
        color: labelColor,
        fontSize: 10,
      );
      final x = _x(plot, index, points.length) - labelPainter.width / 2;
      labelPainter.paint(canvas, Offset(x, plot.bottom + 9));
    }

    final selected =
        (selectedIndex ?? points.length - 1).clamp(0, points.length - 1);
    final selectedX = _x(plot, selected, points.length);
    _dashedLine(
      canvas,
      Offset(selectedX, plot.top),
      Offset(selectedX, plot.bottom),
      Paint()
        ..color = labelColor.withAlpha(120)
        ..strokeWidth = 1,
      dash: 4,
      gap: 4,
    );
    _tooltip(canvas, plot, selected);
  }

  void _fillUnderLine(
    Canvas canvas,
    Rect plot,
    List<double> values,
    Color color,
  ) {
    if (values.isEmpty) return;
    final path = Path()..moveTo(_x(plot, 0, values.length), plot.bottom);
    for (var index = 0; index < values.length; index++) {
      path.lineTo(
        _x(plot, index, values.length),
        plot.bottom - plot.height * values[index].clamp(0.0, 1.0),
      );
    }
    path
      ..lineTo(_x(plot, values.length - 1, values.length), plot.bottom)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withAlpha(55), color.withAlpha(0)],
        ).createShader(plot),
    );
  }

  void _tooltip(Canvas canvas, Rect plot, int index) {
    const width = 164.0;
    const height = 102.0;
    final selectedX = _x(plot, index, points.length);
    final left = selectedX > plot.center.dx
        ? (selectedX - width - 10).clamp(plot.left, plot.right - width)
        : (selectedX + 10).clamp(plot.left, plot.right - width);
    final top = (plot.top + 12).clamp(plot.top, plot.bottom - height);
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, width, height),
      const Radius.circular(12),
    );
    canvas.drawRRect(
      rect,
      Paint()..color = const Color(0xF20A172A),
    );
    canvas.drawRRect(
      rect,
      Paint()
        ..color = gridColor
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke,
    );

    final point = points[index];
    _text(
      canvas,
      _longDate(point.date),
      Offset(left + 12, top + 9),
      color: const Color(0xFFE2E8F0),
      fontSize: 11,
      fontWeight: FontWeight.w700,
    );
    _tooltipRow(
      canvas,
      left: left,
      top: top + 34,
      color: colors[0],
      label: 'Overall Mastery',
      value: _percent(point.overallMastery),
    );
    _tooltipRow(
      canvas,
      left: left,
      top: top + 56,
      color: colors[1],
      label: 'Quiz Accuracy',
      value: _percent(point.quizAccuracy),
    );
    _tooltipRow(
      canvas,
      left: left,
      top: top + 78,
      color: colors[2],
      label: 'Flashcard Recall',
      value: _percent(point.flashcardRecall),
    );
  }

  void _tooltipRow(
    Canvas canvas, {
    required double left,
    required double top,
    required Color color,
    required String label,
    required String value,
  }) {
    canvas.drawCircle(Offset(left + 15, top + 6), 4, Paint()..color = color);
    _text(
      canvas,
      label,
      Offset(left + 25, top),
      color: const Color(0xFFCBD5E1),
      fontSize: 9,
    );
    final valuePainter = _textPainter(
      value,
      color: Colors.white,
      fontSize: 9,
      fontWeight: FontWeight.w700,
    );
    valuePainter.paint(
      canvas,
      Offset(left + 152 - valuePainter.width, top),
    );
  }

  void _dashedLine(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint, {
    double dash = 5,
    double gap = 4,
  }) {
    final distance = (end - start).distance;
    if (distance == 0) return;
    final direction = (end - start) / distance;
    var travelled = 0.0;
    while (travelled < distance) {
      final segmentEnd = math.min(travelled + dash, distance);
      canvas.drawLine(
        start + direction * travelled,
        start + direction * segmentEnd,
        paint,
      );
      travelled += dash + gap;
    }
  }

  void _line(
    Canvas canvas,
    Rect plot,
    List<double> values,
    Color color, {
    double width = 2.5,
    bool drawPoints = true,
  }) {
    if (values.isEmpty) return;
    final offsets = [
      for (var index = 0; index < values.length; index++)
        Offset(
          _x(plot, index, values.length),
          plot.bottom - plot.height * values[index].clamp(0.0, 1.0),
        ),
    ];
    final path = Path()..moveTo(offsets.first.dx, offsets.first.dy);
    for (final point in offsets.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = width
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    if (drawPoints) {
      for (final point in offsets) {
        canvas.drawCircle(
          point,
          4,
          Paint()
            ..color = color
            ..style = PaintingStyle.fill,
        );
        canvas.drawCircle(
          point,
          4,
          Paint()
            ..color = color.withAlpha(110)
            ..strokeWidth = 1.5
            ..style = PaintingStyle.stroke,
        );
      }
    }
  }

  double _x(Rect plot, int index, int count) => count == 1
      ? plot.center.dx
      : plot.left + plot.width * index / (count - 1);

  void _text(
    Canvas canvas,
    String text,
    Offset offset, {
    required Color color,
    required double fontSize,
    FontWeight fontWeight = FontWeight.w400,
  }) {
    _textPainter(
      text,
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
    ).paint(canvas, offset);
  }

  TextPainter _textPainter(
    String text, {
    required Color color,
    required double fontSize,
    FontWeight fontWeight = FontWeight.w400,
  }) {
    return TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.comparison != comparison ||
      oldDelegate.selectedIndex != selectedIndex ||
      oldDelegate.gridColor != gridColor;
}

String _percent(double value) => '${(value * 100).toStringAsFixed(1)}%';

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _longDate(DateTime value) =>
    '${_months[value.month - 1]} ${value.day}, ${value.year}';

String _weekdayLabel(DateTime value) =>
    const ['M', 'T', 'W', 'T', 'F', 'S', 'S'][value.weekday - 1];
