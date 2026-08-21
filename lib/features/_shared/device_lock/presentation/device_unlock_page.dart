import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';
import 'package:delwaqty/core/auth/admin_access.dart';
import 'package:delwaqty/core/config/app_mode_provider.dart';
import 'package:delwaqty/data/datasources/local/biometric_auth_store.dart';
import 'package:delwaqty/features/_shared/auth/domain/auth_state.dart';
import 'package:delwaqty/features/_shared/auth/presentation/auth_provider.dart';
import 'package:delwaqty/features/_shared/device_lock/device_lock_provider.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class DeviceUnlockPage extends ConsumerStatefulWidget {
  const DeviceUnlockPage({super.key});

  @override
  ConsumerState<DeviceUnlockPage> createState() => _DeviceUnlockPageState();
}

class _DeviceUnlockPageState extends ConsumerState<DeviceUnlockPage> {
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _isAuthenticating = false;
  bool _showAccounts = false;
  String? _activeUserId;
  List<_AccountEntry> _accounts = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    try {
      final store = ref.read(biometricAuthStoreProvider);
      final userIds = await store.allUserIds();
      final entries = <_AccountEntry>[];
      final String? active = await store.activeUserId();
      for (final uid in userIds) {
        final creds = await store.credentialsFor(uid);
        if (creds != null) {
          entries.add(_AccountEntry(userId: uid, email: creds.email));
        }
      }
      if (!mounted) return;
      setState(() {
        _accounts = entries;
        _activeUserId = active != null && entries.any((e) => e.userId == active)
            ? active
            : entries.isNotEmpty
                ? entries.first.userId
                : null;
      });
    } catch (_) {}
  }

  Future<void> _unlock() async {
    if (_isAuthenticating) return;
    final store = ref.read(biometricAuthStoreProvider);
    final userId = _activeUserId;
    if (userId == null) {
      if (mounted) context.go('/login');
      return;
    }
    final creds = await store.credentialsFor(userId);
    if (creds == null) {
      if (mounted) {
        setState(() => _error = AppLocalizations.of(context).deviceUnlockStale);
      }
      return;
    }

    setState(() {
      _isAuthenticating = true;
      _error = null;
    });
    final l10n = AppLocalizations.of(context);
    try {
      final didAuth = await _localAuth.authenticate(
        localizedReason: l10n.biometricReason,
      );
      if (!didAuth || !mounted) {
        if (mounted) setState(() => _isAuthenticating = false);
        return;
      }
      await ref.read(authStateProvider.notifier).signIn(
            email: creds.email,
            password: creds.password,
          );
      final next = ref.read(authStateProvider);
      if (!mounted) return;
      if (next is AuthError) {
        final isBadCredentials = next.message
            .toLowerCase()
            .contains('invalid login credentials');
        if (isBadCredentials) {
          await store.clearForUser(userId);
        }
        if (mounted) {
          setState(() {
            _isAuthenticating = false;
            _error = isBadCredentials
                ? l10n.deviceUnlockStale
                : l10n.deviceUnlockFailed;
          });
          await _loadAccounts();
        }
        return;
      }
      ref.read(deviceLockProvider.notifier).markUnlocked();
      final isAdminApp = ref.read(isAdminAppProvider);
      final userIsAdmin = ref.read(authStateProvider).maybeWhen(
            authenticated: (user) => user.isAdmin,
            orElse: () => false,
          );
      final target = isAdminApp
          ? (userIsAdmin ? '/admin' : '/login')
          : '/home';
      if (mounted) context.go(target);
    } on Exception catch (e) {
      final msg = e.toString();
      if (!mounted) return;
      setState(() {
        _isAuthenticating = false;
        _error = msg.contains('LockedOut') || msg.contains('Too many')
            ? l10n.deviceUnlockLockedOut
            : msg.contains('NotEnrolled')
                ? l10n.deviceUnlockNotEnrolled
                : l10n.deviceUnlockFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFF241E44),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF7A5CFF), Color(0xFF2DD4BF)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF7A5CFF).withValues(alpha: 0.3),
                        blurRadius: 30,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.lock_open_rounded,
                    color: Colors.white,
                    size: 44,
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  l10n.deviceUnlockTitle,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.deviceUnlockSubtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 24),
                if (_accounts.length > 1)
                  _AccountSelector(
                    accounts: _accounts,
                    activeUserId: _activeUserId,
                    expanded: _showAccounts,
                    onToggle: () =>
                        setState(() => _showAccounts = !_showAccounts),
                    onSelect: (uid) =>
                        setState(() => _activeUserId = uid),
                  ),
                if (_accounts.length == 1)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      _accounts.first.email,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.redAccent.shade200,
                        fontSize: 13,
                      ),
                    ),
                  ),
                GestureDetector(
                  onTap: _isAuthenticating ? null : _unlock,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF7A5CFF).withValues(alpha: 0.25),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: _isAuthenticating
                        ? const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF7A5CFF),
                          )
                        : Icon(
                            Icons.fingerprint_rounded,
                            color: const Color(0xFF7A5CFF).withValues(alpha: 0.8),
                            size: 38,
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.deviceUnlockAction,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 32),
                TextButton(
                  onPressed: _isAuthenticating
                      ? null
                      : () => context.go('/login'),
                  child: Text(
                    l10n.deviceUnlockAnotherAccount,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountEntry {
  const _AccountEntry({required this.userId, required this.email});
  final String userId;
  final String email;
}

class _AccountSelector extends StatelessWidget {
  const _AccountSelector({
    required this.accounts,
    required this.activeUserId,
    required this.expanded,
    required this.onToggle,
    required this.onSelect,
  });

  final List<_AccountEntry> accounts;
  final String? activeUserId;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final matching =
        accounts.where((e) => e.userId == activeUserId).toList();
    final active = matching.isEmpty ? null : matching.first;
    return Column(
      children: [
        GestureDetector(
          onTap: onToggle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  active?.email ?? '',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                const SizedBox(width: 8),
                Icon(
                  expanded ? Icons.expand_less : Icons.expand_more,
                  color: Colors.white.withValues(alpha: 0.6),
                  size: 18,
                ),
              ],
            ),
          ),
        ),
        if (expanded)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: accounts
                  .where((e) => e.userId != activeUserId)
                  .map(
                    (e) => GestureDetector(
                      onTap: () => onSelect(e.userId),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Text(
                          e.email,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
      ],
    );
  }
}
