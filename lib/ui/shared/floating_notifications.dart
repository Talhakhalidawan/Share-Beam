import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_state.dart';

class FloatingNotifications extends StatefulWidget {
  final Widget child;
  const FloatingNotifications({Key? key, required this.child}) : super(key: key);

  @override
  State<FloatingNotifications> createState() => _FloatingNotificationsState();
}

class _FloatingNotificationsState extends State<FloatingNotifications> with SingleTickerProviderStateMixin {
  StreamSubscription? _subscription;
  final List<_NotificationItem> _notifications = [];
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _subscription?.cancel();
    final appState = Provider.of<AppState>(context, listen: false);
    _subscription = appState.notificationStream.listen(_showNotification);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _showNotification(AppNotification notification) {
    if (!mounted) return;
    
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    setState(() {
      _notifications.add(_NotificationItem(
        id: id,
        message: notification.message,
        type: notification.type,
      ));
    });

    // Auto-remove after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _notifications.removeWhere((n) => n.id == id);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned(
          bottom: 40,
          left: 20,
          right: 20,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _notifications.map((n) => _NotificationWidget(item: n)).toList(),
          ),
        ),
      ],
    );
  }
}

class _NotificationItem {
  final String id;
  final String message;
  final NotificationType type;
  _NotificationItem({required this.id, required this.message, required this.type});
}

class _NotificationWidget extends StatelessWidget {
  final _NotificationItem item;
  const _NotificationWidget({Key? key, required this.item}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bgColor = item.type == NotificationType.error 
        ? const Color(0xFFFFE5E5) 
        : item.type == NotificationType.success 
            ? const Color(0xFFE5FFE5)
            : Colors.white;
    
    final textColor = item.type == NotificationType.error 
        ? const Color(0xFFFF3B30) 
        : item.type == NotificationType.success 
            ? const Color(0xFF34C759)
            : const Color(0xFF8E8E93);

    final icon = item.type == NotificationType.error 
        ? Icons.error_outline 
        : item.type == NotificationType.success 
            ? Icons.check_circle_outline
            : Icons.info_outline;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: textColor.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Icon(icon, color: textColor, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.message,
                style: TextStyle(
                  color: Colors.black.withOpacity(0.8),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.none,
                  fontFamily: 'Inter', // Fallback
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
