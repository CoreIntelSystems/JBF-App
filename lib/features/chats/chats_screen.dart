import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../app_services.dart';
import '../../core/format.dart';
import '../../core/share_file.dart';
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

/// The biggest picture or document that can be sent.
const _maxFileBytes = 3000000;

const _stickers = [
  '👍',
  '🙏',
  '❤️',
  '😂',
  '😍',
  '😊',
  '🎉',
  '👏',
  '🙌',
  '💪',
  '🤝',
  '😢',
  '😮',
  '😎',
  '🥳',
  '🔥',
  '✅',
  '🙂',
  '🤗',
  '😇',
  '🌹',
  '🎂',
  '🕊️',
  '🇬🇭',
];

String _mimeOf(String name) {
  final e = name.contains('.') ? name.split('.').last.toLowerCase() : '';
  return switch (e) {
    'pdf' => 'application/pdf',
    'png' => 'image/png',
    'jpg' || 'jpeg' => 'image/jpeg',
    'gif' => 'image/gif',
    'webp' => 'image/webp',
    'doc' => 'application/msword',
    'docx' =>
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xls' => 'application/vnd.ms-excel',
    'xlsx' =>
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'ppt' => 'application/vnd.ms-powerpoint',
    'pptx' =>
      'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'txt' => 'text/plain',
    'csv' => 'text/csv',
    'mp3' => 'audio/mpeg',
    'mp4' => 'video/mp4',
    _ => 'application/octet-stream',
  };
}

String _sizeText(int bytes) => bytes >= 1000000
    ? '${(bytes / 1000000).toStringAsFixed(1)} MB'
    : '${(bytes / 1000).ceil()} KB';

/// What a quoted message looks like in a preview.
String _quoteText(String kind, String body) => switch (kind) {
  'image' => body.isEmpty ? '📷 Photo' : '📷 $body',
  'file' => body.isEmpty ? '📄 Document' : '📄 $body',
  'sticker' => body,
  _ => body,
};

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.access,
    required this.channel,
    this.api,
  });

  final ChatAccess access;
  final ChatChannel channel;

  /// Only for tests; the app uses the signed-in cloud connection.
  final SyncApi? api;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  static const _every = Duration(seconds: 8);
  static const _wallpaper = Color(0xFFECE5DD);
  static const _mineBubble = Color(0xFFDCF8C6);

  late final _api = widget.api ?? context.read<AppServices>().sync.api;
  final _text = TextEditingController();
  final _messages = <ChatMessage>[];
  final _avatars = <String, Uint8List>{};
  final _files = <String, Future<Uint8List>>{};
  Timer? _timer;
  bool _sending = false;
  String? _error;
  ChatMessage? _replyTo;

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
      final unknown = next.any(
        (m) => m.authorKey != null && !_avatars.containsKey(m.authorKey),
      );
      setState(() {
        final seen = {for (final m in _messages) m.id};
        _messages.addAll(next.where((m) => !seen.contains(m.id)));
        _error = null;
      });
      if (unknown || _avatarsLoaded == false) _loadAvatars();
    } on SyncException catch (e) {
      if (mounted) {
        setState(
          () => _error = e.offline ? 'No internet connection.' : e.message,
        );
      }
    }
  }

  bool _avatarsLoaded = false;

  /// Everyone's picture. Authors without one stay out of the map and show
  /// their initials.
  Future<void> _loadAvatars() async {
    _avatarsLoaded = true;
    try {
      final r = await _api.chatAvatars(
        widget.access.token,
        widget.channel.id,
        asName: widget.access.asName,
      );
      if (!mounted) return;
      setState(() {
        _avatars
          ..clear()
          ..addAll({
            for (final e in r.entries)
              if (e.value.contains(','))
                e.key: base64Decode(e.value.split(',').last),
          });
        // Remember who has been looked up, so we do not ask again for
        // authors without a picture.
        for (final m in _messages) {
          if (m.authorKey != null) {
            _avatars.putIfAbsent(m.authorKey!, () => Uint8List(0));
          }
        }
      });
    } on SyncException catch (_) {}
  }

  void _toast(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _post(
    String body, {
    String kind = 'text',
    String? fileName,
    String? fileMime,
    Uint8List? fileBytes,
  }) async {
    setState(() => _sending = true);
    try {
      await _api.chatPost(
        widget.access.token,
        widget.channel.id,
        body,
        replyTo: _replyTo?.id,
        kind: kind,
        fileName: fileName,
        fileMime: fileMime,
        fileData: fileBytes == null ? null : base64Encode(fileBytes),
        asName: widget.access.asName,
      );
      _replyTo = null;
      await _poll();
    } on SyncException catch (e) {
      if (mounted) {
        _toast(
          e.offline ? 'No internet. Your message was not sent.' : e.message,
        );
      }
      rethrow;
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _send() async {
    final body = _text.text.trim();
    if (body.isEmpty) return;
    try {
      await _post(body);
      _text.clear();
    } on SyncException catch (_) {}
  }

  Future<void> _sendSticker() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: GridView.count(
          crossAxisCount: 6,
          shrinkWrap: true,
          padding: const EdgeInsets.all(12),
          children: [
            for (final s in _stickers)
              InkWell(
                key: Key('sticker$s'),
                onTap: () => Navigator.pop(context, s),
                child: Center(
                  child: Text(s, style: const TextStyle(fontSize: 30)),
                ),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    try {
      await _post(picked, kind: 'sticker');
    } on SyncException catch (_) {}
  }

  Future<void> _attach() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const Key('attachGallery'),
              leading: const Icon(Icons.photo_outlined),
              title: const Text('Photo from gallery'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              key: const Key('attachDocument'),
              leading: const Icon(Icons.insert_drive_file_outlined),
              title: const Text('Document'),
              onTap: () => Navigator.pop(context, 'document'),
            ),
          ],
        ),
      ),
    );
    if (choice == null) return;
    try {
      if (choice == 'document') {
        final picked = await FilePicker.pickFile(
          dialogTitle: 'Choose a document',
        );
        if (picked == null) return;
        final bytes = await picked.xFile.readAsBytes();
        if (bytes.length > _maxFileBytes) {
          if (mounted) {
            _toast('That file is too big. The most you can send is 3 MB.');
          }
          return;
        }
        final name = picked.xFile.name;
        final mime = _mimeOf(name);
        await _post(
          _text.text.trim(),
          kind: mime.startsWith('image/') ? 'image' : 'file',
          fileName: name,
          fileMime: mime,
          fileBytes: bytes,
        );
      } else {
        final picked = await ImagePicker().pickImage(
          source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
          maxWidth: 1280,
          maxHeight: 1280,
          imageQuality: 75,
        );
        if (picked == null) return;
        final bytes = await picked.readAsBytes();
        if (bytes.length > _maxFileBytes) {
          if (mounted) _toast('That picture is too big.');
          return;
        }
        await _post(
          _text.text.trim(),
          kind: 'image',
          fileName: picked.name,
          fileMime: _mimeOf(picked.name),
          fileBytes: bytes,
        );
      }
      _text.clear();
    } on SyncException catch (_) {}
  }

  /// My own chat picture: chosen from the gallery, shrunk, or removed.
  Future<void> _myPicture(String choice) async {
    try {
      if (choice == 'remove') {
        await _api.avatarSet(
          widget.access.token,
          null,
          asName: widget.access.asName,
        );
      } else {
        final picked = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          maxWidth: 200,
          maxHeight: 200,
          imageQuality: 70,
        );
        if (picked == null) return;
        final bytes = await picked.readAsBytes();
        final type = picked.name.toLowerCase().endsWith('.png')
            ? 'png'
            : 'jpeg';
        await _api.avatarSet(
          widget.access.token,
          'data:image/$type;base64,${base64Encode(bytes)}',
          asName: widget.access.asName,
        );
      }
      if (mounted) _toast('Done. Your picture will show in the chats.');
      await _loadAvatars();
    } on SyncException catch (e) {
      if (mounted) _toast(e.offline ? 'No internet.' : e.message);
    }
  }

  Future<Uint8List> _fileBytes(ChatFile f) => _files.putIfAbsent(
    f.id,
    () => _api.chatFile(
      widget.access.token,
      widget.channel.id,
      f.id,
      asName: widget.access.asName,
    ),
  );

  Future<void> _openFile(ChatFile f) async {
    try {
      final bytes = await _fileBytes(f);
      await shareBytes(bytes, f.name, mimeType: f.mime);
    } on SyncException catch (e) {
      _files.remove(f.id);
      if (mounted) _toast(e.offline ? 'No internet.' : e.message);
    }
  }

  Future<void> _showPicture(ChatFile f) async {
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Positioned.fill(
              child: FutureBuilder<Uint8List>(
                future: _fileBytes(f),
                builder: (context, snap) => snap.hasData
                    ? InteractiveViewer(child: Image.memory(snap.data!))
                    : const Center(child: CircularProgressIndicator()),
              ),
            ),
            SafeArea(
              child: IconButton(
                color: Colors.white,
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _messageMenu(ChatMessage m) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.channel.canPost)
              ListTile(
                key: const Key('menuReply'),
                leading: const Icon(Icons.reply),
                title: const Text('Reply'),
                onTap: () => Navigator.pop(context, 'reply'),
              ),
            if (m.body.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('Copy'),
                onTap: () => Navigator.pop(context, 'copy'),
              ),
          ],
        ),
      ),
    );
    if (choice == 'reply') {
      setState(() => _replyTo = m);
    } else if (choice == 'copy') {
      await Clipboard.setData(ClipboardData(text: m.body));
      if (mounted) _toast('Copied.');
    }
  }

  /// The same colour for the same person every time, as in WhatsApp.
  Color _nameColor(String name) {
    const colors = [
      Color(0xFF1F7A5A),
      Color(0xFFB5651D),
      Color(0xFF6A4C93),
      Color(0xFFC0392B),
      Color(0xFF2471A3),
      Color(0xFF8E6B00),
      Color(0xFF117A65),
      Color(0xFFAD1457),
    ];
    return colors[name.codeUnits.fold<int>(0, (a, b) => a + b) % colors.length];
  }

  Widget _avatar(ChatMessage m) {
    final bytes = m.authorKey == null ? null : _avatars[m.authorKey];
    final letters = m.author
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();
    return CircleAvatar(
      key: Key('avatar-${m.id}'),
      radius: 18,
      backgroundColor: _nameColor(m.author).withValues(alpha: 0.25),
      backgroundImage: bytes != null && bytes.isNotEmpty
          ? MemoryImage(bytes)
          : null,
      child: bytes != null && bytes.isNotEmpty
          ? null
          : Text(letters, style: TextStyle(color: _nameColor(m.author))),
    );
  }

  Widget _quote(ChatQuote q, {required bool inBubble}) {
    final color = _nameColor(q.author);
    return Container(
      margin: inBubble ? const EdgeInsets.only(bottom: 6) : null,
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(6),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            q.author,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          Text(
            _quoteText(q.kind, q.body),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _content(ChatMessage m) {
    final f = m.file;
    switch (m.kind) {
      case 'sticker':
        return Text(m.body, style: const TextStyle(fontSize: 64));
      case 'image' when f != null:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => _showPicture(f),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: FutureBuilder<Uint8List>(
                  future: _fileBytes(f),
                  builder: (context, snap) => snap.hasData
                      ? Image.memory(
                          snap.data!,
                          width: 240,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const SizedBox(
                            width: 240,
                            height: 80,
                            child: Center(child: Icon(Icons.broken_image)),
                          ),
                        )
                      : const SizedBox(
                          width: 240,
                          height: 140,
                          child: Center(child: CircularProgressIndicator()),
                        ),
                ),
              ),
            ),
            if (m.body.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(m.body),
              ),
          ],
        );
      case 'file' when f != null:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              key: Key('file-${m.id}'),
              onTap: () => _openFile(f),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.insert_drive_file, size: 32),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            f.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            _sizeText(f.size),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.download_outlined),
                  ],
                ),
              ),
            ),
            if (m.body.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(m.body),
              ),
          ],
        );
      default:
        return Text(m.body);
    }
  }

  Widget _bubble(ChatMessage m, {required bool showName}) {
    final theme = Theme.of(context);
    final sticker = m.kind == 'sticker';
    final who = StringBuffer(m.author);
    final sub = [
      if (m.authorWhatsapp != null && m.authorWhatsapp!.isNotEmpty)
        '~${m.authorWhatsapp}',
      if (m.zones.isNotEmpty) m.zones.join(', '),
    ].join(' · ');
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!m.mine && showName) ...[
          Text(
            who.toString(),
            style: TextStyle(
              color: _nameColor(m.author),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          if (sub.isNotEmpty)
            Text(sub, style: theme.textTheme.bodySmall?.copyWith(fontSize: 11)),
          const SizedBox(height: 2),
        ],
        if (m.reply != null) _quote(m.reply!, inBubble: true),
        _content(m),
        Align(
          alignment: Alignment.bottomRight,
          child: Text(
            formatDateTime(m.at),
            style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
          ),
        ),
      ],
    );
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.72,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: sticker
              ? Colors.transparent
              : (m.mine ? _mineBubble : Colors.white),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: Radius.circular(m.mine ? 12 : 2),
            bottomRight: Radius.circular(m.mine ? 2 : 12),
          ),
          boxShadow: sticker
              ? null
              : const [BoxShadow(color: Colors.black12, blurRadius: 1)],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 4),
          child: content,
        ),
      ),
    );
  }

  Widget _row(List<ChatMessage> reversed, int i) {
    final m = reversed[i];
    // reversed[i + 1] is the message just before this one.
    final before = i + 1 < reversed.length ? reversed[i + 1] : null;
    final first =
        before == null ||
        before.authorKey != m.authorKey ||
        before.author != m.author;
    final bubble = GestureDetector(
      key: Key('msg-${m.id}'),
      onLongPress: () => _messageMenu(m),
      onHorizontalDragEnd: (d) {
        if (widget.channel.canPost && (d.primaryVelocity ?? 0) > 300) {
          setState(() => _replyTo = m);
        }
      },
      child: _bubble(m, showName: first),
    );
    return Padding(
      padding: EdgeInsets.only(top: first ? 8 : 2),
      child: Row(
        mainAxisAlignment: m.mine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!m.mine) SizedBox(width: 40, child: first ? _avatar(m) : null),
          Flexible(child: bubble),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reversed = _messages.reversed.toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.channel.name),
        actions: [
          PopupMenuButton<String>(
            key: const Key('myPicture'),
            tooltip: 'My chat picture',
            icon: const Icon(Icons.account_circle_outlined),
            onSelected: _myPicture,
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'choose', child: Text('Choose my picture')),
              PopupMenuItem(value: 'remove', child: Text('Remove my picture')),
            ],
          ),
        ],
      ),
      backgroundColor: _wallpaper,
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
                    padding: const EdgeInsets.all(10),
                    itemCount: reversed.length,
                    itemBuilder: (context, i) => _row(reversed, i),
                  ),
          ),
          SafeArea(
            top: false,
            child: widget.channel.canPost
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_replyTo != null)
                        Container(
                          key: const Key('replyBar'),
                          color: theme.colorScheme.surface,
                          padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
                          child: Row(
                            children: [
                              Expanded(
                                child: _quote(
                                  ChatQuote(
                                    id: _replyTo!.id,
                                    author: _replyTo!.mine
                                        ? 'You'
                                        : _replyTo!.author,
                                    body: _replyTo!.body,
                                    kind: _replyTo!.kind,
                                  ),
                                  inBubble: false,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Cancel reply',
                                icon: const Icon(Icons.close),
                                onPressed: () =>
                                    setState(() => _replyTo = null),
                              ),
                            ],
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(6, 4, 4, 6),
                        child: Row(
                          children: [
                            IconButton(
                              key: const Key('stickerButton'),
                              tooltip: 'Stickers',
                              onPressed: _sending ? null : _sendSticker,
                              icon: const Icon(Icons.emoji_emotions_outlined),
                            ),
                            Expanded(
                              child: TextField(
                                key: const Key('chatText'),
                                controller: _text,
                                minLines: 1,
                                maxLines: 4,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                decoration: InputDecoration(
                                  hintText: 'Write a message',
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(24),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              key: const Key('attachButton'),
                              tooltip: 'Attach',
                              onPressed: _sending ? null : _attach,
                              icon: const Icon(Icons.attach_file),
                            ),
                            CircleAvatar(
                              backgroundColor: theme.colorScheme.primary,
                              child: IconButton(
                                tooltip: 'Send',
                                color: theme.colorScheme.onPrimary,
                                onPressed: _sending ? null : _send,
                                icon: const Icon(Icons.send),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
