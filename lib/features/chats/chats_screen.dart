import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app_services.dart';
import '../../core/format.dart';
import '../../data/sync/sync_api.dart';
import '../../data/sync/sync_service.dart';
import '../auth/auth_cubit.dart';

/// Who is chatting: the cloud token of this phone (or member session) and,
/// for phones joined before member sign-in, the name to show.
class ChatAccess {
  const ChatAccess(this.token, {this.asName});
  final String token;
  final String? asName;
}

/// Chat access for the signed-in officer on a synced phone, or null when
/// this phone does not use the cloud.
ChatAccess? officerChatAccess(BuildContext context) {
  final token = context.select((SyncService s) => s.state.credentials?.token);
  final user = context.select((AuthCubit c) => c.user);
  if (token == null || user == null) return null;
  return ChatAccess(
    token,
    asName: user.memberAccount ? null : user.displayName,
  );
}

/// The group chats this person is in. Chats live in the cloud and need
/// internet; who is in each one follows their roles.
class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key, required this.access, this.embedded = false});

  final ChatAccess access;

  /// Shown as a tab (no app bar of its own).
  final bool embedded;

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  late final _api = context.read<AppServices>().sync.api;
  List<ChatChannel>? _channels;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final c = await _api.chatChannels(
        widget.access.token,
        asName: widget.access.asName,
      );
      if (mounted) {
        setState(() {
          _channels = c;
          _error = null;
        });
      }
    } on SyncException catch (e) {
      if (mounted) {
        setState(
          () => _error = e.offline
              ? 'Chats need internet. Connect and pull down to try again.'
              : e.message,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final channels = _channels;
    final list = RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (_error != null)
            Padding(padding: const EdgeInsets.all(16), child: Text(_error!)),
          if (channels == null && _error == null)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
          for (final c in channels ?? const <ChatChannel>[])
            ListTile(
              leading: CircleAvatar(
                child: Icon(
                  c.id == 'announcements' || c.id.startsWith('announce:')
                      ? Icons.campaign_outlined
                      : Icons.forum_outlined,
                ),
              ),
              title: Text(c.name),
              subtitle: Text(
                c.last ?? 'No messages yet',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: c.lastAt == null
                  ? null
                  : Text(
                      formatDate(c.lastAt),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        ChatScreen(access: widget.access, channel: c),
                  ),
                );
                _load();
              },
            ),
        ],
      ),
    );
    if (widget.embedded) return list;
    return Scaffold(
      appBar: AppBar(title: const Text('Chats')),
      body: list,
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.access, required this.channel});

  final ChatAccess access;
  final ChatChannel channel;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  static const _every = Duration(seconds: 8);

  late final _api = context.read<AppServices>().sync.api;
  final _text = TextEditingController();
  final _messages = <ChatMessage>[];
  Timer? _timer;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _poll();
    _timer = Timer.periodic(_every, (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _text.dispose();
    super.dispose();
  }

  Future<void> _poll() async {
    try {
      final next = await _api.chatMessages(
        widget.access.token,
        widget.channel.id,
        after: _messages.isEmpty ? null : _messages.last.at,
        asName: widget.access.asName,
      );
      if (!mounted) return;
      setState(() {
        final seen = {for (final m in _messages) m.id};
        _messages.addAll(next.where((m) => !seen.contains(m.id)));
        _error = null;
      });
    } on SyncException catch (e) {
      if (mounted) {
        setState(
          () => _error = e.offline ? 'No internet connection.' : e.message,
        );
      }
    }
  }

  Future<void> _send() async {
    final body = _text.text.trim();
    if (body.isEmpty) return;
    setState(() => _sending = true);
    try {
      await _api.chatSend(
        widget.access.token,
        widget.channel.id,
        body,
        asName: widget.access.asName,
      );
      _text.clear();
      await _poll();
    } on SyncException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.offline ? 'No internet. Your message was not sent.' : e.message,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reversed = _messages.reversed.toList();
    return Scaffold(
      appBar: AppBar(title: Text(widget.channel.name)),
      body: Column(
        children: [
          if (_error != null)
            MaterialBanner(
              content: Text(_error!),
              actions: [
                TextButton(onPressed: _poll, child: const Text('Try again')),
              ],
            ),
          Expanded(
            child: reversed.isEmpty
                ? const Center(child: Text('No messages yet.'))
                : ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.all(12),
                    itemCount: reversed.length,
                    itemBuilder: (context, i) {
                      final m = reversed[i];
                      return Align(
                        alignment: m.mine
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 320),
                          child: Card(
                            color: m.mine
                                ? theme.colorScheme.primaryContainer
                                : null,
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (!m.mine)
                                    Text.rich(
                                      TextSpan(
                                        text: m.author,
                                        children: [
                                          if (m.authorWhatsapp != null)
                                            TextSpan(
                                              text: '  ~${m.authorWhatsapp}',
                                              style: theme.textTheme.bodySmall,
                                            ),
                                        ],
                                      ),
                                      style: theme.textTheme.labelMedium,
                                    ),
                                  Text(m.body),
                                  Text(
                                    formatDateTime(m.at),
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: widget.channel.canPost
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 4, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            key: const Key('chatText'),
                            controller: _text,
                            minLines: 1,
                            maxLines: 4,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: const InputDecoration(
                              hintText: 'Write a message',
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Send',
                          onPressed: _sending ? null : _send,
                          icon: const Icon(Icons.send),
                        ),
                      ],
                    ),
                  )
                : const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      'Only the Founder and General Secretary post here.',
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
