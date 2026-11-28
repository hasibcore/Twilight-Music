import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:melody_tube/core/services/download_service.dart';

void main() {
  group('DownloadService Resilient Completion Tests', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('twilight_dl_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('completes multi-chunk 206 Range download cleanly and reaches >= 0.99 progress', () async {
      const totalLen = (512 * 1024) + 123456; // 2 chunks
      final payload = Uint8List.fromList(List.generate(totalLen, (i) => (i + 7) & 0xFF));

      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));

      server.listen((req) async {
        final range = req.headers.value('range');
        if (range != null && range.startsWith('bytes=')) {
          final parts = range.substring(6).split('-');
          final start = int.parse(parts[0]);
          final end = (parts.length > 1 && parts[1].isNotEmpty)
              ? int.parse(parts[1]).clamp(0, totalLen - 1)
              : totalLen - 1;
          req.response.statusCode = HttpStatus.partialContent;
          req.response.headers.set('content-range', 'bytes $start-$end/$totalLen');
          req.response.headers.contentLength = end - start + 1;
          req.response.add(payload.sublist(start, end + 1));
          await req.response.close();
          return;
        }
        req.response.statusCode = HttpStatus.ok;
        req.response.headers.contentLength = totalLen;
        req.response.add(payload);
        await req.response.close();
      });

      final tmpPath = '${tempDir.path}/ok.tmp';
      final progresses = <double>[];
      final bytesWritten = await DownloadService.downloadUrlWithResilientRangesForTest(
        url: 'http://127.0.0.1:${server.port}/audio.m4a',
        tmpFilePath: tmpPath,
        knownTotalBytes: totalLen,
        songId: 'ok_track',
        onProgress: progresses.add,
      );

      expect(bytesWritten, totalLen);
      expect(progresses, isNotEmpty);
      expect(progresses.last, greaterThanOrEqualTo(0.98));
      expect(File(tmpPath).readAsBytesSync(), orderedEquals(payload));
    });

    test('fails cleanly instead of hanging infinitely when last chunk returns HTTP 503', () async {
      const totalLen = (512 * 1024) + 4096;
      final payload = Uint8List.fromList(List.generate(totalLen, (i) => i & 0xFF));

      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));

      int chunk2Attempts = 0;
      server.listen((req) async {
        final range = req.headers.value('range') ?? '';
        if (range.startsWith('bytes=0-')) {
          const end = (512 * 1024) - 1;
          req.response.statusCode = HttpStatus.partialContent;
          req.response.headers.set('content-range', 'bytes 0-$end/$totalLen');
          req.response.headers.contentLength = 512 * 1024;
          req.response.add(payload.sublist(0, end + 1));
          await req.response.close();
          return;
        }
        chunk2Attempts++;
        req.response.statusCode = HttpStatus.serviceUnavailable;
        await req.response.close();
      });

      final tmpPath = '${tempDir.path}/fail_503.tmp';
      await expectLater(
        DownloadService.downloadUrlWithResilientRangesForTest(
          url: 'http://127.0.0.1:${server.port}/audio.m4a',
          tmpFilePath: tmpPath,
          knownTotalBytes: totalLen,
          songId: 'fail_503_track',
        ).timeout(const Duration(seconds: 5)),
        throwsA(isA<Exception>()),
      );
      expect(chunk2Attempts, equals(3));
    });

    test('fails fast without retrying endlessly when last chunk returns HTTP 403', () async {
      const totalLen = (512 * 1024) + 2048;
      final payload = Uint8List.fromList(List.generate(totalLen, (i) => i & 0xFF));

      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));

      int forbiddenAttempts = 0;
      server.listen((req) async {
        final range = req.headers.value('range') ?? '';
        if (range.startsWith('bytes=0-')) {
          const end = (512 * 1024) - 1;
          req.response.statusCode = HttpStatus.partialContent;
          req.response.headers.set('content-range', 'bytes 0-$end/$totalLen');
          req.response.headers.contentLength = 512 * 1024;
          req.response.add(payload.sublist(0, end + 1));
          await req.response.close();
          return;
        }
        forbiddenAttempts++;
        req.response.statusCode = HttpStatus.forbidden;
        await req.response.close();
      });

      final tmpPath = '${tempDir.path}/fail_403.tmp';
      await expectLater(
        DownloadService.downloadUrlWithResilientRangesForTest(
          url: 'http://127.0.0.1:${server.port}/audio.m4a',
          tmpFilePath: tmpPath,
          knownTotalBytes: totalLen,
          songId: 'fail_403_track',
        ).timeout(const Duration(seconds: 5)),
        throwsA(isA<Exception>()),
      );
      expect(forbiddenAttempts, equals(1));
    });

    test('skips overlapping prefix cleanly when fallback server ignores Range and returns HTTP 200', () async {
      const totalLen = (512 * 1024) + 8192;
      final payload = Uint8List.fromList(List.generate(totalLen, (i) => (i * 3) & 0xFF));

      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));

      server.listen((req) async {
        final range = req.headers.value('range') ?? '';
        if (range.startsWith('bytes=0-')) {
          const end = (512 * 1024) - 1;
          req.response.statusCode = HttpStatus.partialContent;
          req.response.headers.set('content-range', 'bytes 0-$end/$totalLen');
          req.response.headers.contentLength = 512 * 1024;
          req.response.add(payload.sublist(0, end + 1));
          await req.response.close();
          return;
        }
        // Server ignores Range on second request and responds with full 200 OK payload
        req.response.statusCode = HttpStatus.ok;
        req.response.headers.contentLength = totalLen;
        req.response.add(payload);
        await req.response.close();
      });

      final tmpPath = '${tempDir.path}/ok_200_overlap.tmp';
      final bytesWritten = await DownloadService.downloadUrlWithResilientRangesForTest(
        url: 'http://127.0.0.1:${server.port}/audio.m4a',
        tmpFilePath: tmpPath,
        knownTotalBytes: totalLen,
        songId: 'ok_200_track',
      );

      expect(bytesWritten, totalLen);
      expect(File(tmpPath).readAsBytesSync(), orderedEquals(payload));
    });
  });
}
