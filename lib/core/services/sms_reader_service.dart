import 'dart:async';
import 'package:flutter/services.dart';

/// Native SMS reader service using platform channels
class SmsReaderService {
  static const MethodChannel _channel = MethodChannel('com.spendflux/sms');

  // Singleton stream so we never create more than one EventChannel subscription
  static final Stream<Map<String, dynamic>> _smsStream =
      EventChannel('com.spendflux/sms_stream').receiveBroadcastStream().map((
        event,
      ) {
        final map = Map<String, dynamic>.from(event as Map);
        return {
          'id': map['id'] as String,
          'sender': map['sender'] as String,
          'body': map['body'] as String,
          'timestamp': map['timestamp'] as int,
        };
      });

  /// Read SMS messages from the device
  Future<List<Map<String, dynamic>>> readSmsMessages({
    int? limit,
    DateTime? since,
  }) async {
    try {
      final Map<String, dynamic> args = {};
      if (limit != null) args['limit'] = limit;
      if (since != null) args['since'] = since.millisecondsSinceEpoch;

      final List<dynamic>? result = await _channel.invokeMethod(
        'readSms',
        args.isNotEmpty ? args : null,
      );

      if (result == null) return [];

      return result.map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        return {
          'id': map['id'] as String,
          'sender': map['sender'] as String,
          'body': map['body'] as String,
          'timestamp': map['timestamp'] as int,
        };
      }).toList();
    } on PlatformException catch (e) {
      throw Exception('Failed to read SMS: ${e.message}');
    }
  }

  /// Broadcast stream of incoming SMS messages.
  /// Uses a single shared EventChannel stream — safe to listen/cancel repeatedly.
  Stream<Map<String, dynamic>> get onSmsReceived => _smsStream;
}
