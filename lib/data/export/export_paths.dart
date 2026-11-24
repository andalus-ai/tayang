import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<String> defaultExportPath(String fileName) async {
  final docs = await getApplicationDocumentsDirectory();
  final dir =
      await Directory(p.join(docs.path, 'tayang', 'exports')).create(recursive: true);
  return p.join(dir.path, fileName);
}
