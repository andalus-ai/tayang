/// Deterministic (cross-run) short hash for cache file names (FNV-1a, 32-bit).
String stableKey(String input) {
  var hash = 0x811c9dc5;
  for (final unit in input.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash.toRadixString(16);
}
