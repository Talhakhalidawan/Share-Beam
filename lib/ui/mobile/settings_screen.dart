import 'package:flutter/material.dart';
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
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.borderColor),
              borderRadius: BorderRadius.circular(16),
              color: AppTheme.surfaceHover,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(appState.localIp, style: const TextStyle(fontSize: 16, letterSpacing: -0.5, fontWeight: FontWeight.w500)),
                const Text('Local IP', style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'CONNECTED DEVICES (${appState.connectedDevices.length})',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textMuted, letterSpacing: 1),
          ),
          const SizedBox(height: 16),
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
          )).toList(),
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
                   hintText: 'Enter Host IP',
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
               onPressed: () {
                 if (_ipController.text.isNotEmpty) {
                    appState.connectTo(_ipController.text, 8080);
                 }
               },
               child: const Text('Join'),
             )
           ],
         ),
         const SizedBox(height: 32),
         appState.connectedDevices.isNotEmpty 
           ? Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               const Text('Found Hosts via mDNS', style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textMuted)),
               const SizedBox(height: 16),
               ...appState.connectedDevices.map((d) => ListTile(
                 title: Text(d.name),
                 subtitle: Text(d.ip),
                 trailing: const Icon(Icons.wifi),
                 onTap: () => appState.connectTo(d.ip, 8080),
               )).toList(),
             ],
           )
           : Column(
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
