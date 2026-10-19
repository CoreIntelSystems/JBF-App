import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

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

/// "My picture": shows the picture other people see next to my messages
/// and lets me choose a new one or remove it.
class MyPictureTile extends StatefulWidget {
  const MyPictureTile({super.key, required this.token, this.asName, this.api});

  final String token;
  final String? asName;

  /// Only for tests.
  final SyncApi? api;

  @override
  State<MyPictureTile> createState() => _MyPictureTileState();
}

class _MyPictureTileState extends State<MyPictureTile> {
  late final _api = widget.api ?? context.read<AppServices>().sync.api;
  Uint8List? _photo;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final url = await _api.avatarGet(widget.token, asName: widget.asName);
      if (!mounted) return;
      setState(
        () => _photo = url != null && url.contains(',')
            ? base64Decode(url.split(',').last)
            : null,
      );
    } on SyncException catch (_) {}
  }

  Future<void> _change(String choice) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (choice == 'remove') {
        await _api.avatarSet(widget.token, null, asName: widget.asName);
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
          widget.token,
          'data:image/$type;base64,${base64Encode(bytes)}',
          asName: widget.asName,
        );
      }
      await _load();
      messenger.showSnackBar(
        const SnackBar(content: Text('Done. Your picture shows in the chats.')),
      );
    } on SyncException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(e.offline ? 'No internet.' : e.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: const Key('myPictureTile'),
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundImage: _photo == null ? null : MemoryImage(_photo!),
        child: _photo == null ? const Icon(Icons.person_outline) : null,
      ),
      title: const Text('My picture'),
      subtitle: const Text('Shows next to your messages in the chats'),
      trailing: PopupMenuButton<String>(
        tooltip: 'Change my picture',
        onSelected: _change,
        itemBuilder: (context) => const [
          PopupMenuItem(value: 'choose', child: Text('Choose a picture')),
          PopupMenuItem(value: 'remove', child: Text('Remove my picture')),
        ],
      ),
    );
  }
}

/// The chat's own colours, for light and dark.
class _Pal {
  const _Pal({
    required this.dark,
    required this.wall,
    required this.incoming,
    required this.outgoing,
    required this.text,
    required this.soft,
    required this.chip,
    required this.chipText,
    required this.tick,
    required this.field,
    required this.bar,
  });

  final bool dark;
  final Color wall;
  final Color incoming;
  final Color outgoing;
  final Color text;
  final Color soft;
  final Color chip;
  final Color chipText;
  final Color tick;
  final Color field;
  final Color bar;

  static _Pal of(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark
        ? const _Pal(
            dark: true,
            wall: Color(0xFF121A15),
            incoming: Color(0xFF212B25),
            outgoing: Color(0xFF1D5A39),
            text: Color(0xFFEEF2EE),
            soft: Color(0xFFA3B0A7),
            chip: Color(0xFF2D2A14),
            chipText: Color(0xFFE3C76A),
            tick: Color(0xFF7FD3A1),
            field: Color(0xFF151D18),
            bar: Color(0xFF0C120E),
          )
        : const _Pal(
            dark: false,
            wall: Color(0xFFEFE9E1),
            incoming: Colors.white,
            outgoing: Color(0xFFD9F3C4),
            text: Color(0xFF17201B),
            soft: Color(0xFF6B776F),
            chip: Color(0xFFF1EAD0),
            chipText: Color(0xFF6A5410),
            tick: Color(0xFF2A9D5C),
            field: Colors.white,
            bar: Color(0xFFF3F5F2),
          );
  }
}

String _clock(DateTime t) => DateFormat('h:mm a').format(t);

String _dayLabel(DateTime t) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(t.year, t.month, t.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  return DateFormat('d MMM yyyy').format(t);
}

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
  Color _nameColor(String name, [bool lift = false]) {
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
    final c =
        colors[name.codeUnits.fold<int>(0, (a, b) => a + b) % colors.length];
    return lift ? Color.lerp(c, Colors.white, 0.55)! : c;
  }

  Widget _avatar(ChatMessage m) {
    final pal = _Pal.of(context);
    final bytes = m.authorKey == null ? null : _avatars[m.authorKey];
    final letters = m.author
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();
    final colour = _nameColor(m.author, pal.dark);
    return CircleAvatar(
      key: Key('avatar-${m.id}'),
      radius: 16,
      backgroundColor: colour.withValues(alpha: 0.22),
      backgroundImage: bytes != null && bytes.isNotEmpty
          ? MemoryImage(bytes)
          : null,
      child: bytes != null && bytes.isNotEmpty
          ? null
          : Text(
              letters,
              style: TextStyle(
                color: colour,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
    );
  }

  Widget _quote(ChatQuote q, {required bool inBubble}) {
    final pal = _Pal.of(context);
    final color = _nameColor(q.author, pal.dark);
    return Container(
      margin: inBubble ? const EdgeInsets.only(top: 2, bottom: 5) : null,
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border(left: BorderSide(color: color, width: 3)),
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
            style: TextStyle(fontSize: 13, color: pal.soft),
          ),
        ],
      ),
    );
  }

  Widget _content(ChatMessage m) {
    final pal = _Pal.of(context);
    final f = m.file;
    final caption = m.body.isEmpty
        ? null
        : Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(m.body, style: TextStyle(color: pal.text)),
          );
    switch (m.kind) {
      case 'sticker':
        return Text(m.body, style: const TextStyle(fontSize: 56));
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
            ?caption,
          ],
        );
      case 'file' when f != null:
        final ext = f.name.contains('.')
            ? f.name.split('.').last.toUpperCase()
            : 'FILE';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              key: Key('file-${m.id}'),
              borderRadius: BorderRadius.circular(9),
              onTap: () => _openFile(f),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: pal.soft.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 38,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD64545),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        ext.length <= 4 ? ext : 'FILE',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            f.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: pal.text,
                              fontWeight: FontWeight.w600,
                              fontSize: 13.5,
                            ),
                          ),
                          Text(
                            _sizeText(f.size),
                            style: TextStyle(fontSize: 11.5, color: pal.soft),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: pal.soft, width: 1.5),
                      ),
                      child: Icon(
                        Icons.download_outlined,
                        size: 16,
                        color: pal.soft,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ?caption,
          ],
        );
      default:
        return Text(m.body, style: TextStyle(color: pal.text));
    }
  }

  Widget _bubble(ChatMessage m, {required bool showName}) {
    final pal = _Pal.of(context);
    final sticker = m.kind == 'sticker';
    final nameColour = _nameColor(m.author, pal.dark);
    final small = TextStyle(fontSize: 10.5, color: pal.soft);
    final foot = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(_clock(m.at), style: small),
        if (m.mine) ...[
          const SizedBox(width: 4),
          Icon(Icons.done_all, size: 15, color: pal.tick),
        ],
      ],
    );
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!m.mine && showName)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              runSpacing: 2,
              children: [
                Text(
                  m.author,
                  style: TextStyle(
                    color: nameColour,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                if (m.authorWhatsapp != null && m.authorWhatsapp!.isNotEmpty)
                  Text(
                    '~${m.authorWhatsapp}',
                    style: small.copyWith(fontStyle: FontStyle.italic),
                  ),
                for (final z in m.zones)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: pal.chip,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      z,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: pal.chipText,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        if (m.reply != null) _quote(m.reply!, inBubble: true),
        _content(m),
        const SizedBox(height: 1),
        Align(alignment: Alignment.bottomRight, child: foot),
      ],
    );
    final r = Radius.circular(12);
    final tail = Radius.circular(showName ? 3 : 12);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.78,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: sticker
              ? Colors.transparent
              : (m.mine ? pal.outgoing : pal.incoming),
          borderRadius: BorderRadius.only(
            topLeft: m.mine ? r : tail,
            topRight: m.mine ? tail : r,
            bottomLeft: r,
            bottomRight: r,
          ),
          boxShadow: sticker || pal.dark
              ? null
              : const [
                  BoxShadow(
                    color: Color(0x29131C17),
                    blurRadius: 1.5,
                    offset: Offset(0, 1),
                  ),
                ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 4),
          child: content,
        ),
      ),
    );
  }

  Widget _dayChip(DateTime t) {
    final pal = _Pal.of(context);
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 8, bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: pal.incoming,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          _dayLabel(t),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: pal.soft,
          ),
        ),
      ),
    );
  }

  Widget _row(List<ChatMessage> reversed, int i) {
    final m = reversed[i];
    // reversed[i + 1] is the message just before this one.
    final before = i + 1 < reversed.length ? reversed[i + 1] : null;
    final newDay =
        before == null ||
        before.at.year != m.at.year ||
        before.at.month != m.at.month ||
        before.at.day != m.at.day;
    final first =
        newDay || before.authorKey != m.authorKey || before.author != m.author;
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
    final row = Padding(
      padding: EdgeInsets.only(top: first ? 8 : 2),
      child: Row(
        mainAxisAlignment: m.mine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!m.mine) SizedBox(width: 39, child: first ? _avatar(m) : null),
          Flexible(child: bubble),
        ],
      ),
    );
    if (!newDay) return row;
    return Column(children: [_dayChip(m.at), row]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pal = _Pal.of(context);
    final reversed = _messages.reversed.toList();
    final name = widget.channel.name;
    final initials = name
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFFC9A227),
              child: Text(
                initials,
                style: const TextStyle(
                  color: Color(0xFF3A2F06),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    widget.channel.canPost
                        ? 'Swipe a message to reply'
                        : 'Read only',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
      backgroundColor: pal.wall,
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
                ? Center(
                    child: Text(
                      'No messages yet.',
                      style: TextStyle(color: pal.soft),
                    ),
                  )
                : ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
                    itemCount: reversed.length,
                    itemBuilder: (context, i) => _row(reversed, i),
                  ),
          ),
          Container(
            decoration: BoxDecoration(
              color: pal.bar,
              border: Border(top: BorderSide(color: theme.dividerColor)),
            ),
            child: SafeArea(
              top: false,
              child: widget.channel.canPost
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_replyTo != null)
                          Container(
                            key: const Key('replyBar'),
                            margin: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                            padding: const EdgeInsets.fromLTRB(8, 6, 2, 6),
                            decoration: BoxDecoration(
                              color: pal.field,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: theme.dividerColor),
                            ),
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
                                  icon: const Icon(Icons.close, size: 20),
                                  onPressed: () =>
                                      setState(() => _replyTo = null),
                                ),
                              ],
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: pal.field,
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: theme.dividerColor,
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      IconButton(
                                        key: const Key('stickerButton'),
                                        tooltip: 'Stickers',
                                        color: pal.soft,
                                        onPressed: _sending
                                            ? null
                                            : _sendSticker,
                                        icon: const Icon(
                                          Icons.emoji_emotions_outlined,
                                        ),
                                      ),
                                      Expanded(
                                        child: TextField(
                                          key: const Key('chatText'),
                                          controller: _text,
                                          minLines: 1,
                                          maxLines: 4,
                                          textCapitalization:
                                              TextCapitalization.sentences,
                                          decoration: const InputDecoration(
                                            hintText: 'Write a message',
                                            border: InputBorder.none,
                                            enabledBorder: InputBorder.none,
                                            focusedBorder: InputBorder.none,
                                            filled: false,
                                            isDense: true,
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                  vertical: 12,
                                                ),
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        key: const Key('attachButton'),
                                        tooltip: 'Attach',
                                        color: pal.soft,
                                        onPressed: _sending ? null : _attach,
                                        icon: const Icon(Icons.attach_file),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 46,
                                height: 46,
                                child: IconButton.filled(
                                  tooltip: 'Send',
                                  onPressed: _sending ? null : _send,
                                  icon: const Icon(Icons.send, size: 20),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(
                        'Only the Founder and General Secretary post here.',
                        style: TextStyle(color: pal.soft),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
