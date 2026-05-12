import 'dart:convert';

enum FileTransferType { text, file, announcement }

class SharePayload {
  final String id;
  final FileTransferType type;
  final String fileName;
  final int size;
  final String? data;
  final String senderName;
  final String? senderIp;   // IP of the device serving the file download
  final int?    senderPort; // HTTP port of the device serving the file download
  final DateTime timestamp;

  SharePayload({
    required this.id,
    required this.type,
    required this.fileName,
    required this.size,
    this.data,
    required this.senderName,
    this.senderIp,
    this.senderPort,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id':         id,
    'type':       type.index,
    'fileName':   fileName,
    'size':       size,
    'data':       data,
    'senderName': senderName,
    'senderIp':   senderIp,
    'senderPort': senderPort,
    'timestamp':  timestamp.millisecondsSinceEpoch,
  };

  factory SharePayload.fromJson(Map<String, dynamic> json) => SharePayload(
    id:         json['id']         as String,
    type:       FileTransferType.values[json['type'] as int],
    fileName:   json['fileName']   as String,
    size:       json['size']       as int,
    data:       json['data']       as String?,
    senderName: json['senderName'] as String,
    senderIp:   json['senderIp']   as String?,
    senderPort: json['senderPort'] as int?,
    timestamp:  json['timestamp'] != null
        ? DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int)
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

  const DiscoveredDevice({
    required this.name,
    required this.ip,
    required this.port,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiscoveredDevice &&
          runtimeType == other.runtimeType &&
          ip   == other.ip &&
          port == other.port;

  @override
  int get hashCode => ip.hashCode ^ port.hashCode;
}