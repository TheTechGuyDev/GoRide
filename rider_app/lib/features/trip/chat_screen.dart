import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import 'trip_controller.dart';
import 'trip_models.dart';

/// Screen 30. Later: messages stored in a Supabase `trip_messages` table
/// with Realtime, so the driver app sees them instantly.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _text = TextEditingController();
  final _scroll = ScrollController();

  static const _quickReplies = [
    'I\'m on my way out',
    'I\'m at the gate',
    'Where are you now?',
    'Please call me',
  ];

  void _send(String text) {
    ref.read(tripControllerProvider.notifier).sendMessage(text);
    _text.clear();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trip = ref.watch(tripControllerProvider);
    final d = trip?.driver;
    final messages = trip?.messages ?? const <ChatMessage>[];

    // Everything on screen counts as read.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(tripControllerProvider.notifier).markMessagesRead();
    });
    ref.listen(tripControllerProvider, (prev, next) {
      if ((prev?.messages.length ?? 0) != (next?.messages.length ?? 0)) {
        _scrollToEnd();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(d?.name ?? 'Chat'),
        actions: [
          IconButton(
            icon: const Icon(Icons.call_outlined),
            onPressed: () => context.push(Routes.call),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty
                ? const Center(
                    child: Text(
                      'Say hello to your driver 👋',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(20),
                    itemCount: messages.length,
                    itemBuilder: (_, i) => _Bubble(message: messages[i]),
                  ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final q in _quickReplies)
                  Padding(
                    padding: const EdgeInsets.only(right: 8, bottom: 6),
                    child: ActionChip(
                      label: Text(q),
                      onPressed: () => _send(q),
                      shape: const StadiumBorder(
                        side: BorderSide(color: AppColors.border),
                      ),
                      backgroundColor: Colors.white,
                    ),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _text,
                      textInputAction: TextInputAction.send,
                      onSubmitted: _send,
                      decoration: const InputDecoration(
                        hintText: 'Send a message...',
                        prefixIcon: Icon(
                          Icons.sentiment_satisfied_alt_outlined,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => _send(_text.text),
                    child: Container(
                      width: 54,
                      height: 54,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final mine = message.fromRider;
    final t = message.time;
    final time =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.75,
        ),
        decoration: BoxDecoration(
          color: mine ? AppColors.primary : AppColors.fieldFill,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(mine ? 14 : 4),
            bottomRight: Radius.circular(mine ? 4 : 14),
          ),
        ),
        child: Wrap(
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.end,
          spacing: 8,
          children: [
            Text(
              message.text,
              style: TextStyle(
                fontSize: 15,
                height: 1.4,
                color: mine ? Colors.white : AppColors.textPrimary,
              ),
            ),
            Text(
              time,
              style: TextStyle(
                fontSize: 10,
                color: mine ? Colors.white70 : AppColors.textHint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
