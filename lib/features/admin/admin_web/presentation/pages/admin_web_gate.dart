import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/core/auth/admin_access.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/features/admin/admin_web/presentation/pages/admin_web_shell.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

enum AdminWebGateStatus { loading, notSignedIn, authorized, denied }

AdminWebGateStatus adminWebGateStatus({
  required bool hasSession,
  String? role,
}) {
  if (!hasSession) return AdminWebGateStatus.notSignedIn;
  if (isAdminRoleString(role)) return AdminWebGateStatus.authorized;
  return AdminWebGateStatus.denied;
}

class AdminWebGate extends StatefulWidget {
  const AdminWebGate({
    super.key,
    this.authStream,
    this.userIdLoader,
    this.roleLoader,
    this.authorizedBuilder,
  });

  final Stream<AuthState>? authStream;
  final Future<String?> Function()? userIdLoader;
  final Future<String?> Function(String userId)? roleLoader;
  final Widget Function()? authorizedBuilder;

  @override
  State<AdminWebGate> createState() => _AdminWebGateState();
}

class _AdminWebGateState extends State<AdminWebGate> {
  StreamSubscription<AuthState>? _authSub;
  AdminWebGateStatus _status = AdminWebGateStatus.loading;

  @override
  void initState() {
    super.initState();
    _authSub = (widget.authStream ??
            Supabase.instance.client.auth.onAuthStateChange)
        .listen((_) => _resolve());
    _resolve();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _resolve() async {
    if (mounted) setState(() => _status = AdminWebGateStatus.loading);
    String? userId;
    try {
      userId = await (widget.userIdLoader ?? _loadUserId)();
    } catch (_) {
      userId = null;
    }
    if (userId == null) {
      if (mounted) {
        setState(() => _status = AdminWebGateStatus.notSignedIn);
      }
      return;
    }
    String? role;
    try {
      role = await (widget.roleLoader ?? _loadRole)(userId);
    } catch (_) {
      role = null;
    }
    if (mounted) {
      setState(() => _status = adminWebGateStatus(hasSession: true, role: role));
    }
  }

  Future<String?> _loadUserId() async {
    return Supabase.instance.client.auth.currentSession?.user.id;
  }

  Future<String?> _loadRole(String userId) async {
    final response = await Supabase.instance.client
        .from('users')
        .select('role')
        .eq('id', userId)
        .limit(1);
    final rows = response as List?;
    if (rows == null || rows.isEmpty) return null;
    return rows.first['role'] as String?;
  }

  @override
  Widget build(BuildContext context) {
    return switch (_status) {
      AdminWebGateStatus.loading => const _AdminWebLoading(),
      AdminWebGateStatus.notSignedIn => AdminWebLoginPage(
        onSignedIn: _resolve,
      ),
      AdminWebGateStatus.denied => const AdminWebDeniedPage(),
      AdminWebGateStatus.authorized =>
        (widget.authorizedBuilder ?? () => const AdminWebShell())(),
    };
  }
}

class _AdminWebLoading extends StatelessWidget {
  const _AdminWebLoading();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(color: AppColors.brandPurple),
      ),
    );
  }
}

class AdminWebLoginPage extends StatefulWidget {
  const AdminWebLoginPage({super.key, this.onSignedIn});

  final VoidCallback? onSignedIn;

  @override
  State<AdminWebLoginPage> createState() => _AdminWebLoginPageState();
}

class _AdminWebLoginPageState extends State<AdminWebLoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      widget.onSignedIn?.call();
    } catch (e) {
      setState(() => _error = 'Invalid email or password');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.brandPurple, AppColors.brandCyan],
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Center(
                    child: Text(
                      'D',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 32,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Delwaqty Admin',
                  style: TextStyle(
                    color: Color(0xFF1A1035),
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Sign in with an admin account',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: const OutlineInputBorder(),
                    errorText: _error,
                  ),
                  obscureText: true,
                  onSubmitted: (_) => _signIn(),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: _loading ? null : _signIn,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.brandPurple,
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Sign In',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
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

class AdminWebDeniedPage extends StatelessWidget {
  const AdminWebDeniedPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.gpp_bad_rounded,
                  size: 64,
                  color: AppColors.errorLight,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Access Denied',
                  style: TextStyle(
                    color: Color(0xFF1A1035),
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your account does not have admin privileges.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () => Supabase.instance.client.auth.signOut(),
                  icon: const Icon(Icons.logout_rounded),
                  label: Text(l10n.signOut),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
