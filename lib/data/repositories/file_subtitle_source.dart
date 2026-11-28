import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';

import '../../domain/repositories/subtitle_source.dart';
import '../../domain/services/subtitle_parser.dart';

class FileSubtitleSource implements SubtitleSource {
  @override
  Future<List<SubtitleCue>?> pick() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['srt', 'vtt'],
    );
    final path = result?.files.single.path;
    if (path == null) return null;
    final bytes = await File(path).readAsBytes();
    return SubtitleParser.parse(utf8.decode(bytes, allowMalformed: true));
  }
}
