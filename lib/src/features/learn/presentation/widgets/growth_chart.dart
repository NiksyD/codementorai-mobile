import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../domain/dashboard_submission.dart';

enum GrowthView {
  overall,
  correctness,
  readability,
  maintainability,
  efficiency,
}

const Map<GrowthView, String> _viewLabels = <GrowthView, String>{
  GrowthView.overall: 'Overall',
  GrowthView.correctness: 'Correctness',
  GrowthView.readability: 'Readability',
  GrowthView.maintainability: 'Maintainability',
  GrowthView.efficiency: 'Efficiency',
};

/// The choices above the code-review chart.
final List<ChartView> growthViews = <ChartView>[
  for (final GrowthView v in GrowthView.values)
    ChartView(v.name, _viewLabels[v]!),
];

// Survey weights shared with the web (lib/competency/acf.ts).
const double _wCorrectness = 0.2484;
const double _wReadability = 0.2453;
const double _wMaintainability = 0.2516;
const double _wEfficiency = 0.2547;

/// One reviewed submission and the learner's running average after it.
class GrowthPoint {
  const GrowthPoint({
    required this.index,
    required this.submission,
    required this.own,
    required this.running,
  });

  /// 1-based position in time order.
  final int index;
  final DashboardSubmission submission;

  /// This submission's own scores, per view.
  final Map<GrowthView, int> own;

  /// Running average after this submission, per view.
  final Map<GrowthView, int> running;
}

int? _score(Map<String, dynamic> findings, String key) {
  final dynamic block = findings[key];
  if (block is Map && block['score'] is num) {
    return (block['score'] as num).round();
  }
  return null;
}

int _composite(int c, int r, int m, int e) =>
    (c * _wCorrectness +
            r * _wReadability +
            m * _wMaintainability +
            e * _wEfficiency)
        .round();

/// Replays the reviewed submissions in the order they were made. Submissions
/// without all four code-feedback scores are skipped, never filled in.
List<GrowthPoint> computeGrowth(List<DashboardSubmission> submissions) {
  final List<DashboardSubmission> ordered =
      submissions.where((DashboardSubmission s) => s.findings != null).toList()
        ..sort(
          (DashboardSubmission a, DashboardSubmission b) =>
              a.submittedAt.compareTo(b.submittedAt),
        );

  final List<GrowthPoint> points = <GrowthPoint>[];
  double sc = 0, sr = 0, sm = 0, se = 0;
  int n = 0;
  for (final DashboardSubmission s in ordered) {
    final Map<String, dynamic> f = s.findings!;
    final int? c = _score(f, 'correctness');
    final int? r = _score(f, 'readability');
    final int? m = _score(f, 'maintainability');
    final int? e = _score(f, 'efficiency');
    if (c == null || r == null || m == null || e == null) continue;

    sc += c;
    sr += r;
    sm += m;
    se += e;
    n++;
    final int rc = (sc / n).round();
    final int rr = (sr / n).round();
    final int rm = (sm / n).round();
    final int re = (se / n).round();
    points.add(
      GrowthPoint(
        index: n,
        submission: s,
        own: <GrowthView, int>{
          GrowthView.overall: _composite(c, r, m, e),
          GrowthView.correctness: c,
          GrowthView.readability: r,
          GrowthView.maintainability: m,
          GrowthView.efficiency: e,
        },
        running: <GrowthView, int>{
          GrowthView.overall: _composite(rc, rr, rm, re),
          GrowthView.correctness: rc,
          GrowthView.readability: rr,
          GrowthView.maintainability: rm,
          GrowthView.efficiency: re,
        },
      ),
    );
  }
  return points;
}

/// The code-review growth as chart points. Each point opens its submission.
List<ChartPoint> growthChartPoints(
  List<GrowthPoint> growth,
  ValueChanged<DashboardSubmission>? onOpen,
) {
  return <ChartPoint>[
    for (final GrowthPoint p in growth)
      ChartPoint(
        index: p.index,
        date: p.submission.submittedAt,
        title: p.submission.title,
        noun: 'Submission',
        running: <String, int>{
          for (final MapEntry<GrowthView, int> e in p.running.entries)
            e.key.name: e.value,
        },
        own: <String, int>{
          for (final MapEntry<GrowthView, int> e in p.own.entries)
            e.key.name: e.value,
        },
        onOpen: onOpen == null ? null : () => onOpen(p.submission),
      ),
  ];
}

const List<String> _months = <String>[
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

String _dateLabel(DateTime d) => '${_months[d.month - 1]} ${d.day}';

/// One choice in the row above the chart (Overall, Correctness, ...).
class ChartView {
  const ChartView(this.id, this.label);
  final String id;
  final String label;
}

/// One point on the chart: the running value after something happened, plus what to say about it.
class ChartPoint {
  const ChartPoint({
    required this.index,
    required this.date,
    required this.title,
    required this.noun,
    required this.running,
    this.own,
    this.onOpen,
  });

  /// 1-based position in time order, among all points.
  final int index;
  final DateTime date;
  final String title;

  /// "Submission" or "Assessment".
  final String noun;

  /// Value after this point, per view id. A view with no entry has no point here.
  final Map<String, int> running;

  /// This point's own value per view id, when it has one.
  final Map<String, int>? own;

  /// Opens the thing the point stands for. Null when there is nothing to open.
  final VoidCallback? onOpen;
}

/// Growth over time: one line. Tap the chart to pick a point, then open it from the details underneath.
class GrowthChart extends StatefulWidget {
  const GrowthChart({
    super.key,
    required this.points,
    required this.views,
    required this.view,
    required this.onViewChanged,
    required this.textPrimary,
    required this.textSecondary,
    required this.borderColor,
    required this.backgroundColor,
    required this.emptyNone,
    required this.footnote,
    this.emptyFor,
    this.ownLabel,
    this.minPoints = 2,
  });

  final List<ChartPoint> points;
  final List<ChartView> views;

  /// Which view is showing. The parent owns it, so the criteria list above can change it too.
  final String view;
  final ValueChanged<String> onViewChanged;

  final Color textPrimary;
  final Color textSecondary;
  final Color borderColor;
  final Color backgroundColor;

  /// Said when the chart has too few points.
  final String emptyNone;

  /// Said instead, for a given view, when that view specifically has too few points.
  final String? Function(String viewId)? emptyFor;

  final String footnote;

  /// Label for the point's own value, e.g. "This submission".
  final String? ownLabel;

  /// Fewest points needed to draw a line.
  final int minPoints;

  @override
  State<GrowthChart> createState() => _GrowthChartState();
}

class _GrowthChartState extends State<GrowthChart> {
  int? _selected; // index into the points of the current view

  @override
  void didUpdateWidget(covariant GrowthChart old) {
    super.didUpdateWidget(old);
    if (old.view != widget.view) _selected = null;
  }

  Widget _viewRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          for (final ChartView v in widget.views)
            Semantics(
              button: true,
              selected: v.id == widget.view,
              child: InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  widget.onViewChanged(v.id);
                },
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44.0),
                  child: Padding(
                    padding: const EdgeInsets.only(
                      right: 18.0,
                      top: 10.0,
                      bottom: 10.0,
                    ),
                    child: Text(
                      v.label,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.0,
                        fontWeight: v.id == widget.view
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: v.id == widget.view
                            ? widget.textPrimary
                            : widget.textSecondary,
                        decoration: v.id == widget.view
                            ? TextDecoration.underline
                            : null,
                        decorationColor: widget.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _message(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24.0),
      decoration: BoxDecoration(
        border: Border.symmetric(
          horizontal: BorderSide(color: widget.borderColor),
        ),
      ),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13.0,
            color: widget.textSecondary,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String viewId = widget.view;
    final ChartView current = widget.views.firstWhere(
      (ChartView v) => v.id == viewId,
      orElse: () => widget.views.first,
    );
    final List<ChartPoint> pts = widget.points
        .where((ChartPoint p) => p.running.containsKey(viewId))
        .toList();

    if (pts.length < widget.minPoints) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _viewRow(),
          _message(widget.emptyFor?.call(viewId) ?? widget.emptyNone),
        ],
      );
    }

    final int sel = (_selected ?? pts.length - 1).clamp(0, pts.length - 1);
    final ChartPoint selected = pts[sel];
    final int first = pts.first.running[viewId]!;
    final int last = pts.last.running[viewId]!;
    final int change = last - first;
    final String label = current.label;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _viewRow(),
        Text.rich(
          TextSpan(
            children: <InlineSpan>[
              TextSpan(
                text: '$label ',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.0,
                  color: widget.textSecondary,
                ),
              ),
              TextSpan(
                text: '$first% to $last%',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 13.0,
                  color: widget.textPrimary,
                ),
              ),
              if (change != 0)
                TextSpan(
                  text: '  (${change > 0 ? '+' : ''}$change)',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 13.0,
                    color: widget.textSecondary,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12.0),
        Semantics(
          label: '$label over ${pts.length} points, from $first% to $last%',
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints c) {
              void pick(double dx) {
                const double left = _GrowthPainter.leftPad;
                const double right = _GrowthPainter.rightPad;
                final double width = c.maxWidth - left - right;
                if (width <= 0) return;
                final double step = width / (pts.length - 1);
                final int i = ((dx - left) / step).round().clamp(
                  0,
                  pts.length - 1,
                );
                if (i != _selected) HapticFeedback.selectionClick();
                setState(() => _selected = i);
              }

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (TapDownDetails d) => pick(d.localPosition.dx),
                onHorizontalDragUpdate: (DragUpdateDetails d) =>
                    pick(d.localPosition.dx),
                child: CustomPaint(
                  size: Size(c.maxWidth, 200.0),
                  painter: _GrowthPainter(
                    values: <int>[
                      for (final ChartPoint p in pts) p.running[viewId]!,
                    ],
                    dates: <DateTime>[
                      for (final ChartPoint p in pts) p.date.toLocal(),
                    ],
                    selected: sel,
                    line: widget.textPrimary,
                    muted: widget.textSecondary,
                    grid: widget.borderColor,
                    background: widget.backgroundColor,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12.0),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          decoration: BoxDecoration(
            border: Border.symmetric(
              horizontal: BorderSide(color: widget.borderColor),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      selected.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14.0,
                        fontWeight: FontWeight.w600,
                        color: widget.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2.0),
                    Text.rich(
                      TextSpan(
                        children: <InlineSpan>[
                          TextSpan(
                            text: '${selected.noun} ',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.0,
                              color: widget.textSecondary,
                            ),
                          ),
                          TextSpan(
                            text: '${selected.index}',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 12.0,
                              color: widget.textSecondary,
                            ),
                          ),
                          TextSpan(
                            text: ' · ${_dateLabel(selected.date.toLocal())}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.0,
                              color: widget.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6.0),
                    Text.rich(
                      TextSpan(
                        children: <InlineSpan>[
                          TextSpan(
                            text: '$label after this ',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13.0,
                              color: widget.textSecondary,
                            ),
                          ),
                          TextSpan(
                            text: '${selected.running[viewId]}%',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 13.0,
                              color: widget.textPrimary,
                            ),
                          ),
                          if (widget.ownLabel != null &&
                              selected.own?[viewId] != null) ...<InlineSpan>[
                            TextSpan(
                              text: '   ${widget.ownLabel} ',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13.0,
                                color: widget.textSecondary,
                              ),
                            ),
                            TextSpan(
                              text: '${selected.own![viewId]}%',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 13.0,
                                color: widget.textPrimary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (selected.onOpen != null) ...<Widget>[
                const SizedBox(width: 12.0),
                InkWell(
                  onTap: selected.onOpen,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: 48.0,
                      minWidth: 48.0,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          'Open',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13.0,
                            fontWeight: FontWeight.w600,
                            color: widget.textPrimary,
                            decoration: TextDecoration.underline,
                            decorationColor: widget.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 2.0),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 14.0,
                          color: widget.textPrimary,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8.0),
        Text(
          widget.footnote,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12.0,
            height: 1.4,
            color: widget.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _GrowthPainter extends CustomPainter {
  _GrowthPainter({
    required this.values,
    required this.dates,
    required this.selected,
    required this.line,
    required this.muted,
    required this.grid,
    required this.background,
  });

  static const double leftPad = 34.0;
  static const double rightPad = 8.0;
  static const double topPad = 8.0;
  static const double bottomPad = 24.0;

  final List<int> values;
  final List<DateTime> dates;
  final int selected;
  final Color line;
  final Color muted;
  final Color grid;
  final Color background;

  void _text(
    Canvas canvas,
    String t,
    Offset at, {
    bool centered = false,
    bool rightAligned = false,
  }) {
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: t,
        style: GoogleFonts.plusJakartaSans(fontSize: 12.0, color: muted),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    double dx = at.dx;
    if (centered) dx -= tp.width / 2;
    if (rightAligned) dx -= tp.width;
    tp.paint(canvas, Offset(dx, at.dy - tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width - leftPad - rightPad;
    final double h = size.height - topPad - bottomPad;
    final int n = values.length;
    double xOf(int i) => leftPad + (n == 1 ? 0 : i * w / (n - 1));
    double yOf(int v) => topPad + (1 - v / 100.0) * h;

    final Paint gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1.0;
    for (final int tick in <int>[0, 25, 50, 75, 100]) {
      final double y = yOf(tick);
      canvas.drawLine(
        Offset(leftPad, y),
        Offset(size.width - rightPad, y),
        gridPaint,
      );
      _text(canvas, '$tick', Offset(leftPad - 8.0, y), rightAligned: true);
    }

    // Date labels at the first point of each new day, thinned so they never overlap.
    final List<int> firsts = <int>[];
    for (int i = 0; i < n; i++) {
      if (i == 0 || _dateLabel(dates[i]) != _dateLabel(dates[i - 1])) {
        firsts.add(i);
      }
    }
    // Keep a label only if it is at least 72px right of the previous one, so they never overlap.
    double lastX = -1000.0;
    for (final int i in firsts) {
      final double x = min(
        max(xOf(i), leftPad + 18.0),
        size.width - rightPad - 18.0,
      );
      if (x - lastX < 72.0) continue;
      _text(
        canvas,
        _dateLabel(dates[i]),
        Offset(x, size.height - 8.0),
        centered: true,
      );
      lastX = x;
    }

    // The line
    final Path path = Path();
    for (int i = 0; i < n; i++) {
      final Offset p = Offset(xOf(i), yOf(values[i]));
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeJoin = StrokeJoin.round,
    );

    // Selection guide + dots
    canvas.drawLine(
      Offset(xOf(selected), topPad),
      Offset(xOf(selected), topPad + h),
      Paint()
        ..color = muted
        ..strokeWidth = 1.0,
    );
    final bool showDots = n <= 40;
    for (int i = 0; i < n; i++) {
      final Offset p = Offset(xOf(i), yOf(values[i]));
      if (i == selected) {
        canvas.drawCircle(p, 6.0, Paint()..color = line);
        canvas.drawCircle(p, 2.5, Paint()..color = background);
      } else if (showDots) {
        canvas.drawCircle(p, 3.0, Paint()..color = background);
        canvas.drawCircle(
          p,
          3.0,
          Paint()
            ..color = line
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GrowthPainter old) =>
      old.values != values ||
      old.selected != selected ||
      old.line != line ||
      old.background != background;
}

/// A tiny trend line on the same 0-100 scale as the big chart.
class GrowthSparkline extends StatelessWidget {
  const GrowthSparkline({
    super.key,
    required this.values,
    required this.color,
    this.width = 72.0,
    this.height = 28.0,
  });

  final List<int> values;
  final Color color;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) return SizedBox(width: width, height: height);
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size(width, height),
        painter: _SparkPainter(values: values, color: color),
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter({required this.values, required this.color});

  final List<int> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const int maxPoints = 30;
    final int step = max(1, (values.length / maxPoints).ceil());
    final List<int> sampled = <int>[
      for (int i = 0; i < values.length; i++)
        if (i % step == 0 || i == values.length - 1) values[i],
    ];
    final int n = sampled.length;
    Offset at(int i) => Offset(
      2.0 + i * (size.width - 4.0) / (n - 1),
      size.height -
          2.0 -
          (sampled[i].clamp(0, 100) / 100.0) * (size.height - 4.0),
    );
    final Path path = Path()..moveTo(at(0).dx, at(0).dy);
    for (int i = 1; i < n; i++) {
      path.lineTo(at(i).dx, at(i).dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(at(n - 1), 2.5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) =>
      old.values != values || old.color != color;
}
