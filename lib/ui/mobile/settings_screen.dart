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
  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _portController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

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
            // Status banner
            if (appState.connectionStatus.isNotEmpty) ...[
              _buildStatusBanner(appState),
              const SizedBox(height: 16),
            ],
            _buildSegmentedControl(),
            const SizedBox(height: 24),
            _buildDeviceNameField(appState),
            const SizedBox(height: 24),
            _tabIndex == 0 ? _buildHostTab(appState) : _buildJoinTab(appState),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBanner(AppState appState) {
    final isError = appState.connectionStatus.contains('Failed') ||
        appState.connectionStatus.contains('error') ||
        appState.connectionStatus.contains('already in use') ||
        appState.connectionStatus.contains('Could not');

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
        hintText: 'e.g. Talha’s Phone',
        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _tabIndex = 0),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _tabIndex == 0 ? AppTheme.surfaceColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: _tabIndex == 0
                      ? [const BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))]
                      : [],
                ),
                alignment: Alignment.center,
                child: Text('Host Server',
                    style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                        color: _tabIndex == 0 ? AppTheme.textMain : AppTheme.textMuted)),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _tabIndex = 1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _tabIndex == 1 ? AppTheme.surfaceColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: _tabIndex == 1
                      ? [const BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))]
                      : [],
                ),
                alignment: Alignment.center,
                child: Text('Join Server',
                    style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                        color: _tabIndex == 1 ? AppTheme.textMain : AppTheme.textMuted)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---- Available Networks (only when idle) ----
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
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.textMuted),
                  )
                : IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 20, color: AppTheme.textMuted),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                title: Text(d.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                subtitle: Text('${d.ip}:${d.port}', style: const TextStyle(fontSize: 12)),
                trailing: const Icon(Icons.wifi_tethering, size: 20),
                onTap: () {
                  setState(() {
                    _tabIndex = 1;
                    _ipController.text = '${d.ip}:${d.port}';
                  });
                },
              ),
            ),
          ),
      ],
    );
  }

  // ---- Host Tab ----
  Widget _buildHostTab(AppState appState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Port input row
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _portController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Host Port',
                  hintText: '9876',
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                backgroundColor: appState.isHosting ? Colors.red : AppTheme.accentColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
                minimumSize: const Size(120, 52),
              ),
              onPressed: appState.isBusy
                  ? null
                  : () => appState.toggleHosting(!appState.isHosting),
              child: appState.isBusy && !appState.isHosting
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(appState.isHosting ? 'Stop' : 'Start'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        // When hosting: show hosting address and participants
        if (appState.isHosting) ...[
          const Text('HOSTING ADDRESS',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                  color: AppTheme.textMuted, letterSpacing: 1)),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: '${appState.localIp}:${appState.hostPort}'));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Address copied to clipboard'), duration: Duration(seconds: 1)),
              );
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
                      Text('${appState.localIp}:${appState.hostPort}',
                          style: const TextStyle(fontSize: 18, letterSpacing: -0.5,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      const Text('Ready for connections',
                          style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                    ],
                  ),
                  const Icon(Icons.copy_rounded, size: 20, color: AppTheme.textMuted),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          const Text('PARTICIPANTS',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                  color: AppTheme.textMuted, letterSpacing: 1)),
          const SizedBox(height: 16),
          if (appState.participants.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('No one connected yet',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
            ),
          ...appState.participants.map((name) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceHover.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(width: 8, height: 8,
                          decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                      const SizedBox(width: 12),
                      Expanded(child: Text(name,
                          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14))),
                      const Icon(Icons.person, size: 16, color: AppTheme.textMuted),
                    ],
                  ),
                ),
              )),
        ] else ...[
          const SizedBox(height: 24),
          _buildAvailableNetworks(appState),
        ],
      ],
    );
  }

  // ---- Join Tab ----
  Widget _buildJoinTab(AppState appState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ipController,
                enabled: !appState.isBusy,
                style: const TextStyle(fontSize: 14),
                decoration: const InputDecoration(
                  labelText: 'Host Address',
                  hintText: '192.168.1.42:9876',
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: appState.isConnectedToHost ? Colors.red : AppTheme.accentColor,
                foregroundColor: Colors.white,
                minimumSize: const Size(120, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              onPressed: appState.isBusy
                  ? null
                  : (appState.isConnectedToHost
                      ? () => appState.disconnectFromHost()
                      : () {
                          String input = _ipController.text.trim();
                          if (input.isEmpty) return;
                          String ip = input;
                          int port = appState.hostPort;
                          if (input.contains(':')) {
                            final parts = input.split(':');
                            ip = parts[0];
                            final p = int.tryParse(parts[1]);
                            if (p != null) port = p;
                          }
                          appState.connectTo(ip, port);
                        }),
              child: appState.isBusy && !appState.isConnectedToHost
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(appState.isConnectedToHost ? 'Disconnect' : 'Connect'),
            ),
          ],
        ),
        const SizedBox(height: 32),
        // When connected: show participants
        if (appState.isConnectedToHost) ...[
          const Text('PARTICIPANTS',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                  color: AppTheme.textMuted, letterSpacing: 1)),
          const SizedBox(height: 16),
          if (appState.participants.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('No participants',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
            ),
          ...appState.participants.map((name) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceHover.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(width: 8, height: 8,
                          decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                      const SizedBox(width: 12),
                      Expanded(child: Text(name,
                          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14))),
                      const Icon(Icons.person, size: 16, color: AppTheme.textMuted),
                    ],
                  ),
                ),
              )),
        ] else ...[
          const SizedBox(height: 24),
          _buildAvailableNetworks(appState),
        ],
      ],
    );
  }
}