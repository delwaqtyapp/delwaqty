import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:delwaqty/features/admin/support_chat/presentation/chat_providers.dart';
import 'package:delwaqty/features/admin/support_chat/presentation/widgets/chat_media_bubbles.dart';
import 'package:delwaqty/features/admin/support_chat/domain/entities/chat_message.dart';
import 'package:delwaqty/features/_shared/auth/presentation/auth_provider.dart';
import 'package:delwaqty/features/_shared/auth/domain/auth_state.dart';
import 'package:delwaqty/core/config/app_mode_provider.dart';
import 'package:delwaqty/domain/entities/user.dart';
import 'package:delwaqty/shared/widgets/app_loader.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class SupportChatRoomPage extends ConsumerStatefulWidget {
  const SupportChatRoomPage({super.key, required this.roomId});
  final String roomId;

  @override
  ConsumerState<SupportChatRoomPage> createState() => _SupportChatRoomPageState();
}

class _SupportChatRoomPageState extends ConsumerState<SupportChatRoomPage> {
  final _messageController = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();
  final _picker = ImagePicker();
  final _recorder = AudioRecorder();
  Timer? _typingDebounce;
  bool _isRecording = false;
  bool _isSendingMedia = false;
  String? _lastHandledCallMsgId;
  bool _callSheetOpen = false;
  BuildContext? _callSheetContext;
  String? _activeCallMessageId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
      _maybeSendWelcome();
      _maybeHandlePendingIncomingCall();
    });
  }

  @override
  void dispose() {
    _typingDebounce?.cancel();
    _messageController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    _recorder.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  bool _sessionIsAdminPanel() => ref.read(isAdminAppProvider);

  // When the room opens after the call alert routed us here, the ringing call
  // message may already be in the history (the live stream event fired before
  // this page subscribed). Scan the loaded messages once and surface a
  // ringing, peer-originated, unhandled call as the incoming-call sheet.
  Future<void> _maybeHandlePendingIncomingCall() async {
    final user = _currentUser();
    if (user == null) return;
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    final messagesAsync = ref.read(chatMessagesProvider(widget.roomId));
    final messages = messagesAsync.asData?.value;
    if (messages == null || messages.isEmpty) return;
    final candidate = messages.where((m) {
      final isCall = m.messageType == 'call' ||
          (m.metaData?['call_type'] != null);
      if (!isCall) return false;
      final status = (m.metaData?['status'] as String?) ?? 'ringing';
      if (status != 'ringing') return false;
      if (m.senderId == user.id) return false;
      return true;
    }).toList();
    if (candidate.isEmpty || _callSheetOpen) return;
    final latest = candidate.last;
    // Only auto-surface calls still fresh (within ~60s) to avoid nagging on
    // old abandoned requests after reopening an old room.
    final age = DateTime.now().difference(latest.createdAt).inSeconds.abs();
    if (age > 60) return;
    if (latest.id == _lastHandledCallMsgId) return;
    _handleIncomingCall(latest, user.id);
  }

  bool _isRoomActive() {
    final live = ref.read(chatRoomStreamProvider(widget.roomId));
    if (live.hasValue) return live.value?.isActive ?? true;
    final fetched = ref.read(chatRoomProvider(widget.roomId));
    return fetched.asData?.value.isActive ?? true;
  }

  Future<void> _notifyTyping(AppLocalizations l10n) {
    _typingDebounce?.cancel();
    final user = _currentUser();
    if (user == null) return Future.value();
    final repo = ref.read(chatRepositoryProvider);
    final t = repo.setTyping(
      roomId: widget.roomId,
      userId: user.id,
      isTyping: true,
    );
    _typingDebounce = Timer(const Duration(milliseconds: 1200), () {
      final users2 = _currentUser();
      if (users2 == null) return;
      ref.read(chatRepositoryProvider).setTyping(
            roomId: widget.roomId,
            userId: users2.id,
            isTyping: false,
          );
    });
    return t;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final authState = ref.watch(authStateProvider);
    final user = authState is AuthAuthenticated ? authState.user : null;
    final isAdminPanel = _sessionIsAdminPanel();
    final messagesAsync = ref.watch(chatMessagesProvider(widget.roomId));
    final roomAsync = ref.watch(chatRoomProvider(widget.roomId));
    final roomLiveAsync = ref.watch(chatRoomStreamProvider(widget.roomId));
    final isRoomActive =
        roomLiveAsync.asData?.value.isActive ?? roomAsync.asData?.value.isActive ?? true;
    final peerTyping = ref.watch(chatPeerTypingProvider(widget.roomId));
    final permissionsAsync = ref.watch(chatPermissionsProvider);
    final permissions = permissionsAsync.asData?.value ?? <String, dynamic>{};
    final callEnabled = permissions['chat_calls_enabled'] as bool? ?? true;
    final voiceEnabled = permissions['chat_voice_enabled'] as bool? ?? true;
    final mediaEnabled = permissions['chat_media_enabled'] as bool? ?? true;

    ref.listen(chatMessageStreamProvider(widget.roomId), (prev, next) {
      next.whenData((msg) {
        ref.invalidate(chatMessagesProvider(widget.roomId));
        _scrollToBottom();
        _handleIncomingCall(msg, user?.id);
        _closeOutgoingCallOnAnswer(msg, user?.id);
      });
    });

    final referenceNumber = roomAsync.asData?.value.referenceNumber;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              referenceNumber?.isEmpty ?? true
                  ? '${l10n.chatRoom} #${widget.roomId.substring(0, 6)}'
                  : referenceNumber ?? '',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (referenceNumber?.isNotEmpty ?? false)
              Text(
                l10n.chatRoom,
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
        actions: [
          if (isRoomActive && callEnabled)
            IconButton(
              icon: const Icon(Icons.call_rounded),
              tooltip: l10n.voiceCall,
              onPressed: () => _sendCallMessage(),
            ),
          if (isAdminPanel)
            IconButton(
              icon: const Icon(Icons.close_rounded),
              tooltip: l10n.closeChat,
              onPressed: () => _confirmCloseChat(),
            ),
          if (isAdminPanel)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: l10n.deleteChat,
              onPressed: () => _confirmDeleteChat(),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: roomAsync.when(
              data: (room) {
                if (!isRoomActive || !room.isActive) {
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: cs.errorContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.lock_outline_rounded,
                                  color: cs.onErrorContainer),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  l10n.chatClosed,
                                  style: TextStyle(
                                      color: cs.onErrorContainer),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: _messagesSection(
                          messagesAsync, cs, l10n, user?.id ?? ''),
                      ),
                    ],
                  );
                }
                return _messagesSection(
                  messagesAsync, cs, l10n, user?.id ?? '');
              },
              loading: () => const Center(child: AppLoaderCircular()),
              error: (e, _) => Center(child: Text('${l10n.error}: $e')),
            ),
          ),

          // Typing indicator above input
          if (isRoomActive && (peerTyping.asData?.value ?? false))
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                l10n.someoneIsTyping,
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: cs.primary,
                ),
              ),
            ),

          if (isRoomActive)
            _buildInputArea(
              cs,
              l10n,
              user,
              callEnabled: callEnabled,
              voiceEnabled: voiceEnabled,
              mediaEnabled: mediaEnabled,
            ),
        ],
      ),
    );
  }

  Widget _messagesSection(
    AsyncValue<List<ChatMessage>> messagesAsync,
    ColorScheme cs,
    AppLocalizations l10n,
    String currentUserId,
  ) {
    return messagesAsync.when(
      data: (messages) {
        if (messages.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_outlined,
                    size: 48, color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
                const SizedBox(height: 12),
                Text(l10n.noMessages,
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          );
        }
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _scrollToBottom());
        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(12),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final msg = messages[index];
            return _buildMessageCard(msg, currentUserId);
          },
        );
      },
      loading: () => const Center(child: AppLoaderCircular()),
      error: (e, _) => Center(child: Text('${l10n.error}: $e')),
    );
  }

  // Bubble positioning rule (mirrored viewer-side):
  // - From the customer's view: customer's own bubbles on the RIGHT, admin LEFT.
  // - From the admin's view: the admin's own bubbles on the RIGHT, customer LEFT.
  // So: isMe -> right; peer -> left. Colors identify the ROLE:
  // customer bubbles (role) = tertiary container; admin bubbles = primary.
  Widget _buildMessageCard(ChatMessage msg, String currentUserId) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final isMe = msg.senderId == currentUserId;
    final isAdminMsg = msg.isFromAdmin;

    final bubble = Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isAdminMsg ? cs.primaryContainer : cs.tertiaryContainer,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(4),
          bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
        ),
      ),
      constraints: const BoxConstraints(maxWidth: 400),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isAdminMsg ? Icons.support_agent_rounded : Icons.person_rounded,
                  size: 12,
                  color: isAdminMsg
                      ? (isMe ? cs.onPrimaryContainer : cs.primary)
                      : (isMe ? cs.onTertiaryContainer : cs.tertiary),
                ),
                const SizedBox(width: 4),
                Text(
                  isAdminMsg ? l10n.adminLabel : l10n.customerLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isAdminMsg
                        ? (isMe ? cs.onPrimaryContainer : cs.primary)
                        : (isMe ? cs.onTertiaryContainer : cs.tertiary),
                  ),
                ),
                const Spacer(),
                Text(
                  '${msg.createdAt.hour}:${msg.createdAt.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: 10,
                    color: isMe
                        ? (isAdminMsg ? cs.onPrimaryContainer : cs.onTertiaryContainer)
                        : cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          _buildMessageContent(msg, isMe, isAdminMsg, l10n),
        ],
      ),
    );

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: bubble,
    );
  }

  Widget _buildMessageContent(
    ChatMessage msg,
    bool isMe,
    bool isAdminMsg,
    AppLocalizations l10n,
  ) {
    final cs = Theme.of(context).colorScheme;
    final fg = isAdminMsg
        ? (isMe ? cs.onPrimaryContainer : cs.primary)
        : (isMe ? cs.onTertiaryContainer : cs.tertiary);
    final bg = isAdminMsg ? cs.primaryContainer : cs.tertiaryContainer;

    // Image attachment
    if (msg.messageType == 'image' || (msg.attachmentUrl != null && msg.messageType == 'file' && _looksLikeImage(msg.attachmentUrl!))) {
      return ChatAttachmentImage(
        path: msg.attachmentUrl ?? msg.fileUrl ?? '',
        fgColor: fg,
        bgColor: bg,
      );
    }

    // Video attachment
    if (msg.messageType == 'video' || (msg.fileUrl != null && _looksLikeVideo(msg.fileUrl!))) {
      return ChatAttachmentVideo(
        path: msg.fileUrl ?? msg.attachmentUrl ?? '',
        isMe: isMe,
      );
    }

    // Voice message
    if (msg.messageType == 'audio' || msg.audioUrl != null) {
      return ChatAudioMessage(
        path: msg.audioUrl ?? msg.fileUrl ?? '',
        isMe: isMe,
      );
    }

    // Call request bubble — full state machine on the SAME message:
    // ringing -> accepted/declined (via chat_set_call_status) -> ended.
    if (msg.messageType == 'call' || (msg.metaData?['call_type'] != null)) {
      final status = (msg.metaData?['status'] as String?) ?? 'ringing';
      final isIncoming = !isMe;
      final callActive = status == 'accepted';
      final callDeclined = status == 'declined';
      final callEnded = status == 'ended';
      final callRinging = status == 'ringing';

      final Color statusColor = callActive
          ? Colors.green
          : (callDeclined || callEnded) ? cs.error : cs.primary;
      final IconData statusIcon = callActive
          ? Icons.call_rounded
          : (callDeclined || callEnded) ? Icons.call_end_rounded : Icons.call_rounded;

      final String statusLabel;
      if (callActive) {
        statusLabel = l10n.callInProgress;
      } else if (callDeclined) {
        statusLabel = l10n.callDeclinedLabel;
      } else if (callEnded) {
        statusLabel = l10n.callEndedLabel;
      } else {
        statusLabel = isIncoming ? l10n.incomingVoiceCall : l10n.callingLabel;
      }

      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(statusIcon, size: 18, color: statusColor),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if (msg.message.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                msg.message,
                style: TextStyle(color: fg, fontSize: 12),
              ),
            ),
          if (callRinging && isIncoming) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  icon: const Icon(Icons.call_rounded, size: 16),
                  label: Text(l10n.acceptCall),
                  onPressed: () => _acceptCall(msg),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: cs.error,
                    foregroundColor: cs.onError,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  icon: const Icon(Icons.call_end_rounded, size: 16),
                  label: Text(l10n.declineCall),
                  onPressed: () => _declineCall(msg),
                ),
              ],
            ),
          ],
          if (callActive) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: cs.error,
                    foregroundColor: cs.onError,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  icon: const Icon(Icons.call_end_rounded, size: 16),
                  label: Text(l10n.endCall),
                  onPressed: () => _endCall(msg),
                ),
              ],
            ),
          ],
        ],
      );
    }

    return Text(
      msg.message,
      style: TextStyle(color: fg),
      softWrap: true,
    );
  }

  bool _looksLikeImage(String path) {
    final p = path.toLowerCase();
    return p.endsWith('.png') ||
        p.endsWith('.jpg') ||
        p.endsWith('.jpeg') ||
        p.endsWith('.webp') ||
        p.endsWith('.gif');
  }

  bool _looksLikeVideo(String path) {
    final p = path.toLowerCase();
    return p.endsWith('.mp4') || p.endsWith('.webm');
  }

  Future<void> _acceptCall(ChatMessage incoming) async {
    final user = _currentUser();
    if (user == null) return;
    final repo = ref.read(chatRepositoryProvider);
    try {
      await repo.setCallStatus(
        messageId: incoming.id,
        status: 'accepted',
        responderId: user.id,
        responderType: _sessionIsAdminPanel() ? 'admin' : 'customer',
      );
      ref.invalidate(chatMessagesProvider(widget.roomId));
      _scrollToBottom();
    } catch (_) {}
  }

  Future<void> _declineCall(ChatMessage incoming) async {
    final user = _currentUser();
    if (user == null) return;
    final repo = ref.read(chatRepositoryProvider);
    try {
      await repo.setCallStatus(
        messageId: incoming.id,
        status: 'declined',
        responderId: user.id,
        responderType: _sessionIsAdminPanel() ? 'admin' : 'customer',
      );
      ref.invalidate(chatMessagesProvider(widget.roomId));
      _scrollToBottom();
    } catch (_) {}
  }

  // Hang up a call in progress — clears status to 'ended' on the same bubble.
  Future<void> _endCall(ChatMessage msg) async {
    final user = _currentUser();
    if (user == null) return;
    final repo = ref.read(chatRepositoryProvider);
    try {
      await repo.setCallStatus(
        messageId: msg.id,
        status: 'ended',
        responderId: user.id,
        responderType: _sessionIsAdminPanel() ? 'admin' : 'customer',
      );
      ref.invalidate(chatMessagesProvider(widget.roomId));
    } catch (_) {}
  }

  // Opens a full-screen call sheet when a REAL-TIME ringing call arrives from
  // the peer (fresh message, not my own, not already handled). Shows the same
  // accept/decline actions; once answered the bubble itself flips to live state.
  void _handleIncomingCall(ChatMessage msg, String? meId) {
    final isCall = msg.messageType == 'call' ||
        (msg.metaData?['call_type'] != null);
    if (!isCall) return;
    final status = (msg.metaData?['status'] as String?) ?? 'ringing';
    if (status != 'ringing') return;
    if (msg.senderId == meId) return;
    final fresh = DateTime.now().difference(msg.createdAt).inSeconds.abs() < 60;
    if (!fresh) return;
    if (msg.id == _lastHandledCallMsgId || _callSheetOpen) return;
    _lastHandledCallMsgId = msg.id;
    _callSheetOpen = true;

    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.phone_in_talk_rounded, size: 56, color: cs.primary),
              const SizedBox(height: 12),
              Text(
                l10n.incomingVoiceCall,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(msg.message, style: TextStyle(color: cs.onSurfaceVariant)),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                    ),
                    icon: const Icon(Icons.call_rounded),
                    label: Text(l10n.acceptCall),
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      _callSheetOpen = false;
                      _acceptCall(msg);
                    },
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: cs.error,
                      foregroundColor: cs.onError,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                    ),
                    icon: const Icon(Icons.call_end_rounded),
                    label: Text(l10n.declineCall),
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      _callSheetOpen = false;
                      _declineCall(msg);
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    ).whenComplete(() => _callSheetOpen = false);
  }

  Widget _buildInputArea(
    ColorScheme cs,
    AppLocalizations l10n,
    User? user, {
    required bool callEnabled,
    required bool voiceEnabled,
    required bool mediaEnabled,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isSendingMedia)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Text(l10n.sendingMedia, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          Row(
            children: [
              if (mediaEnabled || callEnabled) ...[
                _attachMenu(
                  l10n,
                  callEnabled: callEnabled,
                  mediaEnabled: mediaEnabled,
                ),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: TextField(
                  controller: _messageController,
                  focusNode: _focusNode,
                  decoration: InputDecoration(
                    hintText: l10n.typeMessage,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                  ),
                  textInputAction: TextInputAction.send,
                  onChanged: (_) => _notifyTyping(l10n),
                  onSubmitted: (_) => _sendMessage(user),
                ),
              ),
              const SizedBox(width: 8),
              if (voiceEnabled) _voiceButton(cs, l10n, user),
              const SizedBox(width: 4),
              IconButton.filled(
                icon: const Icon(Icons.send_rounded),
                onPressed: () => _sendMessage(user),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _attachMenu(
    AppLocalizations l10n, {
    required bool callEnabled,
    required bool mediaEnabled,
  }) {
    final cs = Theme.of(context).colorScheme;
    return PopupMenuButton<String>(
      icon: Icon(Icons.add_circle_outline_rounded, color: cs.primary),
      tooltip: l10n.attachment,
      onSelected: (value) async {
        switch (value) {
          case 'image':
            await _pickAndSendImage();
            break;
          case 'video':
            await _pickAndSendVideo();
            break;
          case 'call':
            await _sendCallMessage();
            break;
        }
      },
      itemBuilder: (context) => [
        if (mediaEnabled) ...[
          PopupMenuItem(
            value: 'image',
            child: Row(children: [
              Icon(Icons.image_outlined, color: cs.primary),
              const SizedBox(width: 8),
              Text(l10n.sendImage),
            ]),
          ),
          PopupMenuItem(
            value: 'video',
            child: Row(children: [
              Icon(Icons.videocam_outlined, color: cs.primary),
              const SizedBox(width: 8),
              Text(l10n.sendVideo),
            ]),
          ),
        ],
        if (callEnabled)
          PopupMenuItem(
            value: 'call',
            child: Row(children: [
              Icon(Icons.call_outlined, color: cs.primary),
              const SizedBox(width: 8),
              Text(l10n.voiceCall),
            ]),
          ),
      ],
    );
  }

  Widget _voiceButton(ColorScheme cs, AppLocalizations l10n, User? user) {
    return GestureDetector(
      onLongPressStart: (_) async {
        await _startRecording(l10n, user);
      },
      onLongPressEnd: (_) async {
        await _stopRecordingSend(l10n, user);
      },
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _isRecording ? cs.tertiaryContainer : cs.surfaceContainerHighest,
        ),
        child: Icon(
          _isRecording ? Icons.mic_rounded : Icons.mic_none_rounded,
          color: _isRecording ? cs.onTertiaryContainer : cs.onSurfaceVariant,
        ),
      ),
    );
  }

  Future<void> _startRecording(AppLocalizations l10n, User? user) async {
    if (user == null || _isRecording) return;
    if (!await Permission.microphone.request().isGranted) return;

    final ok = await _recorder.hasPermission();
    if (!ok) return;

    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

    setState(() {
      _isRecording = true;
    });

    try {
      await _recorder.start(
        const RecordConfig(),
        path: path,
      );
    } catch (_) {
      setState(() => _isRecording = false);
    }
  }

  Future<void> _stopRecordingSend(AppLocalizations l10n, User? user) async {
    if (!_isRecording) return;
    final path = await _recorder.stop();
    if (!mounted) return;
    setState(() => _isRecording = false);

    if (path == null) return;

    final file = File(path);
    if (!await file.exists() || (await file.length()) == 0) return;

    await _sendMedia(
      l10n: l10n,
      user: user,
      file: file,
      messageType: 'audio',
      mediaCaption: l10n.voiceMessage,
      audio: true,
    );
  }

  Future<void> _pickAndSendImage() async {
    final l10n = AppLocalizations.of(context);
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    await _sendBytes(
      l10n: l10n,
      user: _currentUser(),
      fileName: file.name,
      bytes: bytes,
      contentType: 'image/jpeg',
      messageType: 'image',
      mediaCaption: l10n.sendImage,
    );
  }

  Future<void> _pickAndSendVideo() async {
    final l10n = AppLocalizations.of(context);
    final file = await _picker.pickVideo(source: ImageSource.gallery);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    await _sendBytes(
      l10n: l10n,
      user: _currentUser(),
      fileName: file.name,
      bytes: bytes,
      contentType: 'video/mp4',
      messageType: 'video',
      mediaCaption: l10n.sendVideo,
    );
  }

  User? _currentUser() {
    final authState = ref.read(authStateProvider);
    return authState is AuthAuthenticated ? authState.user : null;
  }

  Future<void> _sendMedia({
    required AppLocalizations l10n,
    required User? user,
    required File file,
    required String messageType,
    required String mediaCaption,
    bool audio = false,
  }) async {
    final bytes = await file.readAsBytes();
    await _sendBytes(
      l10n: l10n,
      user: user,
      fileName: file.path.split('/').last,
      bytes: bytes,
      contentType: audio ? 'audio/mp4' : 'application/octet-stream',
      messageType: messageType,
      mediaCaption: mediaCaption,
    );
  }

  Future<void> _sendBytes({
    required AppLocalizations l10n,
    required User? user,
    required String fileName,
    required Uint8List bytes,
    required String contentType,
    required String messageType,
    required String mediaCaption,
  }) async {
    if (user == null) return;
    if (!_isRoomActive() && mounted) {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.chatClosed)),
      );
      return;
    }
    setState(() => _isSendingMedia = true);
    final repo = ref.read(chatRepositoryProvider);
    try {
      final path = await repo.uploadAttachment(
        roomId: widget.roomId,
        fileName: fileName,
        bytes: bytes,
        contentType: contentType,
      );
      final isAdminOrOwner = _sessionIsAdminPanel();
      final message = ChatMessage(
        id: '',
        roomId: widget.roomId,
        senderId: user.id,
        senderType: isAdminOrOwner ? 'admin' : 'customer',
        message: mediaCaption == l10n.voiceMessage ? l10n.voiceMessage : mediaCaption,
        messageType: messageType,
        attachmentUrl: messageType == 'image' ? path : null,
        fileUrl: messageType == 'video' || messageType == 'file' ? path : null,
        audioUrl: messageType == 'audio' ? path : null,
        isFromAdmin: isAdminOrOwner,
        createdAt: DateTime.now(),
      );
      await repo.sendMessage(message);
      ref.invalidate(chatMessagesProvider(widget.roomId));
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.error}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSendingMedia = false);
    }
  }

  Future<void> _sendCallMessage() async {
    final authState = ref.read(authStateProvider);
    final user = authState is AuthAuthenticated ? authState.user : null;
    if (user == null) return;
    if (!_isRoomActive() && mounted) {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.chatClosed)),
      );
      return;
    }
    final l10n = AppLocalizations.of(context);
    final isAdminOrOwner = _sessionIsAdminPanel();
    final message = ChatMessage(
      id: '',
      roomId: widget.roomId,
      senderId: user.id,
      senderType: isAdminOrOwner ? 'admin' : 'customer',
      message: l10n.voiceCallRequest,
      messageType: 'call',
      isFromAdmin: isAdminOrOwner,
      createdAt: DateTime.now(),
      metaData: {
        'call_type': 'voice',
        'status': 'ringing',
        'requested_by': user.id,
        'requested_at': DateTime.now().toIso8601String(),
      },
    );
    final repo = ref.read(chatRepositoryProvider);
    try {
      final sent = await repo.sendMessage(message);
      ref.invalidate(chatMessagesProvider(widget.roomId));
      _scrollToBottom();
      await _openOutgoingCallSheet(sent.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.error}: $e')),
        );
      }
    }
  }

  // Caller sheet: shows "calling..." until the peer answers/declines/hangs up,
  // then closes automatically (driven by the live message stream).
  Future<void> _openOutgoingCallSheet(String callMessageId) async {
    if (!mounted || _callSheetOpen) return;
    _callSheetOpen = true;
    _activeCallMessageId = callMessageId;
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final navCtx = context;
    await showModalBottomSheet<void>(
      context: navCtx,
      isDismissible: false,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        _callSheetContext = sheetContext;
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              const SizedBox(height: 12),
              Icon(Icons.phone_in_talk_rounded, size: 56, color: cs.primary),
              const SizedBox(height: 12),
              Text(
                l10n.callingLabel,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: cs.error,
                  foregroundColor: cs.onError,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                ),
                icon: const Icon(Icons.call_end_rounded),
                label: Text(l10n.endCall),
                onPressed: () async {
                  final repo = ref.read(chatRepositoryProvider);
                  await repo.setCallStatus(
                    messageId: callMessageId,
                    status: 'ended',
                    responderId: _currentUser()?.id,
                    responderType: _sessionIsAdminPanel() ? 'admin' : 'customer',
                  );
                  if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                  _callSheetOpen = false;
                  _activeCallMessageId = null;
                },
              ),
            ],
          ),
        );
      },
    ).whenComplete(() {
      _callSheetOpen = false;
      _activeCallMessageId = null;
    });
  }

  // Auto-close the caller sheet the instant the peer flips the call to any
  // terminal state (accepted / declined / ended) via a live stream event.
  void _closeOutgoingCallOnAnswer(ChatMessage msg, String? meId) {
    final isCall = msg.messageType == 'call' ||
        (msg.metaData?['call_type'] != null);
    if (!isCall) return;
    if (msg.id != _activeCallMessageId) return;
    final status = (msg.metaData?['status'] as String?) ?? 'ringing';
    if (status == 'ringing') return;
    final sheetCtx = _callSheetContext;
    if (sheetCtx != null && sheetCtx.mounted) {
      Navigator.of(sheetCtx).pop();
    }
    _callSheetOpen = false;
    _activeCallMessageId = null;
    _lastHandledCallMsgId = msg.id;
    _scrollToBottom();
  }

  void _sendMessage(User? user) async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    if (user == null) return;
    if (!_isRoomActive()) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.chatClosed)),
        );
      }
      return;
    }

    final isAdminOrOwner = _sessionIsAdminPanel();
    final message = ChatMessage(
      id: '',
      roomId: widget.roomId,
      senderId: user.id,
      senderType: isAdminOrOwner ? 'admin' : 'customer',
      message: text,
      isFromAdmin: isAdminOrOwner,
      createdAt: DateTime.now(),
    );

    final repo = ref.read(chatRepositoryProvider);
    try {
      await repo.sendMessage(message);
      if (!mounted) return;
      _messageController.clear();
      _notifyTyping(AppLocalizations.of(context));
      ref.invalidate(chatMessagesProvider(widget.roomId));
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      final errorCode = AppLocalizations.of(context).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$errorCode: $e')),
      );
    }
  }

  Future<void> _confirmCloseChat() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.closeChatConfirmTitle),
        content: Text(l10n.closeChatConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.close),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final repo = ref.read(chatRepositoryProvider);
    try {
      await repo.closeRoom(widget.roomId);
      ref.invalidate(adminAllRoomsProvider);
      ref.invalidate(customerMyRoomsProvider);
      ref.invalidate(chatRoomProvider(widget.roomId));
      ref.invalidate(chatMessagesProvider(widget.roomId));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.error}: $e')),
        );
      }
    }
  }

  Future<void> _confirmDeleteChat() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteChatConfirmTitle),
        content: Text(l10n.deleteChatConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.deleteChat),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final repo = ref.read(chatRepositoryProvider);
    try {
      await repo.deleteChatRoom(widget.roomId);
      ref.invalidate(adminAllRoomsProvider);
      ref.invalidate(customerMyRoomsProvider);
      ref.invalidate(chatRoomProvider(widget.roomId));
      ref.invalidate(chatMessagesProvider(widget.roomId));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.error}: $e')),
        );
      }
    }
  }

  Future<void> _maybeSendWelcome() async {
    final authState = ref.read(authStateProvider);
    final user = authState is AuthAuthenticated ? authState.user : null;
    if (user == null) return;
    if (!_sessionIsAdminPanel()) return;

    final l10n = AppLocalizations.of(context);
    final repo = ref.read(chatRepositoryProvider);
    try {
      final room = await repo.getRoomById(widget.roomId);
      if (!mounted) return;
      if (!room.isActive) return;
      if (room.assignedAdminId != null) return;
      final name = user.fullName ?? user.username ?? user.email.split('@').first;
      final welcomeText = room.regionId == null
          ? l10n.welcomeCustomerMessage(name)
          : '📍 ${l10n.welcomeCustomerMessage(name)}';

      await repo.sendMessage(ChatMessage(
        id: '',
        roomId: widget.roomId,
        senderId: user.id,
        senderType: 'admin',
        message: welcomeText,
        isFromAdmin: true,
        createdAt: DateTime.now(),
      ));
      await repo.setAssignedAdmin(
        roomId: widget.roomId,
        adminId: user.id,
        welcomeMessage: welcomeText,
      );
      ref.invalidate(chatMessagesProvider(widget.roomId));
      _scrollToBottom();
    } catch (_) {}
  }
}