import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/message_model.dart';
import '../ipl_pdf_content.dart';
import '../services/audio_service.dart';
import '../services/database_service.dart';
import '../services/openai_service.dart';
import '../services/pdf_service.dart';
import '../services/tts_service.dart';
import '../widgets/chat_bubble.dart';
import 'api_key_screen.dart';

class ChatScreen extends StatefulWidget {
  final String apiKey;

  const ChatScreen({super.key, required this.apiKey});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _db = DatabaseService();
  final _openAI = OpenAIService();
  final _pdfService = PdfService();
  final _audioService = AudioService();
  final _ttsService = TtsService();

  List<MessageModel> _messages = [];
  bool _isSending = false;
  bool _isRecording = false;
  bool _ttsEnabled = true; // voice output on by default

  // PDF context
  String? _pdfName;
  String? _pdfSystemPrompt;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _autoLoadIplPdf();
  }

  /// Loads the IPL PDF content that is bundled directly in the app at build time.
  /// No device file system access needed.
  void _autoLoadIplPdf() {
    final prompt = _pdfService.buildSystemPrompt(kIplPdfText, kIplPdfName);
    setState(() {
      _pdfName = kIplPdfName;
      _pdfSystemPrompt = prompt;
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _audioService.dispose();
    _ttsService.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    final messages = await _db.loadMessages();
    setState(() => _messages = messages);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ─── Send Text Message ────────────────────────────────────────────────────

  Future<void> _sendText() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isSending) return;
    _textController.clear();
    await _sendMessage(text, isAudio: false);
  }

  // ─── Audio Recording ──────────────────────────────────────────────────────

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    final hasPermission = await _audioService.hasMicrophonePermission();
    if (!hasPermission) {
      _showSnackBar('Microphone permission is required for voice input.');
      return;
    }
    try {
      await _audioService.startRecording();
      setState(() => _isRecording = true);
    } catch (e) {
      _showSnackBar('Failed to start recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioService.stopRecording();
      setState(() => _isRecording = false);
      if (path == null) {
        _showSnackBar('Recording failed. Please try again.');
        return;
      }
      setState(() => _isSending = true);
      String transcription;
      try {
        transcription = await _openAI.transcribeAudio(
          apiKey: widget.apiKey,
          audioFilePath: path,
        );
      } catch (e) {
        _showSnackBar('Transcription error: $e');
        setState(() => _isSending = false);
        return;
      } finally {
        setState(() => _isSending = false);
      }
      if (transcription.isEmpty) {
        _showSnackBar('No speech detected. Please try again.');
        return;
      }
      await _sendMessage(transcription, isAudio: true);
    } catch (e) {
      setState(() => _isRecording = false);
      _showSnackBar('Recording error: $e');
    }
  }

  // ─── Core send + reply ────────────────────────────────────────────────────

  Future<void> _sendMessage(String content, {required bool isAudio}) async {
    final userMsg = MessageModel(
      role: 'user',
      content: content,
      timestamp: DateTime.now(),
      isAudio: isAudio,
    );
    final id = await _db.insertMessage(userMsg);
    final savedUser = MessageModel(
      id: id,
      role: userMsg.role,
      content: userMsg.content,
      timestamp: userMsg.timestamp,
      isAudio: isAudio,
    );
    setState(() {
      _messages.add(savedUser);
      _isSending = true;
    });
    _scrollToBottom();

    try {
      final history = _messages
          .where((m) => m.role == 'user' || m.role == 'assistant')
          .map((m) => m.toOpenAI())
          .toList();

      final reply = await _openAI.sendChatMessage(
        apiKey: widget.apiKey,
        messages: history,
        systemPrompt: _pdfSystemPrompt,
      );

      final assistantMsg = MessageModel(
        role: 'assistant',
        content: reply,
        timestamp: DateTime.now(),
      );
      final aId = await _db.insertMessage(assistantMsg);
      final savedAssistant = MessageModel(
        id: aId,
        role: assistantMsg.role,
        content: assistantMsg.content,
        timestamp: assistantMsg.timestamp,
      );
      setState(() => _messages.add(savedAssistant));
      _scrollToBottom();
      if (_ttsEnabled) {
        await _ttsService.speak(reply);
      }
    } catch (e) {
      _showSnackBar('Error: $e');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  // ─── PDF Picker ───────────────────────────────────────────────────────────

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result == null || result.files.single.path == null) return;

    final path = result.files.single.path!;
    final name = result.files.single.name;

    setState(() => _isSending = true);

    try {
      final text = await _pdfService.extractText(path);
      final prompt = _pdfService.buildSystemPrompt(text, name);
      setState(() {
        _pdfName = name;
        _pdfSystemPrompt = prompt;
      });
      _showSnackBar('PDF loaded: $name. Responses will be scoped to this document.');
    } catch (e) {
      _showSnackBar('Failed to load PDF: $e');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _clearPdf() {
    setState(() {
      _pdfName = null;
      _pdfSystemPrompt = null;
    });
    _showSnackBar('PDF scope removed. Responding from general knowledge.');
  }

  // ─── Clear chat ───────────────────────────────────────────────────────────

  Future<void> _confirmClear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Chat History'),
        content: const Text(
          'This will delete all messages. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade700,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _db.clearMessages();
      setState(() => _messages.clear());
    }
  }

  // ─── Change / Remove API Key ──────────────────────────────────────────────

  Future<void> _changeApiKey() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change API Key'),
        content: const Text('You will be taken back to the key entry screen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Change'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _db.deleteSetting('openai_api_key');
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ApiKeyScreen()),
      );
    }
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 3)),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Chat'),
        centerTitle: false,
        actions: [
          // Voice output (TTS) toggle
          IconButton(
            tooltip: _ttsEnabled ? 'Voice output ON' : 'Voice output OFF',
            icon: Icon(
              _ttsEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
            ),
            onPressed: () {
              setState(() => _ttsEnabled = !_ttsEnabled);
              if (!_ttsEnabled) _ttsService.stop();
            },
          ),
          // PDF scope button
          IconButton(
            tooltip: _pdfName == null ? 'Load PDF scope' : 'PDF: $_pdfName',
            icon: Badge(
              isLabelVisible: _pdfName != null,
              label: const Text('1'),
              child: const Icon(Icons.picture_as_pdf_outlined),
            ),
            onPressed: _pickPdf,
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'clear') _confirmClear();
              if (v == 'change_key') _changeApiKey();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'clear', child: Text('Clear chat')),
              const PopupMenuItem(
                value: 'change_key',
                child: Text('Change API key'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // PDF scope banner
          if (_pdfName != null)
            Container(
              width: double.infinity,
              color: theme.colorScheme.tertiaryContainer,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.picture_as_pdf,
                    size: 16,
                    color: theme.colorScheme.onTertiaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Scoped to: $_pdfName',
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onTertiaryContainer,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      Icons.close,
                      size: 16,
                      color: theme.colorScheme.onTertiaryContainer,
                    ),
                    onPressed: _clearPdf,
                    tooltip: 'Remove PDF scope',
                  ),
                ],
              ),
            ),

          // Message list
          Expanded(
            child: _messages.isEmpty
                ? _buildEmptyState(theme)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 4,
                    ),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) => ChatBubble(message: _messages[i]),
                  ),
          ),

          // Typing indicator
          if (_isSending)
            Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isRecording ? 'Transcribing…' : 'Thinking…',
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),

          // Input bar
          _buildInputBar(theme),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.chat_bubble_outline_rounded,
            size: 56,
            color: theme.colorScheme.outlineVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'Start a conversation',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Type or speak your first message.\nLoad a PDF to restrict answers to that document.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outlineVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(ThemeData theme) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
            top: BorderSide(color: theme.colorScheme.outlineVariant, width: 0.5),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Mic button
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: _isRecording
                    ? Colors.red.shade100
                    : theme.colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(
                  _isRecording ? Icons.stop_rounded : Icons.mic_outlined,
                  color: _isRecording
                      ? Colors.red.shade700
                      : theme.colorScheme.onPrimaryContainer,
                ),
                tooltip: _isRecording ? 'Stop recording' : 'Voice input',
                onPressed: _isSending ? null : _toggleRecording,
              ),
            ),
            const SizedBox(width: 8),

            // Text field
            Expanded(
              child: TextField(
                controller: _textController,
                minLines: 1,
                maxLines: 5,
                enabled: !_isRecording,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: _isRecording
                      ? 'Recording… tap stop when done'
                      : 'Type a message…',
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerLow,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (_) => _sendText(),
              ),
            ),
            const SizedBox(width: 8),

            // Send button
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.send_rounded),
                color: theme.colorScheme.onPrimary,
                tooltip: 'Send',
                onPressed: (_isSending || _isRecording) ? null : _sendText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
