import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/features/admin/support_chat/presentation/chat_providers.dart';
import 'package:delwaqty/features/admin/support_chat/domain/entities/chat_message.dart';
import 'package:delwaqty/features/_shared/auth/presentation/auth_provider.dart';
import 'package:delwaqty/features/_shared/auth/domain/auth_state.dart';
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
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final authState = ref.watch(authStateProvider);
    final user = authState is AuthAuthenticated ? authState.user : null;
    final messagesAsync = ref.watch(chatMessagesProvider(widget.roomId));

    ref.listen(chatMessageStreamProvider(widget.roomId), (prev, next) {
      next.whenData((_) {
        ref.invalidate(chatMessagesProvider(widget.roomId));
        _scrollToBottom();
      });
    });

    // Build message card based on sender
    Widget _buildMessageCard(ChatMessage msg) {
      final isMe = msg.senderId == user?.id;
      final isAdminMsg = msg.isFromAdmin;

      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isMe ? cs.primary : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft: isMe ? const Radius.circular(16) : const Radius.circular(16),
            topRight: isMe ? const Radius.circular(16) : const Radius.circular(16),
            bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(4),
            bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
          ),
        ),
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sender name + time row
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isAdminMsg ? 'Admin' : 'Customer',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${msg.createdAt.hour}:${msg.createdAt.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ),

            // Message text
            Text(
              msg.message,
              style: TextStyle(
                color: isMe ? cs.onPrimary : cs.onSurface,
              ),
              softWrap: true,
              maxLines: null,
            ),

            // Attachment indicator
            if (msg.attachmentUrl != null || msg.fileUrl != null || msg.audioUrl != null)
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.attach_file_rounded,
                  size: 12,
                  color: Colors.white70,
                ),
              ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${l10n.chatRoom} #${widget.roomId.substring(0, 6)}'),
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              data: (messages) {
if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_outlined, size: 48,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
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
                    return _buildMessageCard(msg);
                  },
                );
              },
              loading: () => const Center(child: AppLoaderCircular()),
              error: (e, _) =>
                  Center(child: Text('${l10n.error}: $e')),
            ),
          ),

          // Input area
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border(top: BorderSide(color: cs.outlineVariant)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: l10n.typeMessage,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                    ),
                    focusNode: FocusNode(),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  icon: const Icon(Icons.send_rounded),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final authState = ref.read(authStateProvider);
    final user = authState is AuthAuthenticated ? authState.user : null;
    if (user == null) return;

    final message = ChatMessage(
      id: '',
      roomId: widget.roomId,
      senderId: user.id,
      message: text,
      isFromAdmin: false,
      createdAt: DateTime.now(),
    );

    final repo = ref.read(chatRepositoryProvider);
    await repo.sendMessage(message);
    _messageController.clear();
    ref.invalidate(chatMessagesProvider(widget.roomId));
    _scrollToBottom();
  }
}