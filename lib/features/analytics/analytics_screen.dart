import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../core/models/transaction.dart';
import '../../core/services/category_service.dart';
import '../../core/services/currency_service.dart';
import '../../core/services/transaction_service.dart';
import '../../core/theme/app_colors.dart';

/// Stable key for grouping: custom categories use their id, built-ins use enum name.
class _CategoryKey {
  final String key; // customCategoryId or category.name
  final ResolvedCategory resolved;

  const _CategoryKey({required this.key, required this.resolved});

  @override
  bool operator ==(Object other) =>
      other is _CategoryKey && other.key == key;

  @override
  int get hashCode => key.hashCode;
}

class AnalyticsScreen extends StatefulWidget {
  final TransactionService transactionService;
  final CurrencyService currencyService;
  final CategoryService categoryService;
  final ScrollController? scrollController;

  const AnalyticsScreen({
    super.key,
    required this.transactionService,
    required this.currencyService,
    required this.categoryService,
    this.scrollController,
  });

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  late DateTime _selectedMonth;
  int? _tappedSlice; // index of the tapped pie slice

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
  }

  void _prevMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
    });
  }

  void _nextMonth() {
    final now = DateTime.now();
    final next = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
    // Don't go beyond the current month
    if (next.isAfter(DateTime(now.year, now.month))) return;
    setState(() => _selectedMonth = next);
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _selectedMonth.year == now.year && _selectedMonth.month == now.month;
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: ListenableBuilder(
        listenable: Listenable.merge([
          widget.transactionService,
          widget.currencyService,
          widget.categoryService,
        ]),
        builder: (context, _) {
          final fmt = widget.currencyService.formatter;
          final expenses = widget.transactionService
              .transactionsForMonth(_selectedMonth.year, _selectedMonth.month)
              .where((t) => t.isExpense)
              .toList();

          // Group by resolved category (custom categories get their own bucket)
          final Map<_CategoryKey, double> byCategory = {};
          for (final tx in expenses) {
            final resolved = tx.resolveCategory(widget.categoryService.getById);
            final key = _CategoryKey(
              key: tx.customCategoryId ?? tx.category.name,
              resolved: resolved,
            );
            byCategory[key] = (byCategory[key] ?? 0) + tx.amount;
          }
          final sorted = byCategory.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          final total = sorted.fold(0.0, (s, e) => s + e.value);

          return CustomScrollView(
            controller: widget.scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── Header: back + title ──────────────────────────────────
              SliverToBoxAdapter(
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 20,
                            color: AppColors.textPrimary,
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Analytics',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Month selector ────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Prev arrow
                        IconButton(
                          icon: const Icon(
                            Icons.chevron_left_rounded,
                            size: 24,
                          ),
                          color: AppColors.textPrimary,
                          onPressed: _prevMonth,
                        ),

                        // Month label
                        Expanded(
                          child: GestureDetector(
                            onTap: _pickMonth,
                            child: Text(
                              DateFormat('MMMM yyyy').format(_selectedMonth),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ),

                        // Next arrow — dimmed when at current month
                        IconButton(
                          icon: Icon(
                            Icons.chevron_right_rounded,
                            size: 24,
                            color: _isCurrentMonth
                                ? AppColors.textLight
                                : AppColors.textPrimary,
                          ),
                          onPressed: _isCurrentMonth ? null : _nextMonth,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Summary totals ────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _SummaryChip(
                          label: 'Total Spent',
                          value: fmt.format(total),
                          color: AppColors.accent,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SummaryChip(
                          label: 'Categories',
                          value: '${sorted.length}',
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Category breakdown ────────────────────────────────────
              if (sorted.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.bar_chart_rounded,
                          size: 56,
                          color: AppColors.textLight,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No expenses in ${DateFormat('MMMM').format(_selectedMonth)}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                // ── Pie chart ─────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: _SectionLabel('SPENDING BREAKDOWN'),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: _PieChartCard(
                      entries: sorted,
                      total: total,
                      fmt: fmt,
                      tappedIndex: _tappedSlice,
                      onSliceTap: (i) => setState(
                        () => _tappedSlice = _tappedSlice == i ? null : i,
                      ),
                    ),
                  ),
                ),

                // ── Bar chart (last 6 months) ─────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: _SectionLabel('MONTHLY TREND'),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: _BarChartCard(
                      transactionService: widget.transactionService,
                      currentMonth: _selectedMonth,
                      fmt: fmt,
                    ),
                  ),
                ),

                // ── Category list ─────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                    child: _SectionLabel('SPENDING BY CATEGORY'),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final entry = sorted[index];
                      final cat = entry.key.resolved;
                      final pct = total > 0 ? entry.value / total : 0.0;
                      final isHighlighted =
                          _tappedSlice == null || _tappedSlice == index;

                      return AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: isHighlighted ? 1.0 : 0.35,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: cat.color.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        cat.icon,
                                        color: cat.color,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        cat.label,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      fmt.format(entry.value),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    SizedBox(
                                      width: 40,
                                      child: Text(
                                        '${(pct * 100).toStringAsFixed(0)}%',
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: cat.color,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: pct,
                                    minHeight: 6,
                                    backgroundColor: AppColors.background,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      cat.color,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }, childCount: sorted.length),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  // ── Month picker dialog ───────────────────────────────────────────────────

  Future<void> _pickMonth() async {
    final now = DateTime.now();
    // Build a list of the last 24 months
    final months = List.generate(24, (i) {
      return DateTime(now.year, now.month - i);
    });

    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) =>
          _MonthPickerSheet(months: months, selected: _selectedMonth),
    );

    if (picked != null) {
      setState(() => _selectedMonth = picked);
    }
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
        letterSpacing: 1.0,
      ),
    );
  }
}

// ── Pie chart card ────────────────────────────────────────────────────────────

class _PieChartCard extends StatelessWidget {
  final List<MapEntry<_CategoryKey, double>> entries;
  final double total;
  final NumberFormat fmt;
  final int? tappedIndex;
  final void Function(int) onSliceTap;

  const _PieChartCard({
    required this.entries,
    required this.total,
    required this.fmt,
    required this.tappedIndex,
    required this.onSliceTap,
  });

  @override
  Widget build(BuildContext context) {
    final List<MapEntry<_CategoryKey, double>> display;
    if (entries.length <= 6) {
      display = entries;
    } else {
      final top5 = entries.take(5).toList();
      final otherTotal = entries.skip(5).fold(0.0, (s, e) => s + e.value);
      display = [
        ...top5,
        MapEntry(
          _CategoryKey(
            key: 'other',
            resolved: ResolvedCategory(
              label: 'Other',
              icon: Icons.category_rounded,
              color: const Color(0xFF95A5A6),
            ),
          ),
          otherTotal,
        ),
      ];
    }

    final highlighted = tappedIndex != null && tappedIndex! < display.length
        ? display[tappedIndex!]
        : null;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 200,
            child: Row(
              children: [
                // ── Donut ──────────────────────────────────────────────
                SizedBox(
                  width: 200,
                  height: 200,
                  child: GestureDetector(
                    onTapUp: (details) {
                      const size = 200.0;
                      const centre = Offset(size / 2, size / 2);
                      final tap = details.localPosition;
                      final dx = tap.dx - centre.dx;
                      final dy = tap.dy - centre.dy;
                      final dist = math.sqrt(dx * dx + dy * dy);
                      const outerR = size / 2 - 8;
                      const innerR = outerR * 0.55;
                      if (dist > outerR + 8 || dist < innerR) return;
                      double angle = math.atan2(dy, dx) + math.pi / 2;
                      if (angle < 0) angle += 2 * math.pi;
                      double cumulative = 0;
                      for (int i = 0; i < display.length; i++) {
                        final sweep =
                            (display[i].value / total) * 2 * math.pi;
                        if (angle <= cumulative + sweep) {
                          onSliceTap(i);
                          return;
                        }
                        cumulative += sweep;
                      }
                    },
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CustomPaint(
                          size: const Size(200, 200),
                          painter: _PieChartPainter(
                            entries: display,
                            total: total,
                            tappedIndex: tappedIndex,
                          ),
                        ),
                        // Centre label
                        SizedBox(
                          width: 88,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: highlighted != null
                                ? Column(
                                    key: ValueKey(tappedIndex),
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        highlighted.key.resolved.icon,
                                        size: 16,
                                        color: highlighted.key.resolved.color,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        fmt.format(highlighted.value),
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: highlighted.key.resolved.color,
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        '${(highlighted.value / total * 100).toStringAsFixed(1)}%',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textSecondary,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  )
                                : Column(
                                    key: const ValueKey('total'),
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        fmt.format(total),
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary,
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const Text(
                                        'Total',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSecondary,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 16),

                // ── Legend ─────────────────────────────────────────────
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: display.asMap().entries.map((e) {
                      final idx = e.key;
                      final entry = e.value;
                      final cat = entry.key.resolved;
                      final isSelected = tappedIndex == idx;
                      final isDimmed =
                          tappedIndex != null && tappedIndex != idx;
                      return GestureDetector(
                        onTap: () => onSliceTap(idx),
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 180),
                          opacity: isDimmed ? 0.35 : 1.0,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  width: isSelected ? 12 : 8,
                                  height: isSelected ? 12 : 8,
                                  decoration: BoxDecoration(
                                    color: cat.color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    cat.label,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: isSelected
                                          ? cat.color
                                          : AppColors.textSecondary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  '${(entry.value / total * 100).toStringAsFixed(0)}%',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected
                                        ? cat.color
                                        : AppColors.textLight,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Tap a slice to see details',
              style: TextStyle(fontSize: 11, color: AppColors.textLight),
            ),
          ),
        ],
      ),
    );
  }
}

class _PieChartPainter extends CustomPainter {
  final List<MapEntry<_CategoryKey, double>> entries;
  final double total;
  final int? tappedIndex;

  const _PieChartPainter({
    required this.entries,
    required this.total,
    required this.tappedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 3.0;
    const explode = 8.0;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final outerR = cx - 8;
    final innerR = outerR * 0.55;
    double startAngle = -math.pi / 2;

    for (int i = 0; i < entries.length; i++) {
      final sweep = (entries[i].value / total) * 2 * math.pi;
      final isSelected = tappedIndex == i;
      final midAngle = startAngle + sweep / 2;

      final ox = isSelected ? math.cos(midAngle) * explode : 0.0;
      final oy = isSelected ? math.sin(midAngle) * explode : 0.0;
      final centre = Offset(cx + ox, cy + oy);

      final color = tappedIndex != null && !isSelected
          ? entries[i].key.resolved.color.withValues(alpha: 0.25)
          : entries[i].key.resolved.color;

      // Slice fill
      final fillPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      final path = Path()
        ..moveTo(centre.dx + innerR * math.cos(startAngle),
            centre.dy + innerR * math.sin(startAngle))
        ..lineTo(centre.dx + outerR * math.cos(startAngle),
            centre.dy + outerR * math.sin(startAngle))
        ..arcTo(Rect.fromCircle(center: centre, radius: outerR),
            startAngle, sweep, false)
        ..lineTo(centre.dx + innerR * math.cos(startAngle + sweep),
            centre.dy + innerR * math.sin(startAngle + sweep))
        ..arcTo(Rect.fromCircle(center: centre, radius: innerR),
            startAngle + sweep, -sweep, false)
        ..close();

      canvas.drawPath(path, fillPaint);

      // White gap between slices
      final gapPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;
      canvas.drawPath(path, gapPaint);

      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(_PieChartPainter old) =>
      old.tappedIndex != tappedIndex || old.entries != entries;
}

// ── Bar chart card ────────────────────────────────────────────────────────────

class _BarChartCard extends StatelessWidget {
  final TransactionService transactionService;
  final DateTime currentMonth;
  final NumberFormat fmt;

  const _BarChartCard({
    required this.transactionService,
    required this.currentMonth,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    // Build last 6 months ending at currentMonth
    final months = List.generate(6, (i) {
      return DateTime(currentMonth.year, currentMonth.month - (5 - i));
    });

    final incomeData = months.map((m) {
      return transactionService.incomeForMonth(m.year, m.month);
    }).toList();

    final expenseData = months.map((m) {
      return transactionService.expensesForMonth(m.year, m.month);
    }).toList();

    final maxVal = [
      ...incomeData,
      ...expenseData,
    ].fold(0.0, (m, v) => v > m ? v : m);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Legend
          Row(
            children: [
              _legendDot(const Color(0xFF2D9E6B), 'Income'),
              const SizedBox(width: 16),
              _legendDot(AppColors.accent, 'Expenses'),
            ],
          ),
          const SizedBox(height: 20),
          // Bars
          SizedBox(
            height: 160,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(months.length, (i) {
                final income = maxVal > 0 ? incomeData[i] / maxVal : 0.0;
                final expense = maxVal > 0 ? expenseData[i] / maxVal : 0.0;
                final label = DateFormat('MMM').format(months[i]);
                final isCurrent =
                    months[i].year == currentMonth.year &&
                    months[i].month == currentMonth.month;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Bar group
                        SizedBox(
                          height: 130,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Income bar
                              _Bar(
                                ratio: income,
                                color: const Color(0xFF2D9E6B),
                                maxHeight: 130,
                              ),
                              const SizedBox(width: 3),
                              // Expense bar
                              _Bar(
                                ratio: expense,
                                color: AppColors.accent,
                                maxHeight: 130,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Month label
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isCurrent
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isCurrent
                                ? AppColors.primary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  final double ratio;
  final Color color;
  final double maxHeight;

  const _Bar({
    required this.ratio,
    required this.color,
    required this.maxHeight,
  });

  @override
  Widget build(BuildContext context) {
    final h = (ratio * maxHeight).clamp(3.0, maxHeight);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      width: 10,
      height: h,
      decoration: BoxDecoration(
        color: ratio > 0 ? color : color.withValues(alpha: 0.12),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
      ),
    );
  }
}

// ── Summary chip ──────────────────────────────────────────────────────────────

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ── Month picker bottom sheet ─────────────────────────────────────────────────

class _MonthPickerSheet extends StatelessWidget {
  final List<DateTime> months;
  final DateTime selected;

  const _MonthPickerSheet({required this.months, required this.selected});

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Handle
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textLight,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Select Month',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPadding + 16),
            itemCount: months.length,
            itemBuilder: (_, i) {
              final month = months[i];
              final isSelected =
                  month.year == selected.year && month.month == selected.month;
              return InkWell(
                onTap: () => Navigator.of(context).pop(month),
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.08)
                        : AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        DateFormat('MMMM yyyy').format(month),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      if (isSelected)
                        Container(
                          width: 22,
                          height: 22,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
