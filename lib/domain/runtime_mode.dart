/// Persisted runtime mode that decides which experience the app boots into.
///
///  - [arcade]  → the native sniper game (a.k.a. white flow)
///  - [portal]  → a full-screen WebView that hosts the partner URL
///  - [unset]   → first launch; the bootstrap stage will resolve which mode
///                the user belongs to via the dispatch endpoint
enum RuntimeMode {
  arcade,
  portal,
  unset;

  static const String _arcadeTag = 'arc';
  static const String _portalTag = 'prt';

  static RuntimeMode fromTag(String? tag) {
    switch (tag) {
      case _arcadeTag:
        return RuntimeMode.arcade;
      case _portalTag:
        return RuntimeMode.portal;
      default:
        return RuntimeMode.unset;
    }
  }

  String get storageTag {
    switch (this) {
      case RuntimeMode.arcade:
        return _arcadeTag;
      case RuntimeMode.portal:
        return _portalTag;
      case RuntimeMode.unset:
        return '';
    }
  }
}
