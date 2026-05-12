import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../shared/theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _tabIndex = 0;
  final TextEditingController _ipController   = TextEditingController();
  final TextEditingController _portController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  // Bug #5: inline validation error for the join field.
  String? _ipError;

  static final _ipv4Re =
      RegExp(r'^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$');

  @override
  void initState() {
    super.initState();
    final appState = context.read<AppState>();
    _portController.text = appState.hostPort.toString();
    _nameController.text = appState.deviceName;
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  // ── Validation ─────────────────────────────────────────────────────────────

  /// Parses "ip:port" or bare "ip", validates both, returns (ip, port) or null.
  ({String ip, int port})? _parseAndValidate(String input, int fallbackPort) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      setState(() => _ipError = 'Enter a host address');
      return null;
    }

    String ipPart;
    int    portPart;

    if (trimmed.contains(':')) {
      final idx = trimmed.lastIndexOf(':');
      ipPart = trimmed.substring(0, idx);
      final p = int.tryParse(trimmed.substring(idx + 1));
      if (p == null || p <= 0 || p > 65535) {
        setState(() => _ipError = 'Invalid port — must be 1–65535');
        return null;
      }
      portPart = p;
    } else {
      ipPart   = trimmed;
      portPart = fallbackPort;
    }

    if (!_ipv4Re.hasMatch(ipPart)) {
      setState(() => _ipError = 'Enter a valid IP (e.g. 192.168.1.42)');
      return null;
    }

    // Check each octet is 0–255.
    final octets = ipPart.split('.').map(int.parse).toList();
    if (octets.any((o) => o > 255)) {
      setState(() => _ipError = 'Each IP octet must be 0–255');
      return null;
    }

    setState(() => _ipError = null);
    return (ip: ipPart, port: portPart);
  }

  void _connect(AppState appState) {
    final parsed = _parseAndValidate(
      _ipController.text,
      appState.hostPort,
    );
    if (parsed == null) return;
    appState.connectTo(parsed.ip, parsed.port);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Connection'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (appState.connectionStatus.isNotEmpty) ...[
              _buildStatusBanner(appState),
              const SizedBox(height: 16),
            ],
            _buildSegmentedControl(),
            const SizedBox(height: 24),
            _buildDeviceNameField(appState),
            const SizedBox(height: 24),
            _tabIndex == 0
                ? _buildHostTab(appState)
                : _buildJoinTab(appState),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBanner(AppState appState) {
    final isError = appState.connectionStatus.contains('Failed') ||
        appState.connectionStatus.contains('error') ||
        appState.connectionStatus.contains('already in use') ||
        appState.connectionStatus.contains('Could not') ||
        appState.connectionStatus.contains('not available') ||
        appState.connectionStatus.contains('Network error');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isError ? Colors.red.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            size: 18,
            color: isError ? Colors.red : Colors.green,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              appState.connectionStatus,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
            ),
          ),
          GestureDetector(
            onTap: () => appState.clearStatus(),
            child: Icon(Icons.close, size: 16, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceNameField(AppState appState) {
    return TextField(
      controller: _nameController,
      decoration: const InputDecoration(
        labelText: 'Your Device Name',
        hintText: 'e.g. Talha\'s Phone',
        border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12))),
        contentPadding:
            EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      onChanged: (name) => appState.deviceName = name,
    );
  }

  Widget _buildSegmentedControl() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceHover,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderColor),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _segTab('Host Server', 0),
          _segTab('Join Server', 1),
        ],
      ),
    );
  }

  Widget _segTab(String label, int index) {
    final active = _tabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tabIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? AppTheme.surfaceColor : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            boxShadow: active
                ? [const BoxShadow(
                    color: Colors.black12, blurRadius: 4,
                    offset: Offset(0, 2))]
                : [],
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 13,
              color: active ? AppTheme.textMain : AppTheme.textMuted,
            ),
          ),
        ),
      ),
    );
  }

  // ── Available Networks ─────────────────────────────────────────────────────

  Widget _buildAvailableNetworks(AppState appState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('AVAILABLE NETWORKS',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textMuted,
                    letterSpacing: 1)),
            appState.isScanning
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppTheme.textMuted))
                : IconButton(
                    icon: const Icon(Icons.refresh_rounded,
                        size: 20, color: AppTheme.textMuted),
                    onPressed: () => appState.refreshDiscovery(),
                  ),
          ],
        ),
        const SizedBox(height: 12),
        if (appState.discoveredHosts.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('No hosts found. Tap refresh to scan.',
                style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
          )
        else
          ...appState.discoveredHosts.map(
            (d) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                title: Text(d.name,
                    style: const TextStyle(fontWeight: FontWeight.w500)),
                subtitle: Text('${d.ip}:${d.port}',
                    style: const TextStyle(fontSize: 12)),
                trailing:
                    const Icon(Icons.wifi_tethering, size: 20),
                onTap: () {
                  setState(() {
                    _tabIndex = 1;
                    _ipController.text = '${d.ip}:${d.port}';
                    _ipError = null;
                  });
                  appState.connectTo(d.ip, d.port);
                },
              ),
            ),
          ),
      ],
    );
  }

  // ── Host Tab ───────────────────────────────────────────────────────────────

  Widget _buildHostTab(AppState appState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _portController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Host Port',
                  hintText: '9876',
                  border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.all(Radius.circular(12))),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                onChanged: (val) {
                  final port = int.tryParse(val);
                  if (port != null) appState.setHostPort = port;
                },
              ),
            ),
            const SizedBox(width: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    appState.isHosting ? Colors.red : AppTheme.accentColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
                minimumSize: const Size(120, 52),
              ),
              onPressed: appState.isBusy
                  ? null
                  : () => appState.toggleHosting(!appState.isHosting),
              child: appState.isBusy && !appState.isHosting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(appState.isHosting ? 'Stop' : 'Start'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (appState.isHosting) ...[
          const Text('HOSTING ADDRESS',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textMuted,
                  letterSpacing: 1)),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(
                  text:
                      '${appState.localIp}:${appState.hostPort}'));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Address copied'),
                  duration: Duration(seconds: 1)));
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.borderColor),
                borderRadius: BorderRadius.circular(16),
                color: AppTheme.surfaceHover,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${appState.localIp}:${appState.hostPort}',
                        style: const TextStyle(
                            fontSize: 18,
                            letterSpacing: -0.5,
                            fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      const Text('Ready for connections',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textMuted)),
                    ],
                  ),
                  const Icon(Icons.copy_rounded,
                      size: 20, color: AppTheme.textMuted),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          _buildParticipantsList(appState),
        ] else ...[
          const SizedBox(height: 24),
          _buildAvailableNetworks(appState),
        ],
      ],
    );
  }

  // ── Join Tab ───────────────────────────────────────────────────────────────

  Widget _buildJoinTab(AppState appState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _ipController,
                enabled: !appState.isBusy,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Host Address',
                  hintText: '192.168.1.42:9876',
                  // Bug #5: show validation error inline.
                  errorText: _ipError,
                  border: const OutlineInputBorder(
                      borderRadius:
                          BorderRadius.all(Radius.circular(12))),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                ),
                onChanged: (_) {
                  if (_ipError != null) setState(() => _ipError = null);
                },
              ),
            ),
            const SizedBox(width: 16),
            Padding(
              // Align button with the text field when errorText appears.
              padding: EdgeInsets.only(top: _ipError != null ? 0 : 0),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: appState.isConnectedToHost
                      ? Colors.red
                      : AppTheme.accentColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(120, 52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: appState.isBusy
                    ? null
                    : (appState.isConnectedToHost
                        ? () => appState.disconnectFromHost()
                        : () => _connect(appState)),
                child: appState.isBusy && !appState.isConnectedToHost
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(appState.isConnectedToHost
                        ? 'Disconnect'
                        : 'Connect'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        if (appState.isConnectedToHost)
          _buildParticipantsList(appState)
        else ...[
          const SizedBox(height: 24),
          _buildAvailableNetworks(appState),
        ],
      ],
    );
  }

  // ── Participants ───────────────────────────────────────────────────────────

  Widget _buildParticipantsList(AppState appState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('PARTICIPANTS',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textMuted,
                letterSpacing: 1)),
        const SizedBox(height: 16),
        if (appState.participants.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('No one connected yet',
                style: TextStyle(
                    color: AppTheme.textMuted, fontSize: 13)),
          )
        else
          ...appState.participants.map(
            (name) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceHover.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text(name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 14))),
                    const Icon(Icons.person,
                        size: 16, color: AppTheme.textMuted),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}