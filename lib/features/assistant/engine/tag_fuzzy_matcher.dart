import '../../../core/models/tag.dart';
import '../../../core/services/tag_service.dart';

/// Levenshtein-distance-based tag name matcher.
///
/// Used by [ToolDispatcher] when the user searches transactions by tag name
/// but provides a misspelled or approximate name.
class TagFuzzyMatcher {
  TagFuzzyMatcher({required this.tagService});

  final TagService tagService;

  /// Returns the [Tag] whose name exactly matches [query] (case-insensitive),
  /// or `null` if no exact match exists.
  Tag? exactMatch(String query) {
    final q = query.toLowerCase().trim();
    try {
      return tagService.all.firstWhere((t) => t.name.toLowerCase() == q);
    } catch (_) {
      return null;
    }
  }

  /// Returns up to [maxResults] tags whose names are within
  /// `floor(query.length / 2)` edits of [query], sorted by distance ascending.
  ///
  /// Returns an empty list when no tags are within the threshold.
  List<Tag> fuzzySearch(String query, {int maxResults = 5}) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return [];

    final threshold = q.length ~/ 2;
    final tags = tagService.all;

    final scored = <({Tag tag, int distance})>[];
    for (final tag in tags) {
      final dist = _levenshtein(q, tag.name.toLowerCase());
      if (dist <= threshold) {
        scored.add((tag: tag, distance: dist));
      }
    }

    scored.sort((a, b) => a.distance.compareTo(b.distance));
    return scored.take(maxResults).map((e) => e.tag).toList();
  }

  /// Tries an exact match first; if none found returns fuzzy suggestions.
  ///
  /// Returns a [TagMatchResult] indicating whether an exact match was found,
  /// and if not, provides up to [maxResults] suggestions.
  TagMatchResult resolve(String query, {int maxResults = 5}) {
    final exact = exactMatch(query);
    if (exact != null) {
      return TagMatchResult(exactMatch: exact, suggestions: []);
    }
    final suggestions = fuzzySearch(query, maxResults: maxResults);
    return TagMatchResult(exactMatch: null, suggestions: suggestions);
  }

  // ── Levenshtein distance ──────────────────────────────────────────────────

  /// Standard dynamic-programming edit distance between [a] and [b].
  static int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    // Use two rows to keep memory O(min(|a|,|b|))
    var prev = List<int>.generate(b.length + 1, (i) => i);
    var curr = List<int>.filled(b.length + 1, 0);

    for (int i = 1; i <= a.length; i++) {
      curr[0] = i;
      for (int j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        curr[j] = [
          prev[j] + 1, // deletion
          curr[j - 1] + 1, // insertion
          prev[j - 1] + cost, // substitution
        ].reduce((a, b) => a < b ? a : b);
      }
      final tmp = prev;
      prev = curr;
      curr = tmp;
    }
    return prev[b.length];
  }
}

/// Result of [TagFuzzyMatcher.resolve].
class TagMatchResult {
  const TagMatchResult({required this.exactMatch, required this.suggestions});

  /// Non-null when an exact (case-insensitive) match was found.
  final Tag? exactMatch;

  /// Fuzzy suggestions when no exact match exists. Empty when exact match found.
  final List<Tag> suggestions;

  bool get hasExactMatch => exactMatch != null;
  bool get hasSuggestions => suggestions.isNotEmpty;
}
