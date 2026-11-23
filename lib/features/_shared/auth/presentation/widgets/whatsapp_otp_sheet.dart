import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:delwaqty/core/errors/app_error_text.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

enum _OtpPhase { loading, active, expired, requestFailed }

class WhatsAppOtpSheet extends StatefulWidget {
  const WhatsAppOtpSheet({
    super.key,
    required this.phone,
    this.purpose = 'register',
    this.client,
  });

  final String phone;
  final String purpose;
  final SupabaseClient? client;

  static Future<bool> show(
    BuildContext context, {
    required String phone,
  }) async {
    return await showChallenge(context, phone: phone) != null;
  }

  /// Returns the private challenge only after the webhook confirms ownership.
  /// Password reset passes it to the server's one-time consume endpoint.
  static Future<String?> showChallenge(
    BuildContext context, {
    required String phone,
    String purpose = 'register',
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF140D24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => WhatsAppOtpSheet(phone: phone, purpose: purpose),
    );
  }

  @override
  State<WhatsAppOtpSheet> createState() => _WhatsAppOtpSheetState();
}

class _WhatsAppOtpSheetState extends State<WhatsAppOtpSheet>
    with SingleTickerProviderStateMixin {
  static const Duration _defaultCodeTtl = Duration(seconds: 600);
  static const Duration _resendCooldown = Duration(seconds: 30);

  Timer? _pollTimer;
  Timer? _tickTimer;
  late final AnimationController _pulse;
  _OtpPhase _phase = _OtpPhase.loading;
  bool _verifying = false;
  bool _statusInFlight = false;
  bool _completed = false;
  bool _copied = false;
  int _requestGeneration = 0;
  String? _otpCode;
  String? _challenge;
  String _whatsappNumber = '+201000000000';
  String? _errorText;
  DateTime? _expiresAt;
  DateTime? _resendAvailableAt;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _requestOtp();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _tickTimer?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _requestOtp({bool manual = false}) async {
    if (_completed) return;
    final generation = ++_requestGeneration;
    _pollTimer?.cancel();
    setState(() {
      _phase = _OtpPhase.loading;
      _challenge = null;
      _otpCode = null;
      _errorText = null;
      _copied = false;
      _expiresAt = null;
    });
    try {
      final raw = await (widget.client ?? Supabase.instance.client).rpc(
        'request_whatsapp_otp',
        params: {'p_phone': widget.phone.trim(), 'p_purpose': widget.purpose},
      );
      if (!mounted || generation != _requestGeneration) return;
      final map = raw is Map
          ? Map<String, dynamic>.from(raw)
          : <String, dynamic>{};
      final ok = map['ok'] == true;
      final otp = (map['otp_code'] as String?)?.trim();
      final challenge = (map['challenge'] as String?)?.trim();
      final supportNumber =
          (map['whatsapp_number'] as String?)?.trim() ?? '+201000000000';
      final ttlSeconds = (map['expires_in_seconds'] as num?)?.toInt();
      if (ok &&
          otp != null &&
          otp.isNotEmpty &&
          challenge != null &&
          challenge.isNotEmpty) {
        setState(() {
          _otpCode = otp;
          _challenge = challenge;
          _whatsappNumber = supportNumber;
          _phase = _OtpPhase.active;
          _expiresAt = DateTime.now().add(
            ttlSeconds != null && ttlSeconds > 0
                ? Duration(seconds: ttlSeconds)
                : _defaultCodeTtl,
          );
          _remaining = _expiresAt!.difference(DateTime.now());
          // Cooldown only after a manual resend; the first automatic
          // request must leave Resend tappable (RPC has its own limit).
          if (manual) {
            _resendAvailableAt = DateTime.now().add(_resendCooldown);
          }
        });
        _startPolling();
        _startTicking();
      } else {
        setState(() {
          _phase = _OtpPhase.requestFailed;
          _errorText = AppLocalizations.of(context).invalidOtpCode;
        });
      }
    } catch (e) {
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        _phase = _OtpPhase.requestFailed;
        _errorText = appErrorText(context, e);
      });
    }
  }

  Future<void> _openWhatsApp() async {
    final code = (_otpCode ?? '').trim();
    final cleanNumber = _whatsappNumber.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse(
      'https://wa.me/$cleanNumber?text=${Uri.encodeComponent("Verify Delwaqty OTP: $code")}',
    );
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _copyCode() async {
    final code = (_otpCode ?? '').trim();
    if (code.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    setState(() => _copied = true);
    Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  /// The webhook is the only path that can mark a code verified, so the
  /// sheet polls [whatsapp_otp_status] until Meta confirms the user sent
  /// the code from their own WhatsApp number.
  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      unawaited(_checkStatus());
    });
  }

  /// Drives the expiry countdown. Reaching zero only flips the UI to the
  /// expired state; the server remains the authority on validity.
  void _startTicking() {
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _completed || _phase != _OtpPhase.active) return;
      final expiresAt = _expiresAt;
      if (expiresAt == null) return;
      final remaining = expiresAt.difference(DateTime.now());
      setState(() {
        _remaining = remaining.isNegative ? Duration.zero : remaining;
        if (_remaining == Duration.zero) {
          _phase = _OtpPhase.expired;
          _pollTimer?.cancel();
        }
      });
    });
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<bool> _checkStatus() async {
    if (_statusInFlight || _completed || _challenge == null) return false;
    final challenge = _challenge!;
    final generation = _requestGeneration;
    _statusInFlight = true;
    try {
      final raw = await (widget.client ?? Supabase.instance.client).rpc(
        'whatsapp_otp_status',
        params: {
          'p_phone': widget.phone.trim(),
          'p_purpose': widget.purpose,
          'p_challenge': challenge,
        },
      );
      if (!mounted ||
          _completed ||
          generation != _requestGeneration ||
          challenge != _challenge)
        return false;
      final map = raw is Map
          ? Map<String, dynamic>.from(raw)
          : <String, dynamic>{};
      final status = map['status'] as String?;
      if (status == 'verified') {
        if (ModalRoute.of(context)?.isCurrent != true) return false;
        _completed = true;
        _pollTimer?.cancel();
        _tickTimer?.cancel();
        Navigator.of(context).pop(challenge);
        return true;
      }
      if (status == 'expired') {
        _pollTimer?.cancel();
        setState(() {
          _phase = _OtpPhase.expired;
          _remaining = Duration.zero;
        });
        return false;
      }
      return false;
    } catch (_) {
      return false;
    } finally {
      _statusInFlight = false;
    }
  }

  /// Manual tap on "I've sent it": the code alone proves nothing (the app
  /// showed it), so this just checks whether the webhook already confirmed
  /// the WhatsApp round-trip, and says so distinctly when it has not.
  Future<void> _verifyOtp() async {
    if (_statusInFlight || _completed) return;
    setState(() {
      _verifying = true;
      _errorText = null;
    });
    final ok = await _checkStatus();
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _verifying = false;
        if (_phase == _OtpPhase.active) {
          _errorText =
              AppLocalizations.of(context).otpNotConfirmedYet(widget.phone);
        }
      });
    }
  }

  bool get _resendEnabled {
    final at = _resendAvailableAt;
    return at == null || !DateTime.now().isBefore(at);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    const whatsappGreen = Color(0xFF25D366);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 14, 20, 20 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: whatsappGreen.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: whatsappGreen.withValues(alpha: 0.4),
                    ),
                  ),
                  child: const Icon(
                    Icons.chat_rounded,
                    color: whatsappGreen,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.whatsappOtpTitle,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.phone,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Colors.white.withValues(alpha: 0.65),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: l10n.cancel,
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.close_rounded,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              l10n.whatsappOtpSubtitle,
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.7),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            if (_phase == _OtpPhase.loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: CircularProgressIndicator(color: whatsappGreen),
                ),
              )
            else if (_phase == _OtpPhase.requestFailed) ...[
              if (_errorText != null)
                Text(
                  _errorText!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _requestOtp,
                style: FilledButton.styleFrom(
                  backgroundColor: whatsappGreen,
                  foregroundColor: const Color(0xFF0A0614),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.refresh_rounded),
                label: Text(
                  l10n.retryRequest,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
            ] else if (_phase == _OtpPhase.expired) ...[
              const SizedBox(height: 6),
              Icon(
                Icons.timer_off_rounded,
                color: Colors.white.withValues(alpha: 0.6),
                size: 40,
              ),
              const SizedBox(height: 10),
              Text(
                l10n.otpExpiredTitle,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                l10n.otpExpiredBody,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.7),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _requestOtp,
                style: FilledButton.styleFrom(
                  backgroundColor: whatsappGreen,
                  foregroundColor: const Color(0xFF0A0614),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.refresh_rounded),
                label: Text(
                  l10n.requestNewOtpCode,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
            ] else ...[
              if (_otpCode != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: whatsappGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: whatsappGreen.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.whatsappYourCodeLabel,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Colors.white.withValues(alpha: 0.6),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _otpCode!.split('').join(' '),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 26,
                                letterSpacing: 4,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: l10n.copyOtpCode,
                        onPressed: _copyCode,
                        icon: Icon(
                          _copied
                              ? Icons.check_rounded
                              : Icons.copy_rounded,
                          color: whatsappGreen,
                          size: 22,
                        ),
                      ),
                    ],
                  ),
                ),
              if (_copied) ...[
                const SizedBox(height: 6),
                Text(
                  l10n.otpCodeCopied,
                  style: const TextStyle(
                    color: whatsappGreen,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _PulsingDots(animation: _pulse, color: whatsappGreen),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      l10n.whatsappWaitingAuto,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.65),
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    l10n.otpExpiresIn(_formatDuration(_remaining)),
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.white.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _openWhatsApp,
                style: FilledButton.styleFrom(
                  backgroundColor: whatsappGreen,
                  foregroundColor: const Color(0xFF0A0614),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: Text(
                  l10n.openWhatsAppToVerify,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              TextButton.icon(
                onPressed: _verifying ? null : _verifyOtp,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white.withValues(alpha: 0.8),
                ),
                icon: _verifying
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline_rounded, size: 18),
                label: Text(l10n.iSentItCheckNow),
              ),
              if (_errorText != null) ...[
                const SizedBox(height: 4),
                Text(
                  _errorText!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 6),
              TextButton.icon(
                onPressed: (_verifying || !_resendEnabled)
                    ? null
                    : () => _requestOtp(manual: true),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white.withValues(alpha: 0.7),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 17),
                label: Text(
                  _resendEnabled
                      ? l10n.resendWhatsAppCode
                      : l10n.resendOtpAvailableIn(
                          _formatDuration(
                            _resendAvailableAt!.difference(DateTime.now()),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                l10n.wrongPhoneNumberHint,
                style: TextStyle(
                  fontSize: 11.5,
                  color: Colors.white.withValues(alpha: 0.45),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PulsingDots extends StatelessWidget {
  const _PulsingDots({required this.animation, required this.color});

  final Animation<double> animation;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = (animation.value - i / 3) % 1.0;
            final opacity = 0.3 + 0.7 * (phase < 0.5 ? phase * 2 : 2 - phase * 2);
            return Container(
              width: 7,
              height: 7,
              margin: const EdgeInsets.symmetric(horizontal: 2.5),
              decoration: BoxDecoration(
                color: color.withValues(alpha: opacity),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}
