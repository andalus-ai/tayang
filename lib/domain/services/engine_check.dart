/// Whether the media engine (FFmpeg) is usable on this machine.
class EngineStatus {
  const EngineStatus.ready()
      : ready = true,
        message = null;

  const EngineStatus.missing(String this.message) : ready = false;

  final bool ready;

  /// Human-readable explanation when [ready] is false.
  final String? message;
}

abstract interface class EngineCheck {
  Future<EngineStatus> check();
}
