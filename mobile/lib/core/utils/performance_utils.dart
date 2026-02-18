import 'dart:async';
import 'dart:collection';

/// A debounce utility that delays execution until a specified [duration] has
/// passed without another call.
///
/// Usage:
/// ```dart
/// final debounce = Debounce(duration: Duration(milliseconds: 300));
/// debounce.run(() => doSomething());
/// // ...later, when no longer needed:
/// debounce.dispose();
/// ```
class Debounce {
  final Duration duration;
  Timer? _timer;

  Debounce({required this.duration});

  /// Schedule [action] to run after [duration]. If [run] is called again
  /// before the timer fires, the previous pending action is cancelled and
  /// the timer resets.
  void run(void Function() action) {
    _timer?.cancel();
    _timer = Timer(duration, action);
  }

  /// Whether there is a pending action waiting to fire.
  bool get isPending => _timer?.isActive ?? false;

  /// Cancel any pending action without firing it.
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  /// Cancel any pending action and release resources.
  void dispose() {
    cancel();
  }
}

/// A throttle utility that ensures an action executes at most once per
/// [duration] window.
///
/// The first call within a window executes immediately (leading-edge). If
/// [trailing] is true, the most recent call during a throttle window is also
/// executed once the window expires.
///
/// Usage:
/// ```dart
/// final throttle = Throttle(duration: Duration(milliseconds: 500));
/// throttle.run(() => sendUpdate());
/// // ...later:
/// throttle.dispose();
/// ```
class Throttle {
  final Duration duration;
  final bool trailing;

  Timer? _timer;
  void Function()? _pendingAction;
  bool _isThrottled = false;

  Throttle({required this.duration, this.trailing = true});

  /// Execute [action] immediately if not currently throttled; otherwise,
  /// if [trailing] is true, queue it to run when the throttle window ends.
  void run(void Function() action) {
    if (!_isThrottled) {
      // Leading edge: execute immediately.
      action();
      _isThrottled = true;
      _pendingAction = null;
      _timer = Timer(duration, _onTimerComplete);
    } else if (trailing) {
      // Store the latest action to fire at the trailing edge.
      _pendingAction = action;
    }
  }

  void _onTimerComplete() {
    _isThrottled = false;
    if (_pendingAction != null) {
      final action = _pendingAction!;
      _pendingAction = null;
      run(action);
    }
  }

  /// Whether the throttle is currently active (blocking new calls).
  bool get isThrottled => _isThrottled;

  /// Cancel any pending trailing action and reset the throttle.
  void cancel() {
    _timer?.cancel();
    _timer = null;
    _pendingAction = null;
    _isThrottled = false;
  }

  /// Cancel any pending action and release resources.
  void dispose() {
    cancel();
  }
}

/// A simple memory-bounded Least Recently Used (LRU) cache.
///
/// Useful for caching decoded card images, computed layouts, or any
/// expensive-to-create objects to avoid redundant work during rebuilds.
///
/// The cache stores at most [maxSize] entries. When a new entry is inserted
/// and the cache is full, the least recently accessed entry is evicted.
///
/// Usage:
/// ```dart
/// final cache = LruCache<String, ui.Image>(maxSize: 52); // one per card
/// cache.put('Ah', decodedImage);
/// final image = cache.get('Ah'); // moves 'Ah' to most-recently-used
/// ```
class LruCache<K, V> {
  final int maxSize;

  /// Internally we use a [LinkedHashMap] which maintains insertion order.
  /// On access we re-insert the key to move it to the end (most recent).
  final LinkedHashMap<K, V> _map = LinkedHashMap<K, V>();

  LruCache({required this.maxSize}) : assert(maxSize > 0);

  /// Retrieve the value for [key], or `null` if not present.
  ///
  /// Accessing a key marks it as most-recently-used.
  V? get(K key) {
    final value = _map.remove(key);
    if (value != null) {
      // Re-insert to move to the end (most recent).
      _map[key] = value;
    }
    return value;
  }

  /// Insert or update a [key]-[value] pair.
  ///
  /// If the cache is at capacity and [key] is new, the least recently used
  /// entry is evicted first. Returns the evicted value (if any) so callers
  /// can dispose of resources.
  V? put(K key, V value) {
    V? evicted;

    // If the key already exists, remove it first so re-insertion places it
    // at the end.
    _map.remove(key);

    // Evict the oldest entry if we are at capacity.
    if (_map.length >= maxSize) {
      final oldestKey = _map.keys.first;
      evicted = _map.remove(oldestKey);
    }

    _map[key] = value;
    return evicted;
  }

  /// Remove a specific [key] from the cache. Returns the removed value or
  /// `null`.
  V? remove(K key) => _map.remove(key);

  /// Whether the cache contains [key] (does NOT affect recency).
  bool containsKey(K key) => _map.containsKey(key);

  /// The current number of entries in the cache.
  int get length => _map.length;

  /// Whether the cache is empty.
  bool get isEmpty => _map.isEmpty;

  /// Remove all entries from the cache.
  void clear() => _map.clear();

  /// All keys, ordered from least recently used to most recently used.
  Iterable<K> get keys => _map.keys;

  /// All values, ordered from least recently used to most recently used.
  Iterable<V> get values => _map.values;
}
