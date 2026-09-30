import 'package:flutter/foundation.dart';

/// Process-wide, in-memory record cache.
///
/// Mirrors the caching mobo_sales does with its static `_cachedQuotations` /
/// `_lastFetchTime` pairs, but keyed and in one place so every provider gets the
/// same behaviour:
///
/// * a **fresh** read ([readFresh]) serves a recent result without a round trip,
///   so returning to a list doesn't re-fetch and flicker;
/// * a **stale** read ([read]) serves the last known result regardless of age,
///   which is what screens fall back to when the device is offline or a request
///   fails.
///
/// Entries are static, so they survive provider disposal and screen rebuilds but
/// not an app restart — the same lifetime mobo_sales' caches have.
class DataCache {
  DataCache._();

  /// Freshness window for list/detail reads. Matches mobo_sales' 5 minutes.
  static const Duration defaultTtl = Duration(minutes: 5);

  /// Longer window for reference data that rarely changes (journals, taxes,
  /// payment terms, currencies) — mobo_sales uses 10 minutes for these.
  static const Duration referenceTtl = Duration(minutes: 10);

  static final Map<String, _CacheEntry> _entries = {};

  /// Stores [value] under [key], replacing any previous entry.
  static void write(String key, Object? value) {
    if (value == null) return;
    _entries[key] = _CacheEntry(value, DateTime.now());
  }

  /// Returns the cached value whatever its age, or `null` if nothing is stored.
  ///
  /// This is the offline path: stale data beats an empty screen.
  static T? read<T>(String key) {
    final entry = _entries[key];
    if (entry == null) return null;
    final value = entry.value;
    return value is T ? value as T : null;
  }

  /// Returns the cached value only while it is younger than [ttl].
  static T? readFresh<T>(String key, {Duration ttl = defaultTtl}) {
    final entry = _entries[key];
    if (entry == null) return null;
    if (DateTime.now().difference(entry.storedAt) >= ttl) return null;
    final value = entry.value;
    return value is T ? value as T : null;
  }

  /// When [key] was last written, or `null` when nothing is stored.
  static DateTime? updatedAt(String key) => _entries[key]?.storedAt;

  static bool has(String key) => _entries.containsKey(key);

  static bool isFresh(String key, {Duration ttl = defaultTtl}) {
    final storedAt = _entries[key]?.storedAt;
    if (storedAt == null) return false;
    return DateTime.now().difference(storedAt) < ttl;
  }

  static void invalidate(String key) => _entries.remove(key);

  /// Drops every entry whose key starts with [prefix] — used after a write so
  /// the affected model's list and detail entries are all refetched.
  static void invalidatePrefix(String prefix) {
    _entries.removeWhere((key, _) => key.startsWith(prefix));
  }

  /// Clears everything. Called on logout / account switch so one user's records
  /// can never surface under another's session.
  static void clear() => _entries.clear();

  /// Runs [fetch] behind the cache: a fresh entry short-circuits the call, an
  /// offline device gets the stored value, and a failure falls back to it.
  ///
  /// Used by the form screens for reference data (taxes, journals, payment
  /// terms, currencies, UoMs) so a form still opens with its pickers populated
  /// when the device has no connection.
  static Future<T?> cachedFetch<T>(
    String key,
    Future<T> Function() fetch, {
    Duration ttl = referenceTtl,
    bool isOffline = false,
  }) async {
    if (isOffline) return read<T>(key);

    final fresh = readFresh<T>(key, ttl: ttl);
    if (fresh != null) return fresh;

    try {
      final value = await fetch();
      write(key, value);
      return value;
    } catch (e) {
      final cached = read<T>(key);
      if (cached != null) return cached;
      rethrow;
    }
  }

  @visibleForTesting
  static int get entryCount => _entries.length;

  // --- Key builders --------------------------------------------------------
  // Keeping key construction here stops the providers from drifting apart on
  // naming and makes prefix invalidation reliable.

  static const String invoicePrefix = 'invoice';
  static const String creditNotePrefix = 'credit_note';
  static const String paymentPrefix = 'payment';
  static const String customerPrefix = 'customer';
  static const String productPrefix = 'product';
  static const String dashboardPrefix = 'dashboard';
  static const String referencePrefix = 'reference';

  /// Key for a model's most recent list result.
  static String listKey(String prefix) => '$prefix:list';

  /// Key for a single record's detail payload.
  static String detailKey(String prefix, int id) => '$prefix:detail:$id';

  /// Key for a named sub-resource of a record (payments of an invoice, …).
  static String relatedKey(String prefix, int id, String name) =>
      '$prefix:$name:$id';

  /// Key for reference data shared by the form screens.
  static String referenceKey(String name) => '$referencePrefix:$name';
}

class _CacheEntry {
  const _CacheEntry(this.value, this.storedAt);

  final Object value;
  final DateTime storedAt;
}

/// A list payload plus the total count the server reported for it.
///
/// Lists are paginated, so the count has to be cached alongside the rows or the
/// pagination bar reads `0-0/0` while cached rows are on screen.
class CachedList<T> {
  const CachedList(this.items, this.totalCount);

  final List<T> items;
  final int totalCount;
}
