import '../models/media_asset.dart';

abstract interface class WaveformService {
  /// Path of a transparent PNG waveform covering the whole asset, or null.
  Future<String?> waveform(MediaAsset asset);
}
