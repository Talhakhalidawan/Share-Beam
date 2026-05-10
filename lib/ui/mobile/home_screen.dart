import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';

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
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              itemCount: history.length,
              itemBuilder: (context, index) {
                final payload = history[index];
                return _buildShareCard(context, payload);
              },
            ),
          ),
          const SmartInputBar(),
        ],
      ),
    );
  }

  Widget _buildShareCard(BuildContext context, SharePayload payload) {
    final isText = payload.type == FileTransferType.text;
    final sizeStr = isText ? '' : '${(payload.size / 1024 / 1024).toStringAsFixed(1)} MB';
    
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
                ),
                const SizedBox(height: 4),
                Text(
                  '${payload.senderName}' + (sizeStr.isNotEmpty ? ' • $sizeStr' : ''),
                  style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                )
              ],
            ),
          ),
          if (!isText && payload.senderName != Platform.localHostname) // Minimal assumption for downloading
             IconButton(
               icon: const Icon(Icons.download),
               onPressed: () {
                 final hostIp = context.read<AppState>().localIp;
                 // Ideally extract from connection if acting strictly client
                 // P2P requires host's IP from the signaling, using dummy for now 
                 context.read<AppState>().downloadLargeFile('127.0.0.1', 8080, payload.id, payload.fileName);
               },
             )
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

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                 leading: const Icon(Icons.image),
                 title: const Text('Gallery'),
                 onTap: () async {
                   Navigator.pop(context);
                   _pickFile(FileType.image);
                 },
              ),
              ListTile(
                 leading: const Icon(Icons.folder),
                 title: const Text('Files'),
                 onTap: () async {
                   Navigator.pop(context);
                   _pickFile(FileType.any);
                 },
              )
            ],
          ),
        );
      }
    );
  }
  
  Future<void> _pickFile(FileType type) async {
     FilePickerResult? result = await FilePicker.platform.pickFiles(type: type);
     if (result != null && result.files.single.path != null) {
       File file = File(result.files.single.path!);
       context.read<AppState>().shareFile(file);
     }
  }

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
          IconButton(
            icon: const Icon(Icons.add_circle, color: AppTheme.accentColor, size: 28),
            onPressed: _showAttachmentOptions,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'Type text to share...',
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
