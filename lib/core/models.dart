import 'dart:convert';

enum FileTransferType { text, file, announcement }

class SharePayload {
  final String id;
  final FileTransferType type;
  final String fileName;
  final int size;
  final String? data; // Used for text or < 1MB files (base64)
  final String senderName;

  SharePayload({
    required this.id,
    required this.type,
    required this.fileName,
    required this.size,
    this.data,
    required this.senderName,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.index,
    'fileName': fileName,
    'size': size,
    'data': data,
    'senderName': senderName,
  };

  factory SharePayload.fromJson(Map<String, dynamic> json) => SharePayload(
    id: json['id'],
    type: FileTransferType.values[json['type']],
    fileName: json['fileName'],
    size: json['size'],
    data: json['data'],
    senderName: json['senderName'],
  );
}

class DiscoveredDevice {
  final String name;
  final String ip;
  final int port;

  DiscoveredDevice({required this.name, required this.ip, required this.port});
}
