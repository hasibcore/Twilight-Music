import 'package:flutter/foundation.dart';

enum StreamLogSeverity { info, warn, error }

class StreamDiagnosticEvent {
  final DateTime timestamp;
  final StreamLogSeverity severity;
  final String category;
  final String stage;
  final String message;
  final String? songId;
  final int? statusCode;
  final int? attempt;
  final int? bytePosition;
  final String? detail;

  const StreamDiagnosticEvent({
    required this.timestamp,
    required this.severity,
    required this.category,
    required this.stage,
    required this.message,
    this.songId,
    this.statusCode,
    this.attempt,
    this.bytePosition,
    this.detail,
  });

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'severity': severity.name,
        'category': category,
        'stage': stage,
        'message': message,
        if (songId != null) 'songId': songId,
        if (statusCode != null) 'statusCode': statusCode,
        if (attempt != null) 'attempt': attempt,
        if (bytePosition != null) 'bytePosition': bytePosition,
        if (detail != null) 'detail': detail,
      };
}

class AppLogger {
  AppLogger._();

  static const int _maxHistory = 150;
  static final List<StreamDiagnosticEvent> _streamHistory = [];

  static void info(String message) {
    debugPrint('[Twilight INFO]: $message');
  }

  static void warning(String message) {
    debugPrint('[Twilight WARN]: $message');
  }

  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    debugPrint('[Twilight ERROR]: $message | Error: $error');
    if (stackTrace != null) {
      debugPrint(stackTrace.toString());
    }
  }

  static StreamDiagnosticEvent streamEvent(
    StreamLogSeverity severity,
    String category,
    String stage,
    String message, {
    String? songId,
    int? statusCode,
    int? attempt,
    int? bytePosition,
    String? detail,
  }) {
    final ev = StreamDiagnosticEvent(
      timestamp: DateTime.now(),
      severity: severity,
      category: category,
      stage: stage,
      message: message,
      songId: songId,
      statusCode: statusCode,
      attempt: attempt,
      bytePosition: bytePosition,
      detail: detail,
    );
    _streamHistory.add(ev);
    if (_streamHistory.length > _maxHistory) {
      _streamHistory.removeAt(0);
    }

    final ctx = <String>[
      if (songId != null && songId.isNotEmpty) 'id=$songId',
      if (statusCode != null) 'status=$statusCode',
      if (attempt != null) 'attempt=$attempt',
      if (bytePosition != null) 'byte=$bytePosition',
    ];
    final suffix = ctx.isNotEmpty ? ' (${ctx.join(', ')})' : '';
    final detailStr = (detail != null && detail.isNotEmpty) ? ' | $detail' : '';
    debugPrint('[Twilight STREAM][${severity.name.toUpperCase()}][$category][$stage]: $message$suffix$detailStr');
    return ev;
  }

  static StreamDiagnosticEvent networkDisconnect(
    String stage,
    String message, {
    StreamLogSeverity severity = StreamLogSeverity.warn,
    String category = 'network_disconnect',
    String? songId,
    int? statusCode,
    int? attempt,
    int? bytePosition,
    Object? error,
  }) {
    return streamEvent(
      severity,
      category,
      stage,
      message,
      songId: songId,
      statusCode: statusCode,
      attempt: attempt,
      bytePosition: bytePosition,
      detail: error?.toString(),
    );
  }

  static List<StreamDiagnosticEvent> getRecentStreamEvents({int limit = 50}) {
    if (_streamHistory.isEmpty) return const [];
    final start = _streamHistory.length > limit ? _streamHistory.length - limit : 0;
    return List.unmodifiable(_streamHistory.sublist(start));
  }

  static int getDisconnectCount() {
    return _streamHistory
        .where((e) =>
            e.category.contains('disconnect') ||
            e.category == 'stall' ||
            e.category == 'player_error')
        .length;
  }

  static Map<String, dynamic> exportDiagnosticSummary() {
    return {
      'totalEvents': _streamHistory.length,
      'disconnectCount': getDisconnectCount(),
      'recentEvents': getRecentStreamEvents(limit: 30).map((e) => e.toJson()).toList(),
    };
  }

  static void clearDiagnostics() {
    _streamHistory.clear();
  }
}
