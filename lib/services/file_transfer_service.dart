import 'dart:async';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

class FileTransferService {
  final Map<String, File> _hostedFiles = {};

  final _progressController = StreamController<Map<String, double>>.broadcast();
  Stream<Map<String, double>> get progressStream => _progressController.stream;

  void hostFile(String id, File file) {
    _hostedFiles[id] = file;
  }

  void setupRoutes(Router router) {
    router.get('/download/<id>', (Request request, String id) async {
      final file = _hostedFiles[id];
      if (file == null || !await file.exists()) {
        return Response.notFound('File not found');
      }
      final stat = await file.stat();
      final fileStream = file.openRead();
      return Response.ok(
        fileStream,
        headers: {
          'Content-Length': stat.size.toString(),
          'Content-Type': 'application/octet-stream',
          'Content-Disposition':
              'attachment; filename="${file.uri.pathSegments.last}"',
        },
      );
    });
  }

  Future<File?> downloadFile({
    required String ip,
    required int port,
    required String id,
    required String fileName,
    required String saveDirectory,
  }) async {
    final url = Uri.parse('http://$ip:$port/download/$id');
    final httpClient = HttpClient();
    // Increase timeout for large files or slow networks
    httpClient.connectionTimeout = const Duration(seconds: 15);

    final dir = Directory(saveDirectory);
    try {
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
    } catch (e) {
      print('[FileTransferService] Failed to create directory: $e');
      return null;
    }

    final tempPath = '$saveDirectory/$fileName.tmp';
    final finalPath = '$saveDirectory/$fileName';

    try {
      final request = await httpClient.getUrl(url);
      final response = await request.close().timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final contentLength = response.contentLength;
        final tempFile = File(tempPath);
        final sink = tempFile.openWrite();

        int receivedBytes = 0;
        try {
          await for (final chunk in response) {
            sink.add(chunk);
            receivedBytes += chunk.length;
            if (contentLength > 0) {
              _progressController.add({id: receivedBytes / contentLength});
            }
          }
        } finally {
          await sink.close();
        }

        _progressController.add({id: 1.0});

        // Atomic rename on success
        final finalFile = File(finalPath);
        if (await finalFile.exists()) {
          try {
            await finalFile.delete();
          } catch (_) {}
        }
        await tempFile.rename(finalPath);
        return finalFile;
      } else {
        print('[FileTransferService] Server returned status: ${response.statusCode}');
      }
    } catch (e) {
      print('[FileTransferService] Download error: $e');
      // Clean up partial file
      try {
        final temp = File(tempPath);
        if (await temp.exists()) await temp.delete();
      } catch (_) {}
    } finally {
      httpClient.close();
    }
    return null;
  }

  void clearHostedFiles() {
    _hostedFiles.clear();
  }

  void dispose() {
    _progressController.close();
    _hostedFiles.clear();
  }
}