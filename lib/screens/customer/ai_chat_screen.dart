import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/config.dart';
import '../../core/theme.dart';

// ── Config ────────────────────────────────────────────────────────────────────
const _kApiKey = kGroqApiKey;
const _kModel       = 'llama-3.3-70b-versatile';                    // text-only
const _kVisionModel = 'meta-llama/llama-4-scout-17b-16e-instruct';  // vision
const _kSaveKey     = 'ai_chat_v1';

const _kSystem = '''
You are ServiceHive AI — a smart home-service assistant for Pakistan.

Your job:
1. Identify which professional the user needs (electrician, plumber, carpenter, AC technician, painter, cleaning, etc.).
2. Give IMMEDIATE safety steps for urgent issues:
   - Water leak → "Turn off the main water valve right now."
   - Electrical spark → "Switch off the main circuit breaker. Don't touch wires."
   - Gas smell → "Open all windows, leave the house, call 1199."
3. Explain what the professional will do when they arrive.
4. Share simple DIY tips for minor problems.
5. Give rough cost ranges in PKR.
When the user sends an image: analyse it carefully and give specific advice.
Be concise, friendly, use bullet points. Respond in same language as user (Urdu/English mix ok).
''';

const _kSuggestions = [
  '🚿  Water leak in bathroom',
  '⚡  No electricity in a room',
  '❄️  AC is not cooling',
  '🔧  Fan making noise',
  '🪟  Door/window not closing',
  '🧹  Deep cleaning needed',
];

// ── Model ─────────────────────────────────────────────────────────────────────
class _Msg {
  final String id;
  final String text;
  final bool isUser;
  final String? imgPath;
  final DateTime? time;
  final bool isLoading;

  const _Msg({
    required this.id,
    required this.text,
    required this.isUser,
    this.imgPath,
    this.time,
    this.isLoading = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'isUser': isUser,
        'time': time?.toIso8601String(),
      };

  factory _Msg.fromJson(Map<String, dynamic> j) => _Msg(
        id: j['id'] as String,
        text: j['text'] as String,
        isUser: j['isUser'] as bool,
        time: j['time'] != null ? DateTime.parse(j['time'] as String) : null,
      );
}

// ── Screen ────────────────────────────────────────────────────────────────────
class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen>
    with SingleTickerProviderStateMixin {
  final _input   = TextEditingController();
  final _scroll  = ScrollController();
  final _picker  = ImagePicker();
  final List<_Msg> _msgs = [];
  bool _sending    = false;
  XFile? _pendingImg;
  late final AnimationController _dots;

  static const _welcome = _Msg(
    id: 'welcome',
    text: 'Assalam o Alaikum! 👋 I\'m ServiceHive AI.\n\nDescribe your home problem — or send a photo — and I\'ll tell you:\n• Which professional to call\n• What to do right now\n• What the fix will involve',
    isUser: false,
  );

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _dots = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat();
    _loadMessages();
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    _dots.dispose();
    super.dispose();
  }

  // ── Persistence ────────────────────────────────────────────────────────────

  Future<void> _loadMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kSaveKey);
    if (raw != null) {
      try {
        final list = (jsonDecode(raw) as List)
            .map((e) => _Msg.fromJson(e as Map<String, dynamic>))
            .toList();
        setState(() {
          _msgs.clear();
          if (list.isEmpty) {
            _msgs.add(_welcome);
          } else {
            _msgs.addAll(list);
          }
        });
        _scrollEnd();
        return;
      } catch (_) {}
    }
    setState(() => _msgs.add(_welcome));
  }

  Future<void> _saveMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final saveable = _msgs.where((m) => !m.isLoading).toList();
    // keep last 60 messages
    final trimmed = saveable.length > 60
        ? saveable.sublist(saveable.length - 60)
        : saveable;
    await prefs.setString(_kSaveKey, jsonEncode(trimmed.map((m) => m.toJson()).toList()));
  }

  Future<void> _clearChat() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kSaveKey);
    setState(() {
      _msgs.clear();
      _msgs.add(_welcome);
    });
  }

  // ── Scroll ─────────────────────────────────────────────────────────────────

  void _scrollEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Image picker ───────────────────────────────────────────────────────────

  void _showImageOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // handle
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('Send an Image',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  )),
              const SizedBox(height: 6),
              Text('AI will analyse the photo and advise you.',
                  style: GoogleFonts.inter(
                    color: AppColors.textMuted, fontSize: 13)),
              const SizedBox(height: 20),
              _SheetOption(
                icon: Icons.camera_alt_rounded,
                color: const Color(0xFF8B5CF6),
                label: 'Take a Photo',
                sub: 'Open camera',
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              const SizedBox(height: 12),
              _SheetOption(
                icon: Icons.photo_library_rounded,
                color: const Color(0xFF3B82F6),
                label: 'Choose from Gallery',
                sub: 'Pick existing photo',
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final f = await _picker.pickImage(
        source: source, imageQuality: 55, maxWidth: 768, maxHeight: 768);
    if (f != null) setState(() => _pendingImg = f);
  }

  // ── Send ───────────────────────────────────────────────────────────────────

  Future<void> _send() async {
    final text = _input.text.trim();
    if ((text.isEmpty && _pendingImg == null) || _sending) return;

    final img = _pendingImg;
    final userMsg = _Msg(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      isUser: true,
      imgPath: img?.path,
      time: DateTime.now(),
    );
    const loading = _Msg(id: 'loading', text: '', isUser: false, isLoading: true);

    setState(() {
      _msgs.add(userMsg);
      _msgs.add(loading);
      _sending = true;
      _input.clear();
      _pendingImg = null;
    });
    _scrollEnd();

    try {
      final reply = await _callGroq(userMsg);
      if (!mounted) return;
      final aiMsg = _Msg(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: reply,
        isUser: false,
        time: DateTime.now(),
      );
      setState(() {
        _msgs.removeWhere((m) => m.isLoading);
        _msgs.add(aiMsg);
        _sending = false;
      });
      await _saveMessages();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _msgs.removeWhere((m) => m.isLoading);
        _msgs.add(_Msg(
          id: 'err_${DateTime.now().millisecondsSinceEpoch}',
          text: '⚠️ Error: $e\n\nPlease try again.',
          isUser: false,
          time: DateTime.now(),
        ));
        _sending = false;
      });
    }
    _scrollEnd();
  }

  // ── Groq API ───────────────────────────────────────────────────────────────

  Future<String> _callGroq(_Msg currentUserMsg) async {
    if (currentUserMsg.imgPath != null) {
      try {
        return await _visionCall(currentUserMsg);
      } catch (_) {
        // Fallback: text-only with note about image
        return await _textCall(
          fallbackNote: 'The user sent a photo of their home problem but image processing failed. '
              'Ask them to describe what they see so you can help.',
        );
      }
    }
    return await _textCall();
  }

  Future<String> _visionCall(_Msg userMsg) async {
    final bytes = await File(userMsg.imgPath!).readAsBytes();
    final b64   = base64Encode(bytes);
    final mime  = userMsg.imgPath!.toLowerCase().endsWith('.png')
        ? 'image/png'
        : 'image/jpeg';
    final txt = userMsg.text.isNotEmpty
        ? userMsg.text
        : 'Analyse this image carefully. What is the problem? Which professional do I need and what should I do right now?';

    final res = await http
        .post(
          Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
          headers: {
            'content-type': 'application/json',
            'Authorization': 'Bearer $_kApiKey',
          },
          body: jsonEncode({
            'model': _kVisionModel,
            'messages': [
              {'role': 'system', 'content': _kSystem},
              {
                'role': 'user',
                'content': [
                  {'type': 'text', 'text': txt},
                  {
                    'type': 'image_url',
                    'image_url': {'url': 'data:$mime;base64,$b64'},
                  },
                ],
              },
            ],
            'max_tokens': 1024,
            'temperature': 0.7,
          }),
        )
        .timeout(const Duration(seconds: 45));

    if (res.statusCode == 200) {
      return jsonDecode(res.body)['choices'][0]['message']['content'] as String;
    }
    throw Exception('HTTP ${res.statusCode}: ${res.body}');
  }

  Future<String> _textCall({String? fallbackNote}) async {
    final messages = <Map<String, dynamic>>[
      {'role': 'system', 'content': _kSystem},
    ];

    for (final m in _msgs) {
      if (m.isLoading) continue;
      if (m.id == 'welcome') continue;
      if (m.isUser) {
        String txt = m.text;
        if (m.imgPath != null && txt.isEmpty) txt = '[User sent a photo of their problem]';
        if (m.imgPath != null && txt.isNotEmpty) txt = '[Photo] $txt';
        if (txt.isNotEmpty) messages.add({'role': 'user', 'content': txt});
      } else if (m.text.isNotEmpty) {
        messages.add({'role': 'assistant', 'content': m.text});
      }
    }

    if (fallbackNote != null) messages.add({'role': 'user', 'content': fallbackNote});

    final res = await http
        .post(
          Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
          headers: {
            'content-type': 'application/json',
            'Authorization': 'Bearer $_kApiKey',
          },
          body: jsonEncode({
            'model': _kModel,
            'messages': messages,
            'max_tokens': 1024,
            'temperature': 0.7,
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (res.statusCode == 200) {
      return jsonDecode(res.body)['choices'][0]['message']['content'] as String;
    }
    throw Exception('HTTP ${res.statusCode}: ${res.body}');
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: _appBar(),
      body: Column(
        children: [
          Expanded(child: _messageList()),
          if (_pendingImg != null) _imagePreview(),
          _inputBar(),
        ],
      ),
    );
  }

  // ── AppBar ─────────────────────────────────────────────────────────────────

  PreferredSizeWidget _appBar() => AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 38, height: 38,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFF3B82F6)]),
              ),
              child: const Icon(Icons.auto_awesome,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ServiceHive AI',
                      style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  Row(children: [
                    Container(
                      width: 6, height: 6,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.success),
                    ),
                    Flexible(
                      child: Text('Online · ServiceHive AI',
                          style: GoogleFonts.inter(
                              color: AppColors.textMuted, fontSize: 10),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ]),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                color: AppColors.textDim, size: 22),
            tooltip: 'Clear chat',
            onPressed: () => showDialog(
              context: context,
              builder: (_) => AlertDialog(
                backgroundColor: AppColors.surface2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                title: Text('Clear Chat?',
                    style: GoogleFonts.inter(
                        color: Colors.white, fontWeight: FontWeight.w700)),
                content: Text('All messages will be deleted.',
                    style: GoogleFonts.inter(color: AppColors.textMuted)),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancel',
                          style: GoogleFonts.inter(
                              color: AppColors.textMuted))),
                  TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _clearChat();
                      },
                      child: Text('Clear',
                          style: GoogleFonts.inter(
                              color: AppColors.error,
                              fontWeight: FontWeight.w700))),
                ],
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      );

  // ── Message list ───────────────────────────────────────────────────────────

  Widget _messageList() {
    final showSuggestions = _msgs.length == 1 && !_sending;
    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      children: [
        ..._msgs.map((m) => _Bubble(msg: m, dots: _dots,
          onCopy: m.text.isNotEmpty
              ? () {
                  Clipboard.setData(ClipboardData(text: m.text));
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Copied!',
                        style: GoogleFonts.inter(color: Colors.white)),
                    backgroundColor: AppColors.surface2,
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 1),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ));
                }
              : null,
        )),
        if (showSuggestions) _suggestions(),
      ],
    );
  }

  Widget _suggestions() => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Quick start',
                style: GoogleFonts.inter(
                    color: AppColors.textDim,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: _kSuggestions.map((s) => GestureDetector(
                onTap: () {
                  _input.text = s.substring(2).trim();
                  _send();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                        color: const Color(0xFF8B5CF6).withOpacity(0.3)),
                  ),
                  child: Text(s,
                      style: GoogleFonts.inter(
                          color: AppColors.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w500)),
                ),
              )).toList(),
            ),
          ],
        ),
      );

  // ── Image preview ──────────────────────────────────────────────────────────

  Widget _imagePreview() => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: const Color(0xFF8B5CF6).withOpacity(0.4)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.file(File(_pendingImg!.path),
                  width: 56, height: 56, fit: BoxFit.cover),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Photo ready to send',
                      style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text('Add a message or tap send',
                      style: GoogleFonts.inter(
                          color: AppColors.textMuted, fontSize: 11)),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => _pendingImg = null),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.surface3,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.close_rounded,
                    color: AppColors.textMuted, size: 16),
              ),
            ),
          ],
        ),
      );

  // ── Input bar ──────────────────────────────────────────────────────────────

  Widget _inputBar() => Container(
        padding: EdgeInsets.fromLTRB(
            12, 10, 12, MediaQuery.of(context).padding.bottom + 10),
        decoration: const BoxDecoration(
          color: AppColors.bg,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // "+" button
            GestureDetector(
              onTap: _sending ? null : _showImageOptions,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 42, height: 42,
                decoration: BoxDecoration(
                  gradient: _sending
                      ? null
                      : const LinearGradient(
                          colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)]),
                  color: _sending ? AppColors.surface2 : null,
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: _sending
                      ? null
                      : [
                          BoxShadow(
                            color: const Color(0xFF8B5CF6).withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          )
                        ],
                ),
                child: Icon(Icons.add_rounded,
                    color: _sending
                        ? AppColors.textDim
                        : Colors.white,
                    size: 22),
              ),
            ),
            const SizedBox(width: 8),
            // Text field
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppColors.border),
                ),
                child: TextField(
                  controller: _input,
                  enabled: !_sending,
                  maxLines: 4,
                  minLines: 1,
                  style: GoogleFonts.inter(
                      color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Describe your problem…',
                    hintStyle: GoogleFonts.inter(
                        color: AppColors.textDim, fontSize: 14),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Send button
            GestureDetector(
              onTap: _sending ? null : _send,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 42, height: 42,
                decoration: BoxDecoration(
                  gradient: _sending
                      ? null
                      : const LinearGradient(
                          colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)]),
                  color: _sending ? AppColors.surface2 : null,
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: _sending
                      ? null
                      : [
                          BoxShadow(
                            color: const Color(0xFF3B82F6).withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          )
                        ],
                ),
                child: _sending
                    ? const Padding(
                        padding: EdgeInsets.all(11),
                        child: CircularProgressIndicator(
                            color: Color(0xFF8B5CF6), strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded,
                        color: Colors.white, size: 18),
              ),
            ),
          ],
        ),
      );
}

// ── Message bubble ────────────────────────────────────────────────────────────

class _Bubble extends StatelessWidget {
  final _Msg msg;
  final AnimationController dots;
  final VoidCallback? onCopy;

  const _Bubble({
    required this.msg,
    required this.dots,
    this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    if (msg.isLoading) return _typingIndicator();
    final isUser = msg.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[_aiAvatar(), const SizedBox(width: 8)],
          Flexible(
            child: GestureDetector(
              onLongPress: onCopy,
              child: Column(
                crossAxisAlignment: isUser
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(
                        maxWidth:
                            MediaQuery.of(context).size.width * 0.75),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: isUser
                            ? const LinearGradient(
                                colors: [
                                  Color(0xFF6D28D9),
                                  Color(0xFF2563EB)
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        color: isUser ? null : AppColors.surface2,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(18),
                          topRight: const Radius.circular(18),
                          bottomLeft:
                              Radius.circular(isUser ? 18 : 4),
                          bottomRight:
                              Radius.circular(isUser ? 4 : 18),
                        ),
                        border: isUser
                            ? null
                            : Border.all(color: AppColors.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          if (msg.imgPath != null) ...[
                            ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(10),
                              child: Image.file(
                                File(msg.imgPath!),
                                fit: BoxFit.cover,
                                width: double.infinity,
                                errorBuilder: (_, __, ___) =>
                                    Container(
                                  height: 80,
                                  color: AppColors.surface3,
                                  child: const Center(
                                    child: Icon(
                                        Icons.image_not_supported_outlined,
                                        color: AppColors.textDim),
                                  ),
                                ),
                              ),
                            ),
                            if (msg.text.isNotEmpty)
                              const SizedBox(height: 8),
                          ],
                          if (msg.text.isNotEmpty)
                            Text(
                              msg.text,
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 14,
                                height: 1.55,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  // Timestamp
                  if (msg.time != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
                      child: Text(
                        _formatTime(msg.time!),
                        style: GoogleFonts.inter(
                          color: AppColors.textDim,
                          fontSize: 10,
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

  Widget _aiAvatar() => Container(
        width: 30, height: 30,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
              colors: [Color(0xFF8B5CF6), Color(0xFF3B82F6)]),
        ),
        child: const Icon(Icons.auto_awesome,
            color: Colors.white, size: 15),
      );

  Widget _typingIndicator() => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          children: [
            _aiAvatar(),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 18, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(4),
                  bottomRight: Radius.circular(18),
                ),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: AnimatedBuilder(
                animation: dots,
                builder: (_, __) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (i) {
                    final t = (dots.value - i * 0.25) % 1.0;
                    final opacity =
                        (t < 0.5 ? t * 2 : (1.0 - t) * 2)
                            .clamp(0.25, 1.0);
                    return Padding(
                      padding:
                          EdgeInsets.only(right: i < 2 ? 5.0 : 0),
                      child: Opacity(
                        opacity: opacity,
                        child: Container(
                          width: 7, height: 7,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF8B5CF6),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      );

  String _formatTime(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

// ── Bottom sheet option ───────────────────────────────────────────────────────

class _SheetOption extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String sub;
  final VoidCallback onTap;

  const _SheetOption({
    required this.icon,
    required this.color,
    required this.label,
    required this.sub,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.07),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  Text(sub,
                      style: GoogleFonts.inter(
                          color: AppColors.textMuted, fontSize: 12)),
                ],
              ),
              const Spacer(),
              Icon(Icons.arrow_forward_ios_rounded,
                  color: color.withOpacity(0.5), size: 14),
            ],
          ),
        ),
      );
}
