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
      return Response.ok(
        file.openRead(),
        headers: {
          'Content-Length': stat.size.toString(),
          'Content-Type': 'application/octet-stream',
          'Content-Disposition':
              'attachment; filename="${file.uri.pathSegments.last}"',
        },
      );
    });
  }

  /// Downloads a file from the remote host.
  ///
  /// Bug #3 fix: writes to a `.tmp` file and renames on success. If the
  /// download fails at any point (network drop, server error, mid-stream
  /// exception) the partial temp file is deleted so no garbage accumulates.
  Future<File?> downloadFile({
    required String ip,
    required int port,
    required String id,
    required String fileName,
    required String saveDirectory,
  }) async {
    final url      = Uri.parse('http://$ip:$port/download/$id');
    final client   = HttpClient();
    final tempPath = '$saveDirectory/$fileName.tmp';
    final finalPath = '$saveDirectory/$fileName';
    File? tempFile;

    try {
      final request  = await client.getUrl(url);
      final response = await request.close();

      if (response.statusCode != 200) {
        print('[FileTransferService] Server returned ${response.statusCode}');
        return null;
      }

      final contentLength = response.contentLength;
      tempFile = File(tempPath);
      final sink = tempFile.openWrite();

      try {
        int received = 0;
        await for (final chunk in response) {
          sink.add(chunk);
          received += chunk.length;
          if (contentLength > 0) {
            _progressController.add({id: received / contentLength});
          }
        }
        await sink.close();

        // Atomic-ish: rename temp → final path.
        final saved = await tempFile.rename(finalPath);
        _progressController.add({id: 1.0});
        return saved;
      } catch (e) {
        await sink.close();
        // Clean up the partial file so the user doesn't see corrupt data.
        if (await tempFile.exists()) await tempFile.delete();
        print('[FileTransferService] Download interrupted: $e');
        return null;
      }
    } catch (e) {
      print('[FileTransferService] Download error: $e');
      if (tempFile != null && await tempFile.exists()) {
        await tempFile.delete();
      }
      return null;
    } finally {
      client.close();
    }
  }

  void clearHostedFiles() => _hostedFiles.clear();

  void dispose() {
    _progressController.close();
    _hostedFiles.clear();
  }
}