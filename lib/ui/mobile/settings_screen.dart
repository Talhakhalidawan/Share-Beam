import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_selector/file_selector.dart' as selector;
import 'dart:io' as io;

import '../../core/app_state.dart';
import '../../core/prefs.dart';
import '../shared/theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          ServerSettingsPage(),
          GeneralSettingsPage(),
        ],
      ),
      bottomNavigationBar: CupertinoTabBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        backgroundColor: Colors.white.withOpacity(0.94),
        activeColor: const Color(0xFF007AFF),
        inactiveColor: const Color(0xFF8E8E93),
        border: const Border(
          top: BorderSide(
            color: Color(0xFFE5E5EA),
            width: 0.5,
          ),
        ),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.antenna_radiowaves_left_right),
            label: 'Server',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.settings),
            label: 'General',
          ),
        ],
      ),
    );
  }
}

class ServerSettingsPage extends StatefulWidget {
  const ServerSettingsPage({Key? key}) : super(key: key);

  @override
  State<ServerSettingsPage> createState() => _ServerSettingsPageState();
}

class _ServerSettingsPageState extends State<ServerSettingsPage> {
  final TextEditingController _portController = TextEditingController();

  static const Color _iosBg = Color(0xFFF2F2F7);
  static const Color _iosCardBg = Colors.white;
  static const Color _iosBlue = Color(0xFF007AFF);
  static const Color _iosRed = Color(0xFFFF3B30);
  static const Color _iosGray = Color(0xFF8E8E93);
  static const Color _iosBorder = Color(0xFFE5E5EA);
  static const Color _iosText = Colors.black;

  @override
  void initState() {
    super.initState();
    final appState = context.read<AppState>();
    _portController.text = appState.hostPort.toString();
  }

  @override
  void dispose() {
    _portController.dispose();
    super.dispose();
  }

  Widget _iosDialog({
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Dialog(
      backgroundColor: _iosCardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 20, fontWeight: FontWeight.w600, color: _iosBlue,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14, color: _iosGray, height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }

  void _showNameDialog(AppState appState) {
    final controller = TextEditingController(text: appState.deviceName);
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => _iosDialog(
        title: 'Your Name',
        subtitle: 'This is how others will see you on the network.',
        children: [
          TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            style: const TextStyle(color: _iosText),
            maxLength: 15,
            decoration: InputDecoration(
              counterText: '',
              hintText: 'e.g. Talha\'s Phone',
              hintStyle: const TextStyle(color: _iosGray),
              filled: true,
              fillColor: _iosBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _iosBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _iosBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _iosBlue),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _iosBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  appState.deviceName = controller.text.trim();
                }
                Navigator.of(context).pop();
              },
              child: const Text(
                'Save',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showHostDialog(AppState appState) {
    final controller = TextEditingController(text: appState.hostPort.toString());
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => StatefulBuilder(
        builder: (context, setSt) {
          return _iosDialog(
            title: 'Start Hosting',
            subtitle: 'Enter a unique server port to start server',
            children: [
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                inputFormatters: [LengthLimitingTextInputFormatter(4)],
                style: const TextStyle(color: _iosText),
                decoration: InputDecoration(
                  hintText: 'Enter Port (eg. 5500)',
                  hintStyle: const TextStyle(color: _iosGray),
                  filled: true,
                  fillColor: _iosBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _iosBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _iosBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _iosBlue),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _iosBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: appState.isBusy
                      ? null
                      : () {
                          final port = int.tryParse(controller.text);
                          if (port != null) {
                            appState.setHostPort = port;
                          }
                          Navigator.of(context).pop();
                          appState.startHosting();
                        },
                  child: const Text(
                    'Start Server',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showJoinDialog(AppState appState) {
    final controller = TextEditingController();
    bool connectAuto = false;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => StatefulBuilder(
        builder: (context, setSt) {
          return _iosDialog(
            title: 'Enter Host Address',
            subtitle: 'Enter the host address along with port to join',
            children: [
              TextField(
                controller: controller,
                style: const TextStyle(color: _iosText),
                decoration: InputDecoration(
                  hintText: 'Enter Host (eg. 192.168.1.42:9876)',
                  hintStyle: const TextStyle(color: _iosGray),
                  filled: true,
                  fillColor: _iosBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _iosBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _iosBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _iosBlue),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                ),
              ),
              const SizedBox(height: 4),
              GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => setSt(() => connectAuto = !connectAuto),
                child: Row(
                  children: [
                    Checkbox(
                      value: connectAuto,
                      activeColor: _iosBlue,
                      side: const BorderSide(color: _iosGray, width: 1.5),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      onChanged: (v) => setSt(() => connectAuto = v ?? false),
                    ),
                    const SizedBox(width: 2),
                    const Text(
                      'Connect automatically',
                      style: TextStyle(fontSize: 14, color: _iosGray),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _iosBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: appState.isBusy
                      ? null
                      : () async {
                          final input = controller.text.trim();
                          Navigator.of(context).pop();
                          if (input.isEmpty) return;
                          String ip = input;
                          int port = appState.hostPort;
                          if (input.contains(':')) {
                            final parts = input.split(':');
                            ip = parts[0];
                            final p = int.tryParse(parts[1]);
                            if (p != null) port = p;
                          }
                          if (connectAuto) {
                            await Prefs.addAutoConnectHost(ip, port, 'Manual');
                          }
                          appState.connectTo(ip, port);
                        },
                  child: const Text(
                    'Join Host',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    final bool isHosting = appState.isHosting;
    final bool isConnected = appState.isConnectedToHost;

    final String headerActionText;
    final Color headerActionColor;
    final VoidCallback? headerAction;

    if (isHosting) {
      headerActionText = 'Stop Hosting';
      headerActionColor = _iosRed;
      headerAction = appState.isBusy ? null : () => appState.stopHosting();
    } else if (isConnected) {
      headerActionText = 'Disconnect';
      headerActionColor = _iosRed;
      headerAction = appState.isBusy ? null : () => appState.disconnectFromHost();
    } else {
      headerActionText = 'Host Server';
      headerActionColor = _iosBlue;
      headerAction = appState.isBusy ? null : () => _showHostDialog(appState);
    }

    return Scaffold(
      backgroundColor: _iosBg,
      appBar: AppBar(
        backgroundColor: _iosBg,
        elevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: false,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, color: _iosBlue, size: 28),
                onPressed: () => Navigator.pop(context),
              ),
              const Text(
                'Settings',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: _iosText,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: headerAction,
            child: Text(
              headerActionText,
              style: TextStyle(
                color: headerActionColor,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            _buildNameCard(appState),
            const SizedBox(height: 24),
            if (isHosting) ...[
              _buildAddressCard(appState),
              const SizedBox(height: 24),
              _buildConnectedDevices(appState),
            ] else if (isConnected) ...[
              _buildParticipants(appState),
            ] else ...[
              _buildAvailableHosts(appState),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNameCard(AppState appState) {
    return _buildCard(
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showNameDialog(appState),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Name',
                  style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w500, color: _iosText,
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Flexible(
                        child: Text(
                          appState.deviceName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 16, color: _iosGray),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right, color: _iosBlue, size: 20),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvailableHosts(AppState appState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'AVAILABLE HOSTS',
              style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600,
                color: _iosGray, letterSpacing: 1,
              ),
            ),
            appState.isScanning
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2, color: _iosGray,
                    ),
                  )
                : IconButton(
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.refresh, size: 20, color: _iosGray),
                    onPressed: () => appState.refreshDiscovery(),
                  ),
          ],
        ),
        const SizedBox(height: 8),
        _buildCard(
          child: Column(
            children: [
              _listTile(
                label: 'Join manually',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Enter address',
                      style: TextStyle(fontSize: 16, color: _iosGray),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right, color: _iosBlue, size: 20),
                  ],
                ),
                onTap: () => _showJoinDialog(appState),
                showDivider: appState.discoveredHosts.isNotEmpty,
              ),
              ...appState.discoveredHosts.asMap().entries.map((e) {
                final isLast = e.key == appState.discoveredHosts.length - 1;
                return _listTile(
                  label: e.value.name,
                  trailing: const Icon(
                    Icons.wifi_tethering, size: 20, color: _iosText,
                  ),
                  onTap: () => appState.connectTo(e.value.ip, e.value.port),
                  showDivider: !isLast,
                );
              }).toList(),
              if (appState.discoveredHosts.isEmpty && !appState.isScanning)
                _listTile(
                  label: 'No hosts found. Tap refresh to scan.',
                  trailing: const SizedBox.shrink(),
                  onTap: null,
                  showDivider: false,
                  isPlaceholder: true,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAddressCard(AppState appState) {
    return _buildCard(
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Clipboard.setData(ClipboardData(
                text: '${appState.localIp}:${appState.hostPort}'));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Address copied to clipboard'),
                duration: Duration(seconds: 1),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Address',
                  style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w500, color: _iosText,
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Flexible(
                        child: Text(
                          '${appState.localIp}:${appState.hostPort}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 16, color: _iosGray),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.copy, size: 18, color: _iosGray),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConnectedDevices(AppState appState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'CONNECTED DEVICES',
          style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600,
            color: _iosGray, letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        _buildCard(
          child: Column(
            children: [
              if (appState.participants.isEmpty)
                _listTile(
                  label: 'No one connected yet',
                  trailing: const SizedBox.shrink(),
                  onTap: null,
                  showDivider: false,
                  isPlaceholder: true,
                )
              else
                ...appState.participants.asMap().entries.map((e) {
                  final isLast = e.key == appState.participants.length - 1;
                  return _listTile(
                    label: e.value,
                    trailing: const Icon(
                      Icons.person_outline, size: 20, color: _iosText,
                    ),
                    onTap: null,
                    showDivider: !isLast,
                  );
                }).toList(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildParticipants(AppState appState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'PARTICIPANTS',
          style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600,
            color: _iosGray, letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        _buildCard(
          child: Column(
            children: [
              if (appState.participants.isEmpty)
                _listTile(
                  label: 'No participants',
                  trailing: const SizedBox.shrink(),
                  onTap: null,
                  showDivider: false,
                  isPlaceholder: true,
                )
              else
                ...appState.participants.asMap().entries.map((e) {
                  final isLast = e.key == appState.participants.length - 1;
                  return _listTile(
                    label: e.value,
                    trailing: const Icon(
                      Icons.wifi_tethering, size: 20, color: _iosText,
                    ),
                    onTap: null,
                    showDivider: !isLast,
                  );
                }).toList(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: _iosCardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }

  Widget _listTile({
    required String label,
    required Widget trailing,
    VoidCallback? onTap,
    bool showDivider = true,
    bool isPlaceholder = false,
  }) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isPlaceholder ? FontWeight.w400 : FontWeight.w500,
                color: isPlaceholder ? _iosGray : _iosText,
              ),
            ),
          ),
          trailing,
        ],
      ),
    );

    if (onTap == null) {
      return Container(
        decoration: BoxDecoration(
          border: showDivider
              ? const Border(bottom: BorderSide(color: _iosBorder))
              : null,
        ),
        child: content,
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.vertical(
          top: const Radius.circular(12),
          bottom: Radius.circular(showDivider ? 0 : 12),
        ),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: showDivider
                ? const Border(bottom: BorderSide(color: _iosBorder))
                : null,
          ),
          child: content,
        ),
      ),
    );
  }
}

class GeneralSettingsPage extends StatelessWidget {
  const GeneralSettingsPage({Key? key}) : super(key: key);

  static const Color _iosBg = Color(0xFFF2F2F7);
  static const Color _iosCardBg = Colors.white;
  static const Color _iosBlue = Color(0xFF007AFF);
  static const Color _iosGray = Color(0xFF8E8E93);
  static const Color _iosBorder = Color(0xFFE5E5EA);
  static const Color _iosText = Colors.black;

  Future<void> _pickDownloadFolder(BuildContext context, AppState appState) async {
    try {
      String? result;
      if (io.Platform.isAndroid || io.Platform.isIOS) {
        result = await FilePicker.platform.getDirectoryPath();
      } else {
        result = await selector.getDirectoryPath();
      }

      if (result != null) {
        appState.downloadPath = result;
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick folder: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Scaffold(
      backgroundColor: _iosBg,
      appBar: AppBar(
        backgroundColor: _iosBg,
        elevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: false,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, color: _iosBlue, size: 28),
                onPressed: () => Navigator.pop(context),
              ),
              const Text(
                'General Settings',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: _iosText,
                ),
              ),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            const Text(
              'STORAGE',
              style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600,
                color: _iosGray, letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            _buildCard(
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _pickDownloadFolder(context, appState),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Download Path',
                              style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w500, color: _iosText,
                              ),
                            ),
                            const Icon(CupertinoIcons.folder_open, color: _iosBlue, size: 22),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          appState.downloadPath ?? 'System Default (Downloads)',
                          style: const TextStyle(fontSize: 14, color: _iosGray),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _iosCardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}
xtButton.icon(
                onPressed: () => appState.downloadPath = null,
                icon: const Icon(CupertinoIcons.refresh_thin, size: 16, color: _iosBlue),
                label: const Text(
                  'Reset to default',
                  style: TextStyle(color: _iosBlue, fontSize: 14),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _iosCardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}
