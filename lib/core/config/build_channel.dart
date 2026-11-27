/// True for the Google Play build (`--dart-define=PLAY_BUILD=true`).
///
/// Play forbids apps that update themselves outside Play and restricts
/// REQUEST_INSTALL_PACKAGES, so the Play build has no in-app OTA update: the
/// check, the dialog and the "check for updates" button are all off. The
/// matching Android side removes the permission (set the PLAY_BUILD=true
/// environment variable for Gradle too, see android/app/src/play/).
const bool kPlayBuild = bool.fromEnvironment('PLAY_BUILD');
