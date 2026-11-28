/// One timed line (or lines) of subtitle text.
class SubtitleCue {
  const SubtitleCue(this.start, this.end, this.text);

  final Duration start;
  final Duration end;
  final String text;

  @override
  bool operator ==(Object other) =>
      other is SubtitleCue &&
      other.start == start &&
      other.end == end &&
      other.text == text;

  @override
  int get hashCode => Object.hash(start, end, text);
}

/// Parses SubRip (.srt) and WebVTT (.vtt) subtitle files. Lenient: malformed
/// blocks are skipped, markup tags are stripped, CRLF and a BOM are handled.
abstract final class SubtitleParser {
  static final _time = RegExp(r'(?:(\d+):)?(\d{1,2}):(\d{2})[,.](\d{1,3})');
  static final _markup = RegExp(r'<[^>]*>|\{\\[^}]*\}');

  static List<SubtitleCue> parse(String source) {
    final text = source
        .replaceAll('\uFEFF', '')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');
    final cues = <SubtitleCue>[];
    for (final block in text.split(RegExp(r'\n[ \t]*\n+'))) {
      final lines = block.trim().split('\n');
      final arrow = lines.indexWhere((l) => l.contains('-->'));
      if (arrow < 0) continue; // WEBVTT header, NOTE blocks, junk
      final times = lines[arrow].split('-->');
      final start = _parseTime(times[0]);
      final end = _parseTime(times[1]);
      if (start == null || end == null || end <= start) continue;
      final body = lines
          .sublist(arrow + 1)
          .map((l) => l.replaceAll(_markup, '').trim())
          .where((l) => l.isNotEmpty)
          .join('\n');
      if (body.isEmpty) continue;
      cues.add(SubtitleCue(start, end, body));
    }
    cues.sort((a, b) => a.start.compareTo(b.start));
    return cues;
  }

  static Duration? _parseTime(String s) {
    final m = _time.firstMatch(s.trim());
    if (m == null) return null;
    return Duration(
      hours: int.parse(m.group(1) ?? '0'),
      minutes: int.parse(m.group(2)!),
      seconds: int.parse(m.group(3)!),
      milliseconds: int.parse(m.group(4)!.padRight(3, '0')),
    );
  }
}
