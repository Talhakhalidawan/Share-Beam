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
            _buildSegmentedControl(),
            const SizedBox(height: 24),
            // Show connection status banner
            if (appState.connectionStatus.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: appState.connectionStatus.contains('Failed') || appState.connectionStatus.contains('error')
                    ? Colors.red.shade50
                    : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      appState.connectionStatus.contains('Failed') || appState.connectionStatus.contains('error')
                        ? Icons.error_outline
                        : Icons.check_circle_outline,
                      size: 18,
                      color: appState.connectionStatus.contains('Failed') || appState.connectionStatus.contains('error')
                        ? Colors.red
                        : Colors.green,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(
                      appState.connectionStatus,
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
                    )),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            _tabIndex == 0 ? _buildHostTab(appState) : _buildJoinTab(appState),
          ],
        ),
      ),
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
                child: Text('Host Server', style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                  color: _tabIndex == 0 ? AppTheme.textMain : AppTheme.textMuted
                )),
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
                child: Text('Join Server', style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                  color: _tabIndex == 1 ? AppTheme.textMain : AppTheme.textMuted
                )),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHostTab(AppState appState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          title: const Text('Host Server Locally', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
          subtitle: const Text('Start mDNS and HTTP server'),
          value: appState.isHosting,
          onChanged: (val) => appState.toggleHosting(val),
          activeColor: AppTheme.accentColor,
          contentPadding: EdgeInsets.zero,
        ),
        const SizedBox(height: 16),
        if (appState.isHosting) ...[
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: appState.localIp));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('IP copied to clipboard'), duration: Duration(seconds: 1)),
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
                  Text(
                    '${appState.localIp}:${AppState.serverPort}',
                    style: const TextStyle(fontSize: 16, letterSpacing: -0.5, fontWeight: FontWeight.w500),
                  ),
                  const Text('tap to copy', style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'CONNECTED DEVICES (${appState.connectedDevices.length})',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textMuted, letterSpacing: 1),
          ),
          const SizedBox(height: 16),
          if (appState.connectedDevices.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('No devices connected yet', style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
            ),
          ...appState.connectedDevices.map((d) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Container(
                  width: 8, height: 8,
                  decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(d.name, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14))),
                Text(d.ip, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
              ],
            ),
          )),
        ]
      ],
    );
  }

  Widget _buildJoinTab(AppState appState) {
     return Column(
       children: [
         Row(
           children: [
             Expanded(
               child: TextField(
                 controller: _ipController,
                 decoration: InputDecoration(
                   hintText: 'Enter Host IP (e.g. 192.168.1.42)',
                   border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                   contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                 ),
               )
             ),
             const SizedBox(width: 12),
             ElevatedButton(
               style: ElevatedButton.styleFrom(
                 backgroundColor: AppTheme.accentColor,
                 foregroundColor: Colors.white,
                 minimumSize: const Size(0, 48),
                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
               ),
               onPressed: appState.isConnectedToHost
                 ? () => appState.disconnectFromHost()
                 : () {
                     String ip = _ipController.text.trim();
                     int port = AppState.serverPort;
                     
                     if (ip.contains(':')) {
                       final parts = ip.split(':');
                       ip = parts[0];
                       port = int.tryParse(parts[1]) ?? AppState.serverPort;
                     }
                     
                     if (ip.isNotEmpty) {
                       appState.connectTo(ip, port);
                     }
                   },
               child: Text(appState.isConnectedToHost ? 'Disconnect' : 'Join'),
             )
           ],
         ),
         const SizedBox(height: 32),
         if (appState.connectedDevices.isNotEmpty) 
           Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               const Text('Found Hosts via mDNS', style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textMuted)),
               const SizedBox(height: 16),
               ...appState.connectedDevices.map((d) => ListTile(
                 title: Text(d.name),
                 subtitle: Text(d.ip),
                 trailing: const Icon(Icons.wifi),
                 onTap: () => appState.connectTo(d.ip, d.port),
               )),
             ],
           )
         else
           Column(
             children: const [
               Icon(Icons.radar, size: 32, color: Colors.grey),
               SizedBox(height: 8),
               Text('Searching for nearby hosts...', style: TextStyle(fontSize: 14, color: AppTheme.textMuted))
             ],
           )
       ],
     );
  }
}
