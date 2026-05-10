import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../core/app_state.dart';
import '../../core/models.dart';
import '../shared/theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final history = appState.history;

    // Auto-scroll after each rebuild (new message)
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    return Scaffold(
      appBar: AppBar(
        title: const Text('ShareBeam'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: history.isEmpty
                ? const Center(
                    child: Text(
                      'No messages yet',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 15),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: history.length,
                    itemBuilder: (context, index) {
                      return _buildMessageBubble(context, history[index], index);
                    },
                  ),
          ),
          const SmartInputBar(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(BuildContext context, SharePayload payload, int index) {
    final appState = context.read<AppState>();
    final history = appState.history;
    final isMe = payload.senderName == appState.deviceName;
    final timeString = DateFormat('HH:mm').format(payload.timestamp);

    // Show sender name only for received messages, and only if different from previous sender
    final showSenderName = !isMe &&
        (index == 0 || history[index - 1].senderName != payload.senderName);

    final alignment = isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    // Sent bubble – light green (#DCF8C6), received – white (surface)
    final bubbleColor = isMe ? const Color(0xFFDCF8C6) : AppTheme.surfaceColor;
    final textColor = isMe ? AppTheme.textMain : AppTheme.textMain; // both dark text
    final timeCopyColor = isMe
        ? AppTheme.textMuted.withOpacity(0.8)
        : AppTheme.textMuted.withOpacity(0.7);

    final borderRadius = isMe
        ? const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(4),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
          );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          // Sender name (only for received, first in sequence)
          if (showSenderName)
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 4),
              child: Text(
                payload.senderName,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textMuted,
                ),
              ),
            ),
          // Bubble row
          Row(
            mainAxisAlignment:
                isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (isMe) const Spacer(),
              // Wider bubble with small margin from edge
              Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.85,
                ),
                margin: const EdgeInsets.symmetric(horizontal: 8), // keeps bubble away from screen edge
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: borderRadius,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Message text
                    SelectableText(
                      payload.data ?? '',
                      style: TextStyle(fontSize: 15, color: textColor),
                    ),
                    const SizedBox(height: 4),
                    // Time + copy (right aligned)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          timeString,
                          style: TextStyle(fontSize: 11, color: timeCopyColor),
                        ),
                        if (!isMe) ...[
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              Clipboard.setData(
                                ClipboardData(text: payload.data ?? ''),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Text copied'),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            },
                            child: Icon(
                              Icons.copy,
                              size: 14,
                              color: timeCopyColor,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (!isMe) const Spacer(),
            ],
          ),
        ],
      ),
    );
  }
}

// ---- Smart Input Bar (unchanged) ----
class SmartInputBar extends StatefulWidget {
  const SmartInputBar({Key? key}) : super(key: key);

  @override
  State<SmartInputBar> createState() => _SmartInputBarState();
}

class _SmartInputBarState extends State<SmartInputBar> {
  final TextEditingController _controller = TextEditingController();

  void _sendText() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      context.read<AppState>().shareText(text);
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 32),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceColor,
        border: Border(top: BorderSide(color: AppTheme.borderColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                filled: true,
                fillColor: AppTheme.surfaceHover,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: AppTheme.borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: AppTheme.borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: AppTheme.accentColor),
                ),
              ),
              onSubmitted: (_) => _sendText(),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: AppTheme.accentColor,
            radius: 20,
            child: IconButton(
              icon: const Icon(Icons.arrow_upward, color: Colors.white, size: 20),
              onPressed: _sendText,
            ),
          ),
        ],
      ),
    );
  }
}