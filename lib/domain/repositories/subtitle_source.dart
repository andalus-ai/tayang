import '../services/subtitle_parser.dart';

/// Lets the user choose a subtitle file and returns its cues (null = cancelled).
abstract interface class SubtitleSource {
  Future<List<SubtitleCue>?> pick();
}
