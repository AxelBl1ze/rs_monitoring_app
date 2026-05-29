import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/doctor_models.dart';
import '../services/supabase_service.dart';
import '../widgets/nl_widgets.dart';

class ChatScreen extends StatefulWidget {
  final String otherUserId;
  final String otherUserName;
  final String subtitle;

  const ChatScreen({
    super.key,
    required this.otherUserId,
    required this.otherUserName,
    this.subtitle = '',
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  List<ChatMessage> _messages = [];
  bool _loading = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final messages = await SupabaseService.getChatMessages(
        widget.otherUserId,
      );
      await SupabaseService.markChatAsRead(widget.otherUserId);
      if (!mounted) return;
      setState(() => _messages = messages);
      _scrollToBottom();
    } catch (_) {
      if (mounted) setState(() => _error = 'Не удалось загрузить сообщения');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final text = _messageCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await SupabaseService.sendChatMessage(
        receiverId: widget.otherUserId,
        body: text,
      );
      _messageCtrl.clear();
      await _load();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  String _time(DateTime value) {
    final local = value.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  List<_ChatItem> _buildItems() {
    final items = <_ChatItem>[];
    DateTime? currentDay;
    for (final message in _messages) {
      final localCreated = message.createdAt.toLocal();
      final day = DateTime(
        localCreated.year,
        localCreated.month,
        localCreated.day,
      );
      if (currentDay == null || !isSameDay(currentDay, day)) {
        items.add(_ChatItem.date(day));
        currentDay = day;
      }
      items.add(_ChatItem.message(message));
    }
    return items;
  }

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _dateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final current = DateTime(date.year, date.month, date.day);
    if (current == today) return 'Сегодня';
    if (current == today.subtract(const Duration(days: 1))) return 'Вчера';
    const monthNames = [
      'января',
      'февраля',
      'марта',
      'апреля',
      'мая',
      'июня',
      'июля',
      'августа',
      'сентября',
      'октября',
      'ноября',
      'декабря',
    ];
    return '${date.day} ${monthNames[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = SupabaseService.currentUserId;

    return Scaffold(
      backgroundColor: NLColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            NLTopBar(leading: const NLBackBtn(), title: widget.otherUserName),
            if (widget.subtitle.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    widget.subtitle,
                    style: const TextStyle(fontSize: 13, color: NLColors.muted),
                  ),
                ),
              ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: NLColors.accent),
                    )
                  : _error != null
                  ? Center(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: NLColors.bad),
                      ),
                    )
                  : _messages.isEmpty
                  ? const _EmptyChat()
                  : RefreshIndicator(
                      color: NLColors.accent,
                      onRefresh: _load,
                      child: Builder(
                        builder: (context) {
                          final items = _buildItems();
                          return ListView.builder(
                            controller: _scrollCtrl,
                            padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
                            itemCount: items.length,
                            itemBuilder: (context, index) {
                              final item = items[index];
                              if (item.isDateHeader) {
                                return _DateHeader(
                                  label: _dateLabel(item.date!),
                                );
                              }
                              final message = item.message!;
                              final mine =
                                  currentUserId != null &&
                                  message.isMine(currentUserId);
                              return _MessageBubble(
                                message: message,
                                mine: mine,
                                time: _time(message.createdAt),
                              );
                            },
                          );
                        },
                      ),
                    ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(
                18,
                10,
                18,
                12 + MediaQuery.of(context).viewInsets.bottom,
              ),
              decoration: const BoxDecoration(
                color: NLColors.surface,
                border: Border(top: BorderSide(color: NLColors.line)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageCtrl,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText: 'Написать сообщение',
                        hintStyle: const TextStyle(color: NLColors.muted),
                        filled: true,
                        fillColor: NLColors.surface2,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _send,
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: const BoxDecoration(
                        color: NLColors.ink,
                        shape: BoxShape.circle,
                      ),
                      child: _sending
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.send_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool mine;
  final String time;

  const _MessageBubble({
    required this.message,
    required this.mine,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.76,
        ),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: mine ? NLColors.accent : NLColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(mine ? 18 : 5),
            bottomRight: Radius.circular(mine ? 5 : 18),
          ),
          boxShadow: shadowCard,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.body,
              style: TextStyle(
                fontSize: 15,
                height: 1.35,
                color: mine ? Colors.white : NLColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              time,
              style: TextStyle(
                fontSize: 11,
                color: mine ? Colors.white70 : NLColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateHeader extends StatelessWidget {
  final String label;

  const _DateHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Align(
        alignment: Alignment.center,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: NLColors.surface2,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: NLColors.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatItem {
  final DateTime? date;
  final ChatMessage? message;

  const _ChatItem.date(this.date) : message = null;
  const _ChatItem.message(this.message) : date = null;

  bool get isDateHeader => date != null;
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        children: const [
          Icon(Icons.forum_outlined, color: NLColors.muted, size: 42),
          SizedBox(height: 10),
          Text(
            'Сообщений пока нет',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: NLColors.ink,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Начните диалог внутри приложения.',
            style: TextStyle(fontSize: 13, color: NLColors.muted),
          ),
        ],
      ),
    );
  }
}
