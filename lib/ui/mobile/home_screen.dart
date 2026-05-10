import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/models.dart';
import '../shared/theme.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final history = context.watch<AppState>().history;

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
                      'No shares yet',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 15),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    itemCount: history.length,
                    itemBuilder: (context, index) {
                      return _buildShareCard(context, history[index]);
                    },
                  ),
          ),
          const SmartInputBar(),
        ],
      ),
    );
  }

  Widget _buildShareCard(BuildContext context, SharePayload payload) {
    final appState = context.read<AppState>();
    final isText = payload.type == FileTransferType.text;
    final sizeStr = isText ? '' : '${(payload.size / 1024 / 1024).toStringAsFixed(1)} MB';
    final showDownload = !isText && appState.isConnectedToHost; // only client can download

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.accentLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isText ? Icons.text_snippet : Icons.insert_drive_file,
              color: AppTheme.textMain,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isText ? (payload.data ?? 'Text Message') : payload.fileName,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  payload.senderName + (sizeStr.isNotEmpty ? ' • $sizeStr' : ''),
                  style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
          if (showDownload)
            IconButton(
              icon: const Icon(Icons.download, color: AppTheme.accentColor),
              onPressed: () {
                // For file downloads we need the host's IP; assume we are connected to a host.
                // In a future version you'd extract the host IP from the active connection.
                final hostIp = appState.localIp; // placeholder – will need real host IP
                appState.downloadLargeFile(
                  hostIp,
                  appState.hostPort,
                  payload.id,
                  payload.fileName,
                );
              },
            ),
        ],
      ),
    );
  }
}

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
          // Removed the "+" button for file attachments (text‑only MVP)
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                filled: true,
                fillColor: AppTheme.surfaceHover,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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