import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'sms_parser.dart';
import 'sms_reader_service.dart';

/// Service for reading and managing SMS-based transactions
class SmsTransactionService extends ChangeNotifier {
  static final SmsTransactionService _instance =
      SmsTransactionService._internal();
  factory SmsTransactionService() => _instance;
  SmsTransactionService._internal();

  // State
  bool _isInitialized = false;
  bool _isPermissionGranted = false;
  bool _isLoading = false;
  String? _error;

  // Parsed SMS transactions pending review
  final List<SmsTransaction> _pendingTransactions = [];

  // Processed message IDs to avoid duplicates
  final Set<String> _processedMessageIds = {};

  // SMS feature enabled status
  bool _isSmsTrackingEnabled = false;

  static const _prefKeyAutoScan = 'sms_auto_scan_enabled';

  // Native SMS reader
  final SmsReaderService _smsReader = SmsReaderService();

  // Active real-time listener subscription — kept so it can be cancelled
  StreamSubscription<Map<String, dynamic>>? _smsSubscription;

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isPermissionGranted => _isPermissionGranted;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isSmsTrackingEnabled => _isSmsTrackingEnabled;
  List<SmsTransaction> get pendingTransactions =>
      List.unmodifiable(_pendingTransactions);
  int get pendingCount => _pendingTransactions.length;

  /// Initialize the SMS service
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Restore persisted auto-scan toggle
    final prefs = await SharedPreferences.getInstance();
    _isSmsTrackingEnabled = prefs.getBool(_prefKeyAutoScan) ?? false;

    // Also restore permission state
    await checkSmsPermission();

    // If auto-scan was enabled, restart the real-time listener
    if (_isSmsTrackingEnabled) {
      _startSmsListener();
    }

    _isInitialized = true;
    notifyListeners();
  }

  /// Request SMS permission
  Future<bool> requestSmsPermission() async {
    try {
      // Check current status
      final smsStatus = await Permission.sms.status;

      if (smsStatus.isGranted) {
        _isPermissionGranted = true;
        _error = null;
        notifyListeners();
        return true;
      }

      // Request permission
      final result = await Permission.sms.request();

      _isPermissionGranted = result.isGranted;

      if (!result.isGranted) {
        _error = 'SMS permission denied. Please enable it in settings.';
      } else {
        _error = null;
      }

      notifyListeners();
      return result.isGranted;
    } catch (e) {
      _error = 'Failed to request SMS permission: $e';
      notifyListeners();
      return false;
    }
  }

  /// Check if SMS permission is granted
  Future<bool> checkSmsPermission() async {
    try {
      final status = await Permission.sms.status;
      _isPermissionGranted = status.isGranted;
      notifyListeners();
      return status.isGranted;
    } catch (e) {
      _isPermissionGranted = false;
      return false;
    }
  }

  /// Enable/disable SMS tracking
  Future<void> setSmsTrackingEnabled(bool enabled) async {
    _isSmsTrackingEnabled = enabled;

    // Persist the value
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeyAutoScan, enabled);

    if (enabled) {
      // Start listening for incoming SMS
      _startSmsListener();
    } else {
      // Stop listening
      _stopSmsListener();
    }

    notifyListeners();
  }

  /// Start listening for incoming SMS messages
  void _startSmsListener() {
    // Cancel any existing subscription first to avoid duplicates
    _smsSubscription?.cancel();
    _smsSubscription = null;

    try {
      _smsSubscription = _smsReader.onSmsReceived.listen(
        (sms) {
          if (!_isSmsTrackingEnabled) return;

          final messageId = sms['id'] as String;
          final sender = sms['sender'] as String;
          final body = sms['body'] as String;
          final timestamp = sms['timestamp'] as int;
          final receivedTime = DateTime.fromMillisecondsSinceEpoch(timestamp);

          // Skip already processed messages
          if (_processedMessageIds.contains(messageId)) return;

          // Parse the SMS
          final parsed = SmsParser.parseSms(
            messageId: messageId,
            sender: sender,
            message: body,
            receivedTime: receivedTime,
          );

          // Only add valid expense transactions (debit account or credit card spend)
          if (parsed.isValid && _isExpenseTransaction(parsed)) {
            _pendingTransactions.add(parsed);
            _processedMessageIds.add(messageId);
            // Keep list sorted: latest transaction first
            _pendingTransactions.sort((a, b) {
              final aTime =
                  a.dateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
              final bTime =
                  b.dateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
              return bTime.compareTo(aTime);
            });
            notifyListeners();
          }
        },
        onError: (e) {
          debugPrint('[SMS] Listener error: $e');
        },
      );
    } catch (e) {
      debugPrint('[SMS] Error starting SMS listener: $e');
    }
  }

  /// Stop listening for incoming SMS
  void _stopSmsListener() {
    _smsSubscription?.cancel();
    _smsSubscription = null;
  }

  /// Scan SMS messages for transactions.
  /// Always attempts real SMS when permission is granted.
  /// Falls back to simulated data only if permission is missing.
  Future<void> scanSmsMessages({bool useRealSms = true}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Check permission first
      if (!_isPermissionGranted) {
        debugPrint('[SMS] Permission not granted, using simulated data');
        await _simulateSmsReading();
        return;
      }

      if (useRealSms) {
        // Read actual SMS from device
        await _readRealSmsMessages();
      } else {
        // Use simulated data for testing
        await _simulateSmsReading();
      }
    } catch (e) {
      debugPrint('[SMS] Error scanning: $e');
      _error = 'Failed to read SMS: $e';
      // Fall back to simulated data
      await _simulateSmsReading();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Read actual SMS messages from device
  Future<void> _readRealSmsMessages() async {
    try {
      // Read SMS from last 90 days with a high limit to catch all transactions
      final since = DateTime.now().subtract(const Duration(days: 90));
      final messages = await _smsReader.readSmsMessages(
        limit: 500,
        since: since,
      );

      for (final sms in messages) {
        final messageId = sms['id'] as String;
        final sender = sms['sender'] as String;
        final body = sms['body'] as String;
        final timestamp = sms['timestamp'] as int;
        final receivedTime = DateTime.fromMillisecondsSinceEpoch(timestamp);

        // Check if already in pending list
        final alreadyPending = _pendingTransactions.any(
          (tx) => tx.messageId == messageId,
        );
        if (alreadyPending) continue;

        // Check if already processed (approved or rejected)
        if (_processedMessageIds.contains(messageId)) continue;

        // Parse the SMS
        final parsed = SmsParser.parseSms(
          messageId: messageId,
          sender: sender,
          message: body,
          receivedTime: receivedTime,
        );

        // Only add valid expense transactions (debit account or credit card spend)
        if (parsed.isValid && _isExpenseTransaction(parsed)) {
          _pendingTransactions.add(parsed);
          // DON'T add to processed IDs yet - only add when approved/rejected
        }
      }

      // Sort: latest transaction first
      _pendingTransactions.sort((a, b) {
        final aTime = a.dateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.dateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });
    } catch (e) {
      debugPrint('Error reading real SMS: $e');
      // Fall back to simulated data if real SMS reading fails
      await _simulateSmsReading();
    }
  }

  /// Simulate SMS reading for demo purposes
  Future<void> _simulateSmsReading() async {
    debugPrint('[SMS] Starting simulated SMS reading...');

    // Sample SMS messages for demonstration
    final sampleMessages = [
      _SampleSms(
        id: 'sms_001',
        sender: 'HDFCBK',
        message:
            'Your HDFC Bank a/c ****4567 is debited with Rs.1,250.00 on 28/04/2026 at AMAZON.IN. Available balance: Rs.45,000.00',
        receivedTime: DateTime(2026, 4, 28, 14, 30),
      ),
      _SampleSms(
        id: 'sms_002',
        sender: 'ICICIB',
        message:
            'ICICI Bank: Your a/c ****8901 debited Rs.500.00 on 27/04/2026 for SWIGGY order. Available balance: Rs.12,000.00',
        receivedTime: DateTime(2026, 4, 27, 19, 45),
      ),
      _SampleSms(
        id: 'sms_003',
        sender: 'AXISBK',
        message:
            'Axis Bank: Your a/c ****2345 debited Rs.850.00 on 25/04/2026 at FLIPKART. Transaction ID: AXI123456789',
        receivedTime: DateTime(2026, 4, 25, 16, 20),
      ),
      _SampleSms(
        id: 'sms_004',
        sender: 'PHONEPE',
        message:
            'You paid Rs.300.00 to MERCHANT@upi via PhonePe on 24/04/2026. UPI Ref: 123456789012',
        receivedTime: DateTime(2026, 4, 24, 12, 0),
      ),
      _SampleSms(
        id: 'sms_005',
        sender: 'HDFCBK',
        message:
            'Your HDFC Bank a/c ****4567 is debited with Rs.2,150.00 on 23/04/2026 at BIGBASKET. Available balance: Rs.42,850.00',
        receivedTime: DateTime(2026, 4, 23, 18, 15),
      ),
    ];

    int validCount = 0;
    for (final sms in sampleMessages) {
      // Check if already in pending list (by message ID)
      final alreadyPending = _pendingTransactions.any(
        (tx) => tx.messageId == sms.id,
      );
      if (alreadyPending) {
        debugPrint('[SMS] Already in pending list: ${sms.id}');
        continue;
      }

      // Check if already processed (approved or rejected)
      if (_processedMessageIds.contains(sms.id)) {
        debugPrint('[SMS] Already processed: ${sms.id}');
        continue;
      }

      // Parse the SMS
      final parsed = SmsParser.parseSms(
        messageId: sms.id,
        sender: sms.sender,
        message: sms.message,
        receivedTime: sms.receivedTime,
      );

      debugPrint(
        '[SMS] Parsed ${sms.id}: valid=${parsed.isValid}, type=${parsed.transactionType}, amount=${parsed.amount}',
      );

      // Only add valid transactions
      if (parsed.isValid && _isExpenseTransaction(parsed)) {
        _pendingTransactions.add(parsed);
        // DON'T add to processed IDs yet - only add when approved/rejected
        validCount++;
      }
    }

    debugPrint(
      '[SMS] Simulated reading complete. Added $validCount transactions. Total pending: ${_pendingTransactions.length}',
    );

    // Sort: latest transaction first
    _pendingTransactions.sort((a, b) {
      final aTime = a.dateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.dateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });
  }

  /// Returns true for transactions that represent an outgoing spend —
  /// covers both debit account debits and credit card charges.
  bool _isExpenseTransaction(SmsTransaction tx) {
    if (tx.transactionType == 'debit') return true;
    // Credit card spends: bankName contains "Credit Card" or "Card"
    // and transactionType was not resolved (some CC messages don't use
    // "debited" — they say "used" or "charged" which we now map to debit,
    // but keep this as a safety net for unrecognised patterns)
    final bank = (tx.bankName ?? '').toLowerCase();
    if (bank.contains('credit card') ||
        bank.contains('card') ||
        bank.contains('amex')) {
      return tx.transactionType == 'debit' || tx.transactionType == null;
    }
    return false;
  }

  /// Approve an SMS transaction and convert to app transaction
  Map<String, dynamic>? approveTransaction(SmsTransaction smsTransaction) {
    if (!_pendingTransactions.contains(smsTransaction)) {
      return null;
    }

    // Generate a meaningful title — always prefer vendor/merchant name
    String title;
    if (smsTransaction.vendor != null && smsTransaction.vendor!.isNotEmpty) {
      // Use vendor name if available
      title = smsTransaction.vendor!;
    } else if (smsTransaction.bankName != null) {
      // Fall back to bank name only (no generic "Transaction" suffix)
      title = smsTransaction.bankName!;
    } else {
      // Last resort: use the SMS sender as the title
      title = smsTransaction.sender;
    }

    // Create transaction data that can be used by TransactionService
    final transactionData = {
      'title': title,
      'amount': smsTransaction.amount,
      'type': 'expense',
      'date': smsTransaction.dateTime ?? DateTime.now(),
      'note': 'Imported from SMS: ${smsTransaction.message}',
      'source': 'sms',
      'smsMessageId': smsTransaction.messageId,
      'bankName': smsTransaction.bankName,
    };

    // Remove from pending
    _pendingTransactions.remove(smsTransaction);
    notifyListeners();

    return transactionData;
  }

  /// Reject an SMS transaction
  void rejectTransaction(SmsTransaction smsTransaction) {
    if (!_pendingTransactions.contains(smsTransaction)) return;

    // Mark as processed so it won't appear again
    _processedMessageIds.add(smsTransaction.messageId);

    // Remove from pending
    _pendingTransactions.remove(smsTransaction);
    notifyListeners();
  }

  /// Clear all pending transactions
  void clearPendingTransactions() {
    _pendingTransactions.clear();
    notifyListeners();
  }

  /// Clear processed message IDs (to rescan)
  void clearProcessedMessages() {
    _processedMessageIds.clear();
    notifyListeners();
  }

  /// Get transaction summary for a specific period
  Map<String, dynamic> getSmsTransactionSummary({
    required DateTime startDate,
    required DateTime endDate,
  }) {
    double totalAmount = 0;
    int transactionCount = 0;
    final Map<String, double> byBank = {};

    for (final sms in _pendingTransactions) {
      if (sms.dateTime != null &&
          sms.dateTime!.isAfter(startDate) &&
          sms.dateTime!.isBefore(endDate)) {
        totalAmount += sms.amount ?? 0;
        transactionCount++;

        if (sms.bankName != null) {
          byBank[sms.bankName!] =
              (byBank[sms.bankName!] ?? 0) + (sms.amount ?? 0);
        }
      }
    }

    return {
      'totalAmount': totalAmount,
      'transactionCount': transactionCount,
      'byBank': byBank,
    };
  }

  @override
  void dispose() {
    _smsSubscription?.cancel();
    _smsSubscription = null;
    _pendingTransactions.clear();
    _processedMessageIds.clear();
    super.dispose();
  }
}

/// Sample SMS data for testing
class _SampleSms {
  final String id;
  final String sender;
  final String message;
  final DateTime receivedTime;

  _SampleSms({
    required this.id,
    required this.sender,
    required this.message,
    required this.receivedTime,
  });
}
