import 'package:flutter/material.dart';

/// A text field that mirrors an external value (so undo/redo updates it) while
/// still letting the user type freely.
class SyncedTextField extends StatefulWidget {
  const SyncedTextField({
    super.key,
    required this.value,
    required this.onChanged,
    this.onCommit,
    this.label,
    this.maxLines = 1,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final VoidCallback? onCommit;
  final String? label;
  final int maxLines;

  @override
  State<SyncedTextField> createState() => _SyncedTextFieldState();
}

class _SyncedTextFieldState extends State<SyncedTextField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.value);
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) widget.onCommit?.call();
    });
  }

  @override
  void didUpdateWidget(SyncedTextField old) {
    super.didUpdateWidget(old);
    if (!_focus.hasFocus && _controller.text != widget.value) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focus,
      maxLines: widget.maxLines,
      decoration: InputDecoration(labelText: widget.label),
      onChanged: widget.onChanged,
      onSubmitted: (_) => widget.onCommit?.call(),
    );
  }
}
