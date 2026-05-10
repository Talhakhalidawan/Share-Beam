import 'dart:convert';

enum FileTransferType { text, file, announcement }

class SharePayload {
  final String id;
  final FileTransferType type;
  final String fileName;
  final int size;
  final String? data; // for text (raw string) or base64 file content
  final String senderName;
  final DateTime timestamp;   // <-- new field

  SharePayload({
    required this.id,
    required this.type,
    required this.fileName,
    required this.size,
    this.data,
    required this.senderName,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.index,
        'fileName': fileName,
        'size': size,
        'data': data,
        'senderName': senderName,
        'timestamp': timestamp.millisecondsSinceEpoch,
      };

  factory SharePayload.fromJson(Map<String, dynamic> json) => SharePayload(
        id: json['id'],
        type: FileTransferType.values[json['type']],
        fileName: json['fileName'],
        size: json['size'],
        data: json['data'],
        senderName: json['senderName'],
        timestamp: json['timestamp'] != null
            ? DateTime.fromMillisecondsSinceEpoch(json['timestamp'])
            : null,
      );

  @override
  String toString() =>
      'SharePayload(id: $id, type: $type, from: $senderName, file: $fileName)';
}

class DiscoveredDevice {
  final String name;
  final String ip;
  final int port;

  DiscoveredDevice({required this.name, required this.ip, required this.port});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiscoveredDevice &&
          runtimeType == other.runtimeType &&
          ip == other.ip &&
          port == other.port;

  @override
  int get hashCode => ip.hashCode ^ port.hashCode;
}