import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:delwaqty/core/errors/app_error_text.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

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

class _WhatsAppOtpSheetState extends State<WhatsAppOtpSheet> {
  Timer? _pollTimer;
  bool _loadingRequest = true;
  bool _verifying = false;
  bool _statusInFlight = false;
  bool _completed = false;
  String? _otpCode;
  String? _challenge;
  String _whatsappNumber = '+201000000000';
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _requestOtp();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _requestOtp() async {
    _pollTimer?.cancel();
    setState(() {
      _loadingRequest = true;
      _errorText = null;
    });
    try {
      final raw = await (widget.client ?? Supabase.instance.client).rpc(
        'request_whatsapp_otp',
        params: {'p_phone': widget.phone.trim(), 'p_purpose': widget.purpose},
      );
      if (!mounted) return;
      final map = raw is Map
          ? Map<String, dynamic>.from(raw)
          : <String, dynamic>{};
      final ok = map['ok'] == true;
      final otp = (map['otp_code'] as String?)?.trim();
      final challenge = (map['challenge'] as String?)?.trim();
      final supportNumber =
          (map['whatsapp_number'] as String?)?.trim() ?? '+201000000000';
      if (ok &&
          otp != null &&
          otp.isNotEmpty &&
          challenge != null &&
          challenge.isNotEmpty) {
        setState(() {
          _otpCode = otp;
          _challenge = challenge;
          _whatsappNumber = supportNumber;
          _loadingRequest = false;
        });
        _startPolling();
      } else {
        setState(() {
          _loadingRequest = false;
          _errorText = AppLocalizations.of(context).invalidOtpCode;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingRequest = false;
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

  /// The webhook is the only path that can mark a code verified, so the
  /// sheet polls [whatsapp_otp_status] until Meta confirms the user sent
  /// the code from their own WhatsApp number.
  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      unawaited(_checkStatus());
    });
  }

  Future<bool> _checkStatus() async {
    if (_statusInFlight || _completed || _challenge == null) return false;
    _statusInFlight = true;
    try {
      final raw = await (widget.client ?? Supabase.instance.client).rpc(
        'whatsapp_otp_status',
        params: {
          'p_phone': widget.phone.trim(),
          'p_purpose': widget.purpose,
          'p_challenge': _challenge,
        },
      );
      if (!mounted || _completed) return false;
      final map = raw is Map
          ? Map<String, dynamic>.from(raw)
          : <String, dynamic>{};
      final status = map['status'] as String?;
      if (status == 'verified') {
        _completed = true;
        _pollTimer?.cancel();
        Navigator.of(context).pop(_challenge);
        return true;
      }
      if (status == 'expired') {
        _pollTimer?.cancel();
        setState(
          () => _errorText = AppLocalizations.of(context).invalidOtpCode,
        );
        return false;
      }
      return false;
    } catch (_) {
      return false;
    } finally {
      _statusInFlight = false;
    }
  }

  /// Manual tap on "verify": the code alone proves nothing (the app showed
  /// it), so this just checks whether the webhook already confirmed the
  /// WhatsApp round-trip.
  Future<void> _verifyOtp() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _verifying = true;
      _errorText = null;
    });
    final ok = await _checkStatus();
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _verifying = false;
        _errorText = l10n.invalidOtpCode;
      });
    }
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
            if (_loadingRequest)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: CircularProgressIndicator(color: whatsappGreen),
                ),
              )
            else ...[
              if (_otpCode != null)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: whatsappGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: whatsappGreen.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.verified_user_rounded,
                        color: whatsappGreen,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          l10n.whatsappCodeSentBanner(_otpCode!),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _openWhatsApp,
                style: OutlinedButton.styleFrom(
                  foregroundColor: whatsappGreen,
                  side: const BorderSide(color: whatsappGreen, width: 1.3),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: Text(
                  l10n.openWhatsAppToVerify,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 14),
              if (_errorText != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorText!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _verifying ? null : _verifyOtp,
                style: FilledButton.styleFrom(
                  backgroundColor: whatsappGreen,
                  foregroundColor: const Color(0xFF0A0614),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: _verifying
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF0A0614),
                        ),
                      )
                    : const Icon(Icons.check_circle_rounded),
                label: Text(
                  l10n.verifyAndActivateAccount,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              TextButton.icon(
                onPressed: _verifying ? null : _requestOtp,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white.withValues(alpha: 0.7),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 17),
                label: Text(l10n.resendWhatsAppCode),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
