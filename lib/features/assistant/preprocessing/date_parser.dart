/// Resolves relative dates in natural language to ISO date strings.
class RelativeDateParser {
  RelativeDateParser({DateTime? reference})
    : _reference = reference ?? DateTime.now();

  final DateTime _reference;

  static final RegExp _relativePattern = RegExp(
    r'\b(today|yesterday|tomorrow|last\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday)|'
    r'this\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday)|'
    r'(\d{1,2})\s+(days?\s+)?ago|last\s+week|this\s+week|last\s+month|this\s+month)\b',
    caseSensitive: false,
  );

  static final RegExp _isoPattern = RegExp(
    r'\b(\d{4}-\d{2}-\d{2})\b',
  );

  /// Returns ISO date (yyyy-MM-dd) and confidence.
  ({String? dateIso, double confidence}) parse(String text) {
    final isoMatch = _isoPattern.firstMatch(text);
    if (isoMatch != null) {
      return (dateIso: isoMatch.group(1), confidence: 1.0);
    }

    final lower = text.toLowerCase();
    final match = _relativePattern.firstMatch(lower);
    if (match == null) {
      return (dateIso: _toIso(_reference), confidence: 0.6);
    }

    final token = match.group(0)!.trim();
    final resolved = _resolveToken(token);
    if (resolved == null) {
      return (dateIso: _toIso(_reference), confidence: 0.5);
    }

    return (dateIso: _toIso(resolved), confidence: 0.92);
  }

  DateTime? _resolveToken(String token) {
    final today = DateTime(_reference.year, _reference.month, _reference.day);

    switch (token) {
      case 'today':
        return today;
      case 'yesterday':
        return today.subtract(const Duration(days: 1));
      case 'tomorrow':
        return today.add(const Duration(days: 1));
      case 'last week':
        return today.subtract(const Duration(days: 7));
      case 'this week':
        return today;
      case 'last month':
        return DateTime(today.year, today.month - 1, today.day);
      case 'this month':
        return today;
    }

    final daysAgo = RegExp(r'(\d+)\s+days?\s+ago').firstMatch(token);
    if (daysAgo != null) {
      final n = int.parse(daysAgo.group(1)!);
      return today.subtract(Duration(days: n));
    }

    final lastDay = RegExp(
      r'last\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday)',
    ).firstMatch(token);
    if (lastDay != null) {
      return _previousWeekday(today, lastDay.group(1)!);
    }

    final thisDay = RegExp(
      r'this\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday)',
    ).firstMatch(token);
    if (thisDay != null) {
      return _thisWeekday(today, thisDay.group(1)!);
    }

    return null;
  }

  DateTime _previousWeekday(DateTime from, String dayName) {
    final target = _weekdayIndex(dayName);
    var d = from.subtract(const Duration(days: 1));
    while (d.weekday != target) {
      d = d.subtract(const Duration(days: 1));
    }
    return d;
  }

  DateTime _thisWeekday(DateTime from, String dayName) {
    final target = _weekdayIndex(dayName);
    var d = from;
    while (d.weekday != target) {
      d = d.subtract(const Duration(days: 1));
    }
    return d;
  }

  int _weekdayIndex(String name) {
    const map = {
      'monday': DateTime.monday,
      'tuesday': DateTime.tuesday,
      'wednesday': DateTime.wednesday,
      'thursday': DateTime.thursday,
      'friday': DateTime.friday,
      'saturday': DateTime.saturday,
      'sunday': DateTime.sunday,
    };
    return map[name.toLowerCase()] ?? DateTime.monday;
  }

  static String _toIso(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
