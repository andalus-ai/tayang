import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/editor_actions.dart';

/// Global keyboard shortcuts. They are suppressed while a text field has focus.
class EditorShortcuts extends ConsumerStatefulWidget {
  const EditorShortcuts({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<EditorShortcuts> createState() => _EditorShortcutsState();
}

class _EditorShortcutsState extends ConsumerState<EditorShortcuts> {
  final _focus = FocusNode(debugLabel: 'editor-shortcuts');

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  bool get _isTyping =>
      FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<EditableText>() !=
      null;

  void _run(VoidCallback action) {
    if (!_isTyping) action();
  }

  @override
  Widget build(BuildContext context) {
    final a = ref.read(editorActionsProvider);
    final apple = defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.iOS;

    SingleActivator mod(LogicalKeyboardKey key, {bool shift = false}) =>
        SingleActivator(key, control: !apple, meta: apple, shift: shift);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.space): () => _run(a.togglePlay),
        const SingleActivator(LogicalKeyboardKey.keyS): () => _run(a.splitAtPlayhead),
        const SingleActivator(LogicalKeyboardKey.delete): () => _run(a.deleteSelected),
        const SingleActivator(LogicalKeyboardKey.backspace): () => _run(a.deleteSelected),
        const SingleActivator(LogicalKeyboardKey.delete, shift: true): () =>
            _run(() => a.deleteSelected(ripple: true)),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _run(() => a.stepFrames(-1)),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => _run(() => a.stepFrames(1)),
        const SingleActivator(LogicalKeyboardKey.home): () => _run(a.seekToStart),
        const SingleActivator(LogicalKeyboardKey.end): () => _run(a.seekToEnd),
        mod(LogicalKeyboardKey.keyZ): () => _run(a.undo),
        mod(LogicalKeyboardKey.keyZ, shift: true): () => _run(a.redo),
        mod(LogicalKeyboardKey.keyY): () => _run(a.redo),
        mod(LogicalKeyboardKey.keyD): () => _run(a.duplicateSelected),
        mod(LogicalKeyboardKey.keyC): () => _run(a.copySelected),
        mod(LogicalKeyboardKey.keyX): () => _run(a.cutSelected),
        mod(LogicalKeyboardKey.keyV): () => _run(a.paste),
      },
      child: Focus(
        focusNode: _focus,
        autofocus: true,
        // Clicking anywhere outside a text field hands focus back to the editor
        // so shortcuts keep working.
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) {
            if (_isTyping) _focus.requestFocus();
          },
          child: widget.child,
        ),
      ),
    );
  }
}
