import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:delwaqty/core/errors/app_error_text.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class WhatsAppOtpSheet extends StatefulWidget {
  const WhatsAppOtpSheet({super.key, required this.phone});

  final String phone;

  static Future<bool> show(
    BuildContext context, {
    required String phone,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF140D24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => WhatsAppOtpSheet(phone: phone),
    );
    return result == true;
  }

  @override
  State<WhatsAppOtpSheet> createState() => _WhatsAppOtpSheetState();
}

class _WhatsAppOtpSheetState extends State<WhatsAppOtpSheet> {
  final TextEditingController _codeController = TextEditingController();
  bool _loadingRequest = true;
  bool _verifying = false;
  String? _otpCode;
  String _whatsappNumber = '+201000000000';
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _requestOtp();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _requestOtp() async {
    setState(() {
      _loadingRequest = true;
      _errorText = null;
    });
    try {
      final raw = await Supabase.instance.client.rpc(
        'request_whatsapp_otp',
        params: {
          'p_phone': widget.phone.trim(),
          'p_purpose': 'register',
        },
      );
      if (!mounted) return;
      final map = raw is Map
          ? Map<String, dynamic>.from(raw)
          : <String, dynamic>{};
      final ok = map['ok'] == true;
      final otp = (map['otp_code'] as String?)?.trim();
      final supportNumber =
          (map['whatsapp_number'] as String?)?.trim() ?? '+201000000000';
      if (ok && otp != null && otp.isNotEmpty) {
        setState(() {
          _otpCode = otp;
          _whatsappNumber = supportNumber;
          _codeController.text = otp;
          _loadingRequest = false;
        });
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
    final code = (_otpCode ?? _codeController.text).trim();
    final cleanNumber = _whatsappNumber.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse(
      'https://wa.me/$cleanNumber?text=${Uri.encodeComponent("Verify Delwaqty OTP: $code")}',
    );
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _verifyOtp() async {
    final l10n = AppLocalizations.of(context);
    final code = _codeController.text.trim();
    if (code.length < 4) {
      setState(() => _errorText = l10n.invalidOtpCode);
      return;
    }
    setState(() {
      _verifying = true;
      _errorText = null;
    });
    try {
      final raw = await Supabase.instance.client.rpc(
        'verify_whatsapp_otp',
        params: {
          'p_phone': widget.phone.trim(),
          'p_otp_code': code,
        },
      );
      if (!mounted) return;
      final map = raw is Map
          ? Map<String, dynamic>.from(raw)
          : <String, dynamic>{};
      final verified = map['ok'] == true && map['verified'] == true;
      if (verified) {
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _verifying = false;
          _errorText = l10n.invalidOtpCode;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _errorText = appErrorText(context, e);
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
                  onPressed: () => Navigator.of(context).pop(false),
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
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 6,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: l10n.enterOtpCode,
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 14,
                    letterSpacing: 0,
                  ),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.08),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: whatsappGreen,
                      width: 1.6,
                    ),
                  ),
                ),
              ),
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
