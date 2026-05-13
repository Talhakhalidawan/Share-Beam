import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';

import '../../core/app_state.dart';
import '../../core/models.dart';
import '../../core/prefs.dart';
import '../../services/notification_service.dart';
import '../../ui/shared/theme.dart';

class GeneralSettingsScreen extends StatefulWidget {
  const GeneralSettingsScreen({Key? key}) : super(key: key);

  @override
  State<GeneralSettingsScreen> createState() => _GeneralSettingsScreenState();
}

class _GeneralSettingsScreenState extends State<GeneralSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        backgroundColor: AppTheme.bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppTheme.accentColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'General Settings',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppTheme.textMain,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Appearance'),
            const SizedBox(height: 12),
            _buildAppearanceCard(appState),
            const SizedBox(height: 24),

            _buildSectionTitle('Downloads'),
            const SizedBox(height: 12),
            _buildDownloadsCard(appState),
            const SizedBox(height: 24),

            _buildSectionTitle('Notifications'),
            const SizedBox(height: 12),
            _buildNotificationsCard(appState),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppTheme.textMuted,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildAppearanceCard(AppState appState) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Main Accent Color',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppTheme.textMain),
            ),
            const SizedBox(height: 12),
            _buildColorRow(
              selected: AppTheme.accentColor,
              onSelect: (color) async {
                await Prefs.setAccentColor(color.value);
                AppTheme.setColors(accent: color);
                appState.notifyListeners();
              },
            ),
            const SizedBox(height: 20),
            const Text(
              'Sent Message Color',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppTheme.textMain),
            ),
            const SizedBox(height: 12),
            _buildColorRow(
              selected: AppTheme.myBubbleColor,
              onSelect: (color) async {
                await Prefs.setSentBubbleColor(color.value);
                AppTheme.setColors(bubble: color);
                appState.notifyListeners();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorRow({required Color selected, required ValueChanged<Color> onSelect}) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          const SizedBox(width: 4),
          ...AppTheme.presetColors.map((color) {
            final isSelected = color.value == selected.value;
            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: GestureDetector(
                onTap: () => onSelect(color),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(color: AppTheme.textMain, width: 3)
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.4),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 20)
                      : null,
                ),
              ),
            );
          }).toList(),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _buildDownloadsCard(AppState appState) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            title: const Text('Save Location', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            subtitle: FutureBuilder<String>(
              future: appState.getSaveDirectory(),
              builder: (context, snap) {
                return Text(
                  snap.data ?? 'Loading...',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                );
              },
            ),
            trailing: Icon(Icons.folder_open, color: AppTheme.accentColor),
            onTap: _pickSaveDirectory,
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 16),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              title: const Text('Auto-download', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              subtitle: const Text('Which files to download automatically', style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
              iconColor: AppTheme.accentColor,
              children: [
                _buildCheckboxTile(
                  title: 'Images',
                  value: appState.autoDownloadImages,
                  onChanged: (v) async {
                    appState.autoDownloadImages = v ?? true;
                    await Prefs.setAutoDownloadImages(appState.autoDownloadImages);
                    appState.notifyListeners();
                  },
                ),
                _buildCheckboxTile(
                  title: 'Files',
                  value: appState.autoDownloadFiles,
                  onChanged: (v) async {
                    appState.autoDownloadFiles = v ?? false;
                    await Prefs.setAutoDownloadFiles(appState.autoDownloadFiles);
                    appState.notifyListeners();
                  },
                ),
                _buildCheckboxTile(
                  title: 'Text',
                  value: appState.autoDownloadText,
                  onChanged: (v) async {
                    appState.autoDownloadText = v ?? false;
                    await Prefs.setAutoDownloadText(appState.autoDownloadText);
                    appState.notifyListeners();
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Size limit:', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Slider(
                        value: appState.autoDownloadSizeThreshold.toDouble(),
                        min: 0,
                        max: 10 * 1048576,
                        divisions: 10,
                        label: '${(appState.autoDownloadSizeThreshold / 1048576).toStringAsFixed(1)} MB',
                        activeColor: AppTheme.accentColor,
                        onChanged: (v) => setState(() => appState.autoDownloadSizeThreshold = v.toInt()),
                        onChangeEnd: (v) async => await Prefs.setAutoDownloadThreshold(v.toInt()),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckboxTile({required String title, required bool value, required ValueChanged<bool?> onChanged}) {
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(fontSize: 15)),
      value: value,
      activeColor: AppTheme.accentColor,
      onChanged: onChanged,
      controlAffinity: ListTileControlAffinity.leading,
      dense: true,
    );
  }

  Widget _buildNotificationsCard(AppState appState) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            title: const Text('Message Notifications', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            subtitle: const Text('Notify when new messages arrive', style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
            value: appState.notificationsEnabled,
            activeColor: AppTheme.accentColor,
            onChanged: (v) => appState.notificationsEnabled = v,
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            title: const Text('Quick Send Notification', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            subtitle: const Text('Persistent notification to send messages instantly', style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
            value: appState.persistentNotificationEnabled,
            activeColor: AppTheme.accentColor,
            onChanged: (v) => appState.persistentNotificationEnabled = v,
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            title: const Text('Test Notification', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            trailing: Icon(Icons.notifications_active, color: AppTheme.accentColor),
            onTap: () {
              final testPayload = SharePayload(
                id: 'test-notif',
                type: FileTransferType.text,
                fileName: 'Test',
                size: 12,
                data: 'This is a test notification from ShareBeam!',
                senderName: 'ShareBeam',
              );
              NotificationService.showMessageNotification(testPayload);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _pickSaveDirectory() async {
    final path = await FilePicker.platform.getDirectoryPath();
    if (path != null) {
      await Prefs.setSaveDirectory(path);
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Save location updated')),
        );
      }
    }
  }
}