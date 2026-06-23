// Dart collection extensions used across services.

extension TemporalSort<T> on List<T> {
  /// Sorts the list in-place by a nullable [DateTime] field.
  /// Null dates are pushed to the end regardless of direction.
  /// [descending] = true (default) → newest first.
  void sortByDate(
    DateTime? Function(T) getDate, {
    bool descending = true,
  }) {
    sort((a, b) {
      final ta = getDate(a);
      final tb = getDate(b);
      if (ta == null && tb == null) return 0;
      if (ta == null) return 1;
      if (tb == null) return -1;
      return descending ? tb.compareTo(ta) : ta.compareTo(tb);
    });
  }
}
