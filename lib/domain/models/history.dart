/// Generic undo/redo container over immutable snapshots.
class History<T> {
  const History({
    required this.present,
    this.past = const [],
    this.future = const [],
  });

  static const int limit = 200;

  final T present;
  final List<T> past;
  final List<T> future;

  bool get canUndo => past.isNotEmpty;
  bool get canRedo => future.isNotEmpty;

  /// Records [next] as a new undoable step.
  History<T> push(T next) {
    if (identical(next, present)) return this;
    return History(present: next, past: _capped([...past, present]));
  }

  /// Replaces the present without recording history (live gesture updates).
  History<T> replacePresent(T next) =>
      History(present: next, past: past, future: future);

  /// Records [base] (the state before a gesture began) as one undoable step.
  History<T> commitFrom(T base) =>
      History(present: present, past: _capped([...past, base]));

  History<T> undo() {
    if (!canUndo) return this;
    return History(
      present: past.last,
      past: past.sublist(0, past.length - 1),
      future: [present, ...future],
    );
  }

  History<T> redo() {
    if (!canRedo) return this;
    return History(
      present: future.first,
      past: [...past, present],
      future: future.sublist(1),
    );
  }

  List<T> _capped(List<T> list) =>
      list.length > limit ? list.sublist(list.length - limit) : list;
}
