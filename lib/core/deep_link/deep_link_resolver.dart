/// Pure deep-link resolution core for the app's custom URL scheme.
///
/// The app owns `io.delwaqty://...` (declared in `AndroidManifest.xml` and
/// configured as Supabase auth `site_url`/`uri_allow_list`, see
/// docs/DECISION_LOG.md ADR-040 / ADR-065). supabase_flutter already consumes
/// auth-callback links (PKCE `code`/`access_token`) on its own `AppLinks`
/// subscription, so this resolver must NOT re-consume those parameters. It
/// only classifies an inbound URI into a navigation target after the session
/// has resolved.
library;

enum DeepLinkRoute {
  /// `io.delwaqty://login-callback` — email-confirm / OAuth return. The auth
  /// SDK completes the exchange; the app should then let the router's auth
  /// redirect land the user on the correct page (pending verification or home).
  loginCallback,

  /// `io.delwaqty://login-callback/activated` is the redirect of the signup
  /// activation email. The app signs the temporary session out and shows the
  /// login page with an "account active" message.
  emailActivated,
}

class DeepLinkResolver {
  const DeepLinkResolver();

  static const String _scheme = 'io.delwaqty';

  /// The admin flavor owns its own scheme (see its AndroidManifest).
  static const String _adminScheme = 'io.delwaqty.admin';
  static const String _callbackHost = 'login-callback';

  /// Classifies [uri] into a [DeepLinkRoute] or `null` when the URI is not a
  /// Delwaqty deep link.
  ///
  /// Allowlist rules:
  ///   * scheme must be exactly `io.delwaqty` (customer/driver/provider) or
  ///     `io.delwaqty.admin` (admin flavor)
  ///   * host `login-callback` -> [DeepLinkRoute.loginCallback]
  ///   * unknown hosts are rejected (never trust arbitrary URIs).
  static DeepLinkRoute? resolve(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null) return null;
    if (!uri.hasScheme ||
        (uri.scheme != _scheme && uri.scheme != _adminScheme)) {
      return null;
    }
    if (!uri.hasAuthority) return null;
    return switch (uri.host) {
      _callbackHost when uri.path == '/activated' =>
        DeepLinkRoute.emailActivated,
      _callbackHost => DeepLinkRoute.loginCallback,
      _ => null,
    };
  }
}
