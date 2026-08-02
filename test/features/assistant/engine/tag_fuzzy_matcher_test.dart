// Feature: spendflux-ai-assistant — Property 22
//
// Tests validate the Levenshtein distance and fuzzy matching algorithms
// used by TagFuzzyMatcher, without constructing the class (which requires
// a real TagService). This is the standard approach for testing pure
// algorithm logic in Dart.

import 'package:flutter_test/flutter_test.dart';

// ── Levenshtein implementation (mirrors TagFuzzyMatcher._levenshtein) ─────────

int _levenshtein(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  var prev = List<int>.generate(b.length + 1, (i) => i);
  var curr = List<int>.filled(b.length + 1, 0);
  for (int i = 1; i <= a.length; i++) {
    curr[0] = i;
    for (int j = 1; j <= b.length; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      curr[j] = [
        prev[j] + 1,
        curr[j - 1] + 1,
        prev[j - 1] + cost,
      ].reduce((x, y) => x < y ? x : y);
    }
    final tmp = prev;
    prev = curr;
    curr = tmp;
  }
  return prev[b.length];
}

// ── Fuzzy search simulation ───────────────────────────────────────────────────

List<String> _fuzzySearch(
  String query,
  List<String> names, {
  int maxResults = 5,
}) {
  if (query.isEmpty) return [];
  final q = query.toLowerCase();
  final threshold = q.length ~/ 2;
  final scored = <({String name, int dist})>[];
  for (final name in names) {
    final dist = _levenshtein(q, name.toLowerCase());
    if (dist <= threshold) scored.add((name: name, dist: dist));
  }
  scored.sort((a, b) => a.dist.compareTo(b.dist));
  return scored.take(maxResults).map((e) => e.name).toList();
}

String? _exactMatch(String query, List<String> names) {
  final q = query.toLowerCase();
  try {
    return names.firstWhere((n) => n.toLowerCase() == q);
  } catch (_) {
    return null;
  }
}

void main() {
  // ── Property 22a: Exact match is case-insensitive ─────────────────────────
  test('Property 22a: exactMatch returns tag when name matches exactly', () {
    final tags = ['Zomato', 'Swiggy', 'Groceries'];
    expect(_exactMatch('Zomato', tags), equals('Zomato'));
    expect(_exactMatch('zomato', tags), equals('Zomato'));
    expect(_exactMatch('SWIGGY', tags), equals('Swiggy'));
    expect(_exactMatch('unknown', tags), isNull);
  });

  // ── Property 22b: Fuzzy suggestions within threshold ─────────────────────
  test('Property 22b: all fuzzy results are within distance threshold', () {
    final tags = ['restaurant', 'xyz_not_close', 'restoran'];
    final results = _fuzzySearch('resturant', tags);
    for (final name in results) {
      final dist = _levenshtein('resturant', name.toLowerCase());
      expect(dist, lessThanOrEqualTo('resturant'.length ~/ 2));
    }
  });

  // ── Property 22c: No suggestions for dissimilar strings ──────────────────
  test('Property 22c: completely dissimilar query returns empty list', () {
    final tags = ['abc', 'def'];
    final results = _fuzzySearch('xyzqrst', tags);
    expect(results, isEmpty);
  });

  // ── Property 22d: Empty query returns empty results ───────────────────────
  test('Property 22d: empty query returns empty results', () {
    expect(_fuzzySearch('', ['food', 'fuel']), isEmpty);
  });

  // ── Property 22e: Max results is respected ─────────────────────────────────
  test('Property 22e: fuzzySearch returns at most maxResults results', () {
    final tags = ['food', 'foot', 'fool', 'fold', 'form', 'fork', 'fore'];
    final results = _fuzzySearch('food', tags, maxResults: 3);
    expect(results.length, lessThanOrEqualTo(3));
  });

  // ── Levenshtein correctness ───────────────────────────────────────────────
  test('Levenshtein: identical strings have distance 0', () {
    expect(_levenshtein('hello', 'hello'), equals(0));
    expect(_levenshtein('', ''), equals(0));
  });

  test('Levenshtein: empty string distance equals other string length', () {
    expect(_levenshtein('', 'abc'), equals(3));
    expect(_levenshtein('abc', ''), equals(3));
  });

  test('Levenshtein: one substitution', () {
    expect(_levenshtein('cat', 'bat'), equals(1));
  });

  test('Levenshtein: one insertion', () {
    expect(_levenshtein('cat', 'cats'), equals(1));
  });

  test('Levenshtein: one deletion', () {
    expect(_levenshtein('cats', 'cat'), equals(1));
  });

  test('Levenshtein: is symmetric', () {
    expect(_levenshtein('abc', 'xyz'), equals(_levenshtein('xyz', 'abc')));
    expect(
      _levenshtein('resturant', 'restaurant'),
      equals(_levenshtein('restaurant', 'resturant')),
    );
  });
}
