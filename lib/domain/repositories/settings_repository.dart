abstract interface class SettingsRepository {
  Future<bool> hasSeenWelcome();
  Future<void> markWelcomeSeen();
}
