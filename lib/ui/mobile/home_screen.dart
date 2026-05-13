import 'dart:io' as io;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_selector/file_selector.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/app_state.dart';
import '../../core/models.dart';
import '../../core/user_color.dart';
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

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        backgroundColor: AppTheme.bgColor,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ShareBeam',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textMain,
              ),
            ),
            if (appState.isHosting)
              Text(
                'Hosting • ${appState.participants.length} connected',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.textMuted,
                ),
              )
            else if (appState.isConnectedToHost)
              Text(
                'Connected to ${appState.connectedHostIp}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.textMuted,
                ),
              )
            else
              const Text(
                'Not connected',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.accentRed,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: AppTheme.accentColor),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildChatBody(appState, history)),
          _buildInputArea(appState),
        ],
      ),
    );
  }

  Widget _buildChatBody(AppState appState, List<SharePayload> history) {
    if (history.isEmpty) {
      if (!appState.isConnectedToHost && !appState.isHosting) {
        return _buildEmptyState();
      }
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 48,
              color: AppTheme.borderColor,
            ),
            const SizedBox(height: 16),
            const Text(
              'No messages yet',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      itemCount: history.length,
      itemBuilder: (context, index) {
        return _buildMessageBubble(context, history[index], index);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.accentLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.wifi_tethering,
                size: 48,
                color: AppTheme.accentColor,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'ShareBeam',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppTheme.textMain,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Connect to a host or start hosting to share files and messages across your local network.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: AppTheme.textMuted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/settings'),
              icon: const Icon(Icons.settings),
              label: const Text('Open Settings'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentColor,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(
      BuildContext context, SharePayload payload, int index) {
    final appState = context.read<AppState>();
    final history = appState.history;
    final isMe = payload.senderName == appState.deviceName;

    final showSender = !isMe &&
        (index == 0 || history[index - 1].senderName != payload.senderName);

    final alignment =
        isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    final bubbleColor =
        isMe ? const Color(0xFFDCF8C6) : AppTheme.surfaceColor;

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
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          Row(
            mainAxisAlignment:
                isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (isMe) const Spacer(),
              Flexible(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.78,
                  ),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: borderRadius,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: _buildPayloadContent(
                      context, payload, appState, showSender, isMe),
                ),
              ),
              if (!isMe) const Spacer(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPayloadContent(BuildContext context, SharePayload payload,
      AppState appState, bool showSender, bool isMe) {
    switch (payload.type) {
      case FileTransferType.text:
        return _buildTextContent(payload, showSender, isMe);
      case FileTransferType.image:
        return _buildImageContent(context, payload, appState, showSender, isMe);
      case FileTransferType.file:
        return _buildFileContent(context, payload, appState, showSender, isMe);
      case FileTransferType.announcement:
        return Padding(
          padding: const EdgeInsets.all(12),
          child: Center(
            child: Text(
              payload.data ?? '',
              style: const TextStyle(
                fontStyle: FontStyle.italic,
                color: AppTheme.textMuted,
                fontSize: 13,
              ),
            ),
          ),
        );
    }
  }

  Widget _buildTextContent(SharePayload payload, bool showSender, bool isMe) {
    final time = DateFormat('HH:mm').format(payload.timestamp);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showSender)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
            child: Text(
              payload.senderName,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: UserColorGenerator.forName(payload.senderName),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
          child: SelectableText(
            payload.data ?? '',
            style: const TextStyle(fontSize: 15, color: AppTheme.textMain),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 2, 12, 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (!isMe) ...[
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(
                        ClipboardData(text: payload.data ?? ''));
                    _showCopiedSnack();
                  },
                  child: Icon(
                    Icons.copy,
                    size: 14,
                    color: AppTheme.textMuted.withOpacity(0.7),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                time,
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textMuted.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImageContent(BuildContext context, SharePayload payload,
      AppState appState, bool showSender, bool isMe) {
    final time = DateFormat('HH:mm').format(payload.timestamp);
    final localPath = appState.downloadedFilePaths[payload.id];
    final isDownloaded =
        localPath != null && io.File(localPath).existsSync();
    final progress = appState.downloadsProgress[payload.id];
    final isDownloading = progress != null && progress < 1.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showSender)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
            child: Text(
              payload.senderName,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: UserColorGenerator.forName(payload.senderName),
              ),
            ),
          ),
        GestureDetector(
          onTap: isDownloaded
              ? () => _openFullScreenImage(context, localPath!)
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: isDownloaded
                  ? Image.file(
                      io.File(localPath),
                      width: 240,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _buildImagePlaceholder(payload, appState, isDownloading, progress),
                    )
                  : _buildImagePlaceholder(payload, appState, isDownloading, progress),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
          child: Row(
            children: [
              Text(
                time,
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textMuted.withOpacity(0.8),
                ),
              ),
              const Spacer(),
              if (isDownloaded && !isMe) ...[
                GestureDetector(
                  onTap: () => _copyImageToClipboard(payload, appState),
                  child: Icon(
                    Icons.copy,
                    size: 16,
                    color: AppTheme.textMuted.withOpacity(0.7),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => _saveImageToLocalStorage(localPath!),
                  child: Icon(
                    Icons.save_alt,
                    size: 16,
                    color: AppTheme.accentColor,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImagePlaceholder(SharePayload payload, AppState appState,
      bool isDownloading, double? progress) {
    return Container(
      width: 240,
      height: 140,
      color: AppTheme.accentLight,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.image_outlined,
              size: 36, color: AppTheme.textMuted),
          const SizedBox(height: 6),
          Text(
            payload.fileName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: AppTheme.textMain),
          ),
          const SizedBox(height: 2),
          Text(
            _formatBytes(payload.size),
            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
          ),
          if (isDownloading) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: AppTheme.borderColor,
                  minHeight: 3,
                ),
              ),
            ),
          ] else if (payload.senderName != appState.deviceName) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _downloadImage(payload, appState),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.accentColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.download, color: Colors.white, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'Download',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFileContent(BuildContext context, SharePayload payload,
      AppState appState, bool showSender, bool isMe) {
    final time = DateFormat('HH:mm').format(payload.timestamp);
    final localPath = appState.downloadedFilePaths[payload.id];
    final isDownloaded =
        localPath != null && io.File(localPath).existsSync();
    final progress = appState.downloadsProgress[payload.id];
    final isDownloading = progress != null && progress < 1.0;

    return Container(
      width: 260,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showSender)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                payload.senderName,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: UserColorGenerator.forName(payload.senderName),
                ),
              ),
            ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.accentColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isDownloaded ? Icons.file_present : Icons.insert_drive_file,
                  color: AppTheme.accentColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      payload.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatBytes(payload.size),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (isDownloading) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: AppTheme.borderColor,
                minHeight: 3,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                time,
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textMuted.withOpacity(0.8),
                ),
              ),
              const Spacer(),
              if (!isMe && !isDownloaded)
                GestureDetector(
                  onTap: () => _downloadFile(payload, appState),
                  child: Icon(
                    Icons.download,
                    size: 16,
                    color: AppTheme.accentColor,
                  ),
                ),
              if (isDownloaded)
                GestureDetector(
                  onTap: () => _saveFileToLocalStorage(localPath!, payload.fileName),
                  child: Icon(
                    Icons.save_alt,
                    size: 16,
                    color: AppTheme.accentColor,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _openFullScreenImage(BuildContext context, String imagePath) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.file(
                io.File(imagePath),
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _copyImageToClipboard(SharePayload payload, AppState appState) async {
    try {
      String? path = appState.downloadedFilePaths[payload.id];
      
      if (path == null || !io.File(path).existsSync()) {
        await appState.downloadPayload(payload);
        path = appState.downloadedFilePaths[payload.id];
      }
      
      if (path != null && io.File(path).existsSync()) {
        final bytes = await io.File(path).readAsBytes();
        await Pasteboard.writeImage(bytes);
        if (mounted) _showCopiedSnack();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to copy: $e')),
        );
      }
    }
  }

  Future<void> _downloadImage(SharePayload payload, AppState appState) async {
    try {
      await appState.downloadPayload(payload);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
      }
    }
  }

  Future<void> _downloadFile(SharePayload payload, AppState appState) async {
    try {
      await appState.downloadPayload(payload);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
      }
    }
  }

  Future<void> _saveImageToLocalStorage(String imagePath) async {
    try {
      final file = io.File(imagePath);
      if (!await file.exists()) return;

      if (io.Platform.isAndroid || io.Platform.isIOS) {
        final hasAccess = await Gal.hasAccess();
        if (!hasAccess) {
          await Gal.requestAccess();
        }
        await Gal.putImage(imagePath);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Saved to Gallery')),
          );
        }
        return;
      }

      // Rest of the logic for Desktop
      final bytes = await file.readAsBytes();
      
      io.Directory? saveDir;
      final home = io.Platform.environment['HOME'] ?? 
                   io.Platform.environment['USERPROFILE'];
      if (home != null) {
        saveDir = io.Directory('$home/Downloads');
        if (!await saveDir.exists()) {
          saveDir = io.Directory('$home/Documents');
        }
      }

      if (saveDir == null) {
        throw Exception('Could not determine save location');
      }

      if (!await saveDir.exists()) {
        await saveDir.create(recursive: true);
      }

      final fileName = 'sharebeam_${DateTime.now().millisecondsSinceEpoch}.png';
      final savePath = '${saveDir.path}/$fileName';
      await file.copy(savePath);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved to $savePath')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    }
  }

  Future<void> _saveFileToLocalStorage(String filePath, String originalName) async {
    try {
      final file = io.File(filePath);
      if (!await file.exists()) return;

      if (io.Platform.isAndroid || io.Platform.isIOS) {
        // Use share_plus to allow user to save the file
        // This is more reliable than manually copying to Downloads on modern mobile OS
        await Share.shareXFiles([XFile(filePath, name: originalName)]);
        return;
      }

      io.Directory? saveDir;
      final home = io.Platform.environment['HOME'] ?? 
                   io.Platform.environment['USERPROFILE'];
      if (home != null) {
        saveDir = io.Directory('$home/Downloads');
        if (!await saveDir.exists()) {
          saveDir = io.Directory('$home/Documents');
        }
      }

      if (saveDir == null) {
        throw Exception('Could not determine save location');
      }

      if (!await saveDir.exists()) {
        await saveDir.create(recursive: true);
      }

      final savePath = '${saveDir.path}/$originalName';
      await file.copy(savePath);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved to $savePath')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    }
  }

  void _showCopiedSnack() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  Widget _buildInputArea(AppState appState) {
    final isConnected = appState.isConnectedToHost || appState.isHosting;

    if (!isConnected && appState.history.isEmpty) {
      return const SizedBox.shrink();
    }

    if (!isConnected && appState.history.isNotEmpty) {
      return _buildDisconnectWarning();
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        border: Border(top: BorderSide(color: AppTheme.borderColor)),
      ),
      child: SafeArea(
        child: SmartInputBar(enabled: isConnected),
      ),
    );
  }

  Widget _buildDisconnectWarning() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE5E5),
        border: Border(top: BorderSide(color: AppTheme.accentRed)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            const Icon(Icons.wifi_off, color: AppTheme.accentRed, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'You\'re not connected',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.accentRed,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    'Messages can\'t be sent until you reconnect.',
                    style: TextStyle(
                      color: AppTheme.accentRed.withOpacity(0.8),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/settings'),
              child: const Text(
                'Settings',
                style: TextStyle(
                  color: AppTheme.accentRed,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Smart Input Bar - WhatsApp Style
// ─────────────────────────────────────────────────────────────────────────────
class SmartInputBar extends StatefulWidget {
  final bool enabled;
  const SmartInputBar({Key? key, required this.enabled}) : super(key: key);

  @override
  State<SmartInputBar> createState() => _SmartInputBarState();
}

class _SmartInputBarState extends State<SmartInputBar> {
  final TextEditingController _controller = TextEditingController();
  Uint8List? _pendingImageBytes;
  String? _pendingImageName;
  Future<bool> _handlePaste() async {
    try {
      final bytes = await Pasteboard.image;
      if (bytes != null && bytes.isNotEmpty && _pendingImageBytes == null) {
        setState(() {
          _pendingImageBytes = bytes;
          _pendingImageName =
              'image_${DateTime.now().millisecondsSinceEpoch}.png';
        });
        return true; // Successfully pasted image
      }
    } catch (_) {}

    try {
      final text = await Pasteboard.text;
      if (text != null && text.isNotEmpty) {
        final selection = _controller.selection;
        final newText = _controller.text
            .replaceRange(selection.start, selection.end, text);
        _controller.value = TextEditingValue(
          text: newText,
          selection:
              TextSelection.collapsed(offset: selection.start + text.length),
        );
        return true;
      }
    } catch (_) {}
    return false;
  }

  void _send() async {
    final text = _controller.text.trim();
    final appState = context.read<AppState>();

    if (_pendingImageBytes != null && _pendingImageName != null) {
      await appState.shareImageBytes(_pendingImageBytes!, _pendingImageName!);
      setState(() {
        _pendingImageBytes = null;
        _pendingImageName = null;
      });
    }

    if (text.isNotEmpty) {
      appState.shareText(text);
      _controller.clear();
    }
  }

  void _pickFile({bool image = false}) async {
    try {
      if (io.Platform.isAndroid || io.Platform.isIOS) {
        final result = await FilePicker.platform.pickFiles(
          type: image ? FileType.image : FileType.any,
          allowCompression: false,
          allowMultiple: false,
        );
        
        if (result != null && result.files.isNotEmpty) {
          final path = result.files.single.path;
          if (path != null) {
            await context.read<AppState>().shareFile(io.File(path));
          }
        }
      } else {
        // Use file_selector for Desktop (Linux, Windows, macOS) to avoid zenity dependency
        final typeGroup = image
            ? const XTypeGroup(label: 'Images', extensions: ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic'])
            : const XTypeGroup(label: 'All Files');

        final XFile? file = await openFile(acceptedTypeGroups: [typeGroup]);
        
        if (file != null) {
          await context.read<AppState>().shareFile(io.File(file.path));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick file: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: {
        SingleActivator(LogicalKeyboardKey.keyV, control: true):
            const _PasteIntent(),
        SingleActivator(LogicalKeyboardKey.keyV, meta: true):
            const _PasteIntent(),
      },
      child: Actions(
        actions: {
          _PasteIntent: CallbackAction<_PasteIntent>(
            onInvoke: (_) {
              _handlePaste();
              return null;
            },
          ),
        },
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_pendingImageBytes != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          _pendingImageBytes!,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Image ready',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.textMuted.withOpacity(0.9),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        color: AppTheme.textMuted,
                        onPressed: () =>
                            setState(() => _pendingImageBytes = null),
                      ),
                    ],
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.bgColor,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.add, color: AppTheme.textMuted),
                      onPressed: widget.enabled
                          ? () => _showAttachmentSheet(context)
                          : null,
                      splashRadius: 20,
                    ),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        enabled: widget.enabled,
                        textCapitalization: TextCapitalization.sentences,
                        contentInsertionConfiguration: ContentInsertionConfiguration(
                          onContentInserted: (content) {
                            if (content.data != null) {
                              setState(() {
                                _pendingImageBytes = content.data;
                                _pendingImageName =
                                    'image_${DateTime.now().millisecondsSinceEpoch}.${content.mimeType.split('/').last}';
                              });
                            }
                          },
                        ),
                        decoration: InputDecoration(
                          hintText: widget.enabled
                              ? 'Type a message...'
                              : 'Connect to send',
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 10),
                          isDense: true,
                        ),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    GestureDetector(
                      onTap: widget.enabled ? _send : null,
                      child: Container(
                        margin: const EdgeInsets.only(right: 4),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: widget.enabled
                              ? AppTheme.accentColor
                              : AppTheme.textMuted.withOpacity(0.3),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.send,
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
      ),
    );
  }

  void _showAttachmentSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.borderColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.accentColor.withOpacity(0.1),
                    child: const Icon(Icons.image,
                        color: AppTheme.accentColor),
                  ),
                  title: const Text('Image'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickFile(image: true);
                  },
                ),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.accentColor.withOpacity(0.1),
                    child: const Icon(Icons.insert_drive_file,
                        color: AppTheme.accentColor),
                  ),
                  title: const Text('File'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickFile(image: false);
                  },
                ),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.accentColor.withOpacity(0.1),
                    child: const Icon(Icons.paste,
                        color: AppTheme.accentColor),
                  ),
                  title: const Text('Paste from Clipboard'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final success = await _handlePaste();
                    if (!success && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Nothing found to paste')),
                      );
                    }
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _PasteIntent extends Intent {
  const _PasteIntent();
}