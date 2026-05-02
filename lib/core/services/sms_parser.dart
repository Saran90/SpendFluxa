/// Represents a parsed SMS transaction
class SmsTransaction {
  final String messageId;
  final String sender;
  final String message;
  final double? amount;
  final String? accountUsed;
  final DateTime? dateTime;
  final String? vendor;
  final String? transactionType; // debit, credit, refund
  final String? bankName;
  final bool isValid;

  SmsTransaction({
    required this.messageId,
    required this.sender,
    required this.message,
    this.amount,
    this.accountUsed,
    this.dateTime,
    this.vendor,
    this.transactionType,
    this.bankName,
    this.isValid = false,
  });

  factory SmsTransaction.invalid(
    String messageId,
    String sender,
    String message,
  ) {
    return SmsTransaction(
      messageId: messageId,
      sender: sender,
      message: message,
      isValid: false,
    );
  }

  SmsTransaction copyWith({
    String? messageId,
    String? sender,
    String? message,
    double? amount,
    String? accountUsed,
    DateTime? dateTime,
    String? vendor,
    String? transactionType,
    String? bankName,
    bool? isValid,
  }) {
    return SmsTransaction(
      messageId: messageId ?? this.messageId,
      sender: sender ?? this.sender,
      message: message ?? this.message,
      amount: amount ?? this.amount,
      accountUsed: accountUsed ?? this.accountUsed,
      dateTime: dateTime ?? this.dateTime,
      vendor: vendor ?? this.vendor,
      transactionType: transactionType ?? this.transactionType,
      bankName: bankName ?? this.bankName,
      isValid: isValid ?? this.isValid,
    );
  }
}

/// Service for parsing SMS messages to extract transaction data
class SmsParser {
  // ── Shared patterns ───────────────────────────────────────────────────────

  static final _amountPattern = RegExp(
    r'(?:Rs\.?|INR)\s*([\d,]+\.?\d*)',
    caseSensitive: false,
  );

  static final _typePattern = RegExp(
    r'(debited|credited|spent|paid|sent|refund|transferred|used|charged)',
    caseSensitive: false,
  );

  // "credited to <name>" — money sent OUT to a named recipient
  static final _creditedToPattern = RegExp(
    r'credited\s+to\s+([^.;,\n]+?)(?:\s+(?:on|via|for|ref|upi)|[.;,])',
    caseSensitive: false,
  );

  // "<name> credited" — merchant name BEFORE "credited" in an expense SMS
  // Anchored after sentence-ending punctuation OR semicolon + whitespace.
  // e.g. "...on 19-Apr-26; REDBUS credited."
  //      "...Rs.500 debited. Swiggy credited."
  static final _xyzCreditedPattern = RegExp(
    r'[.!?;]\s+([A-Za-z][A-Za-z0-9&\-]*(?:\s+[A-Za-z][A-Za-z0-9&\-]*){0,3})\s+credited\b',
    caseSensitive: false,
  );

  // Noise words that must not be treated as merchant names
  static const _creditedNoise = {
    'your',
    'account',
    'a/c',
    'acct',
    'bank',
    'wallet',
    'amount',
    'rs',
    'inr',
    'the',
    'has',
    'been',
    'is',
    'will',
    'be',
  };

  static final _onlyDigits = RegExp(r'^\d+$');

  // Rejects strings containing a phone/ref number (6+ consecutive digits)
  static final _containsLongDigits = RegExp(r'\d{6,}');

  // Footer keywords — vendor extraction stops when these appear
  static final _footerKeywords = RegExp(
    r'\s+(?:on|via|avl|available|bal|balance|ref|upi|vpa|'
    r'call|contact|info|block|sms|please|kindly|transaction|txn|'
    r'helpline|customer|not\s+you)\b',
    caseSensitive: false,
  );

  // Hard sentence-end: dot followed by a space or end of string
  static final _sentenceEnd = RegExp(r'\.\s');

  // ── Vendor capture pattern ────────────────────────────────────────────────
  // Captures everything up to the first ; , or newline.
  // Dots are allowed (for AMAZON.IN). _cleanVendor strips trailing noise.
  static const _captureTillHard = r'([^;,\n]+)';

  // ── Bank / card patterns ──────────────────────────────────────────────────

  static final List<_BankPattern> _bankPatterns = [
    _BankPattern(
      bankName: 'HDFC Bank',
      sender: 'HDFCBK',
      accountPattern: RegExp(
        r'(?:a\/c|acct?)\s*[*xX\d]+',
        caseSensitive: false,
      ),
      vendorPattern: RegExp(r'at\s+' + _captureTillHard, caseSensitive: false),
    ),
    _BankPattern(
      bankName: 'HDFC Credit Card',
      sender: 'HDFCCC',
      accountPattern: RegExp(r'(?:card|cc)\s*[*xX\d]+', caseSensitive: false),
      vendorPattern: RegExp(r'at\s+' + _captureTillHard, caseSensitive: false),
    ),
    _BankPattern(
      bankName: 'ICICI Bank',
      sender: 'ICICIB',
      accountPattern: RegExp(
        r'(?:a\/c|acct?)\s*[*xX\d]+',
        caseSensitive: false,
      ),
      vendorPattern: RegExp(r'at\s+' + _captureTillHard, caseSensitive: false),
    ),
    _BankPattern(
      bankName: 'ICICI Credit Card',
      sender: 'ICICIC',
      accountPattern: RegExp(r'(?:card|cc)\s*[*xX\d]+', caseSensitive: false),
      vendorPattern: RegExp(r'at\s+' + _captureTillHard, caseSensitive: false),
    ),
    _BankPattern(
      bankName: 'SBI',
      sender: 'SBIBEN',
      accountPattern: RegExp(
        r'(?:a\/c|acct?)\s*[*xX\d]+',
        caseSensitive: false,
      ),
      vendorPattern: RegExp(r'at\s+' + _captureTillHard, caseSensitive: false),
    ),
    _BankPattern(
      bankName: 'SBI Card',
      sender: 'SBICARD',
      accountPattern: RegExp(r'(?:card|cc)\s*[*xX\d]+', caseSensitive: false),
      vendorPattern: RegExp(r'at\s+' + _captureTillHard, caseSensitive: false),
    ),
    _BankPattern(
      bankName: 'Axis Bank',
      sender: 'AXISBK',
      accountPattern: RegExp(
        r'(?:a\/c|acct?)\s*[*xX\d]+',
        caseSensitive: false,
      ),
      vendorPattern: RegExp(r'at\s+' + _captureTillHard, caseSensitive: false),
    ),
    _BankPattern(
      bankName: 'Axis Credit Card',
      sender: 'AXISCC',
      accountPattern: RegExp(r'(?:card|cc)\s*[*xX\d]+', caseSensitive: false),
      vendorPattern: RegExp(r'at\s+' + _captureTillHard, caseSensitive: false),
    ),
    _BankPattern(
      bankName: 'Yes Bank',
      sender: 'YESBNK',
      accountPattern: RegExp(
        r'(?:a\/c|acct?)\s*[*xX\d]+',
        caseSensitive: false,
      ),
      vendorPattern: RegExp(r'at\s+' + _captureTillHard, caseSensitive: false),
    ),
    _BankPattern(
      bankName: 'Kotak Bank',
      sender: 'KOTAKB',
      accountPattern: RegExp(
        r'(?:a\/c|acct?)\s*[*xX\d]+',
        caseSensitive: false,
      ),
      vendorPattern: RegExp(r'at\s+' + _captureTillHard, caseSensitive: false),
    ),
    _BankPattern(
      bankName: 'Kotak Credit Card',
      sender: 'KOTAKCC',
      accountPattern: RegExp(r'(?:card|cc)\s*[*xX\d]+', caseSensitive: false),
      vendorPattern: RegExp(r'at\s+' + _captureTillHard, caseSensitive: false),
    ),
    _BankPattern(
      bankName: 'IndusInd Bank',
      sender: 'INDUSB',
      accountPattern: RegExp(
        r'(?:a\/c|acct?)\s*[*xX\d]+',
        caseSensitive: false,
      ),
      vendorPattern: RegExp(r'at\s+' + _captureTillHard, caseSensitive: false),
    ),
    _BankPattern(
      bankName: 'IndusInd Credit Card',
      sender: 'INDUSCC',
      accountPattern: RegExp(r'(?:card|cc)\s*[*xX\d]+', caseSensitive: false),
      vendorPattern: RegExp(r'at\s+' + _captureTillHard, caseSensitive: false),
    ),
    _BankPattern(
      bankName: 'IDBI Bank',
      sender: 'IDBIBK',
      accountPattern: RegExp(
        r'(?:a\/c|acct?)\s*[*xX\d]+',
        caseSensitive: false,
      ),
      vendorPattern: RegExp(r'at\s+' + _captureTillHard, caseSensitive: false),
    ),
    _BankPattern(
      bankName: 'PNB',
      sender: 'PNBBKS',
      accountPattern: RegExp(
        r'(?:a\/c|acct?)\s*[*xX\d]+',
        caseSensitive: false,
      ),
      vendorPattern: RegExp(r'at\s+' + _captureTillHard, caseSensitive: false),
    ),
    _BankPattern(
      bankName: 'Canara Bank',
      sender: 'CNRBKS',
      accountPattern: RegExp(
        r'(?:a\/c|acct?)\s*[*xX\d]+',
        caseSensitive: false,
      ),
      vendorPattern: RegExp(r'at\s+' + _captureTillHard, caseSensitive: false),
    ),
    _BankPattern(
      bankName: 'Federal Bank',
      sender: 'FEDBNK',
      accountPattern: RegExp(
        r'(?:a\/c|acct?)\s*[*xX\d]+',
        caseSensitive: false,
      ),
      vendorPattern: RegExp(r'to\s+([^.;,\n]+)', caseSensitive: false),
    ),
    _BankPattern(
      bankName: 'Amex',
      sender: 'AMEXIN',
      accountPattern: RegExp(
        r'(?:card|cc|ending)\s*[*xX\d]+',
        caseSensitive: false,
      ),
      vendorPattern: RegExp(r'at\s+' + _captureTillHard, caseSensitive: false),
    ),
    _BankPattern(
      bankName: 'UPI',
      sender: 'UPI',
      accountPattern: RegExp(r'@[\w]+'),
      vendorPattern: RegExp(
        r'(?:to|to\/from)\s+([^.;,\n]+)',
        caseSensitive: false,
      ),
    ),
    _BankPattern(
      bankName: 'PhonePe',
      sender: 'PHONEPE',
      accountPattern: RegExp(r'@[\w]+'),
      vendorPattern: RegExp(r'to\s+([^.;,\n]+)', caseSensitive: false),
    ),
    _BankPattern(
      bankName: 'Google Pay',
      sender: 'GPAY',
      accountPattern: RegExp(r'@[\w]+'),
      vendorPattern: RegExp(r'to\s+([^.;,\n]+)', caseSensitive: false),
    ),
    _BankPattern(
      bankName: 'Paytm',
      sender: 'PAYTMBK',
      accountPattern: RegExp(r'@[\w]+'),
      vendorPattern: RegExp(r'to\s+([^.;,\n]+)', caseSensitive: false),
    ),
  ];

  // ── Public parse entry point ──────────────────────────────────────────────

  static SmsTransaction parseSms({
    required String messageId,
    required String sender,
    required String message,
    DateTime? receivedTime,
  }) {
    // 1. Find matching bank/card pattern by sender ID
    _BankPattern? matched;
    for (final p in _bankPatterns) {
      if (sender.toUpperCase().contains(p.sender) ||
          (p.sender == 'UPI' && _isUpiMessage(message))) {
        matched = p;
        break;
      }
    }

    // 2. Generic credit-card fallback
    if (matched == null && _isCreditCardMessage(message)) {
      matched = _BankPattern(
        bankName: _inferBankName(sender),
        sender: sender.toUpperCase(),
        accountPattern: RegExp(
          r'(?:card|cc|ending)\s*[*xX\d]+',
          caseSensitive: false,
        ),
        vendorPattern: RegExp(
          r'at\s+' + _captureTillHard,
          caseSensitive: false,
        ),
      );
    }

    // 3. Generic debit fallback — catches any bank SMS with a debit keyword
    //    even if the sender ID isn't in our known list (e.g. SBIINB, FedBnk)
    if (matched == null && _isDebitMessage(message)) {
      matched = _BankPattern(
        bankName: _inferBankName(sender),
        sender: sender.toUpperCase(),
        accountPattern: RegExp(
          r'(?:a\/c|acct?|card|cc)\s*[*xX\d]+',
          caseSensitive: false,
        ),
        vendorPattern: RegExp(
          r'(?:at|to)\s+' + _captureTillHard,
          caseSensitive: false,
        ),
      );
    }

    if (matched == null) {
      return SmsTransaction.invalid(messageId, sender, message);
    }

    // ── Amount ──────────────────────────────────────────────────────────────
    double? amount;
    final am = _amountPattern.firstMatch(message);
    if (am != null) {
      amount = double.tryParse(am.group(1)!.replaceAll(',', ''));
    }
    if (amount == null || amount <= 0) {
      return SmsTransaction.invalid(messageId, sender, message);
    }

    // ── Account / card hint ─────────────────────────────────────────────────
    String? account = matched.accountPattern.firstMatch(message)?.group(0);
    account ??= RegExp(
      r'(?:ending|card)\s+(?:in\s+)?([*xX\d]{4,})',
      caseSensitive: false,
    ).firstMatch(message)?.group(0);

    // ── Transaction type ────────────────────────────────────────────────────
    //
    // Priority:
    //   A. "credited to <name>"  → debit (outgoing transfer); name = vendor
    //   B. "<name> credited"     → name = vendor candidate; type from other kw
    //   C. Plain keyword         → standard debit / credit / refund

    String? transactionType;
    String? vendorCandidate;

    // A. "credited to <name>"
    final ctMatch = _creditedToPattern.firstMatch(message);
    if (ctMatch != null) {
      transactionType = 'debit';
      vendorCandidate = ctMatch.group(1)?.trim();
    }

    // B. "<name> credited" — scan all sentence/semicolon-anchored occurrences
    String? xyzName;
    for (final m in _xyzCreditedPattern.allMatches(message)) {
      final raw = (m.group(1) ?? '').trim();
      final lower = raw.toLowerCase();
      if (raw.length >= 2 &&
          !_creditedNoise.contains(lower) &&
          !_onlyDigits.hasMatch(raw) &&
          !_containsLongDigits.hasMatch(raw)) {
        xyzName = raw;
        break;
      }
    }

    // C. Plain keyword match (only if A didn't already set the type)
    if (transactionType == null) {
      final tm = _typePattern.firstMatch(message);
      if (tm != null) {
        final t = tm.group(1)!.toLowerCase();
        if (t == 'debited' ||
            t == 'spent' ||
            t == 'paid' ||
            t == 'sent' ||
            t == 'transferred' ||
            t == 'used' ||
            t == 'charged') {
          transactionType = 'debit';
        } else if (t == 'credited' || t == 'received') {
          transactionType = 'credit';
        } else if (t == 'refund') {
          transactionType = 'refund';
        }
      }
    }

    // Apply B result only when the message is confirmed as an expense
    if (transactionType == 'debit' &&
        xyzName != null &&
        vendorCandidate == null) {
      vendorCandidate = xyzName;
    }

    // ── Vendor extraction ───────────────────────────────────────────────────
    // Priority: A/B candidate → bank-specific pattern → generic fallbacks
    // Patterns capture greedily up to ; , or \n.
    // _cleanVendor() trims at the first ". " sentence boundary and strips
    // trailing footer words.

    String? vendor = vendorCandidate;

    if (vendor == null || vendor.isEmpty) {
      vendor = matched.vendorPattern.firstMatch(message)?.group(1)?.trim();
    }

    if (vendor == null || vendor.isEmpty) {
      final fallbacks = [
        RegExp(
          r'(?:used|charged)\s+at\s+' + _captureTillHard,
          caseSensitive: false,
        ),
        RegExp(
          r'(?:paid|sent|transferred)\s+(?:to|at)\s+' + _captureTillHard,
          caseSensitive: false,
        ),
        RegExp(
          r'(?:debited|spent)\s+(?:at|to)\s+' + _captureTillHard,
          caseSensitive: false,
        ),
        RegExp(r'\bat\s+' + _captureTillHard, caseSensitive: false),
        RegExp(r'\bto\s+([A-Za-z][^;,\n]+)', caseSensitive: false),
        RegExp(r'\bfor\s+([A-Za-z][^;,\n]+)', caseSensitive: false),
      ];
      for (final p in fallbacks) {
        final extracted = p.firstMatch(message)?.group(1)?.trim();
        if (extracted != null && extracted.length > 2) {
          vendor = extracted;
          break;
        }
      }
    }

    // ── Clean up vendor ─────────────────────────────────────────────────────
    if (vendor != null) {
      vendor = _cleanVendor(vendor);
    }

    // ── Date extraction ─────────────────────────────────────────────────────
    DateTime? dateTime = receivedTime;
    final datePatterns = [
      RegExp(r'on\s+(\d{1,2})\/(\d{1,2})\/(\d{4})', caseSensitive: false),
      RegExp(r'on\s+(\d{1,2})-(\d{1,2})-(\d{4})', caseSensitive: false),
      RegExp(
        r'on\s+(\d{1,2})\s+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+(\d{4})',
        caseSensitive: false,
      ),
      RegExp(
        r'on\s+(\d{1,2})-(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*-(\d{2,4})',
        caseSensitive: false,
      ),
    ];
    for (final p in datePatterns) {
      final m = p.firstMatch(message);
      if (m != null) {
        try {
          final monthStr = m.group(2)!;
          final month = int.tryParse(monthStr) ?? _monthFromName(monthStr);
          final year = int.parse(m.group(3)!);
          dateTime = DateTime(
            year < 100 ? 2000 + year : year,
            month,
            int.parse(m.group(1)!),
          );
        } catch (_) {}
        break;
      }
    }

    return SmsTransaction(
      messageId: messageId,
      sender: sender,
      message: message,
      amount: amount,
      accountUsed: account,
      dateTime: dateTime ?? receivedTime,
      vendor: vendor,
      transactionType: transactionType,
      bankName: matched.bankName,
      isValid: amount > 0,
    );
  }

  // ── Vendor cleanup ────────────────────────────────────────────────────────

  /// Cleans a raw vendor string:
  /// 1. Strips at the first ". " (sentence boundary) — preserves "AMAZON.IN"
  ///    since that has no space after the dot
  /// 2. Strips UPI handles
  /// 3. Strips trailing footer keywords
  /// 4. Strips trailing noise words
  /// 5. Capitalizes
  /// Returns null if result is too short or contains a long digit run.
  static String? _cleanVendor(String raw) {
    var v = raw.trim();

    // 1. Cut at first ". " (dot + space = sentence end)
    final sentenceMatch = _sentenceEnd.firstMatch(v);
    if (sentenceMatch != null) {
      v = v.substring(0, sentenceMatch.start).trim();
    }

    // 2. Strip UPI handles (e.g. "Rahul Kumar@okaxis" → "Rahul Kumar")
    v = v.replaceAll(RegExp(r'@\S+'), '').trim();

    // 3. Strip everything from the first footer keyword onwards
    final footerMatch = _footerKeywords.firstMatch(v);
    if (footerMatch != null) {
      v = v.substring(0, footerMatch.start).trim();
    }

    // 4. Remove trailing noise words
    v = v
        .replaceAll(
          RegExp(
            r'\s+(order|transaction|payment|purchase|transfer|ref|upi|vpa)$',
            caseSensitive: false,
          ),
          '',
        )
        .trim();

    // 5. Capitalize properly
    if (v.isNotEmpty) {
      v = v
          .split(RegExp(r'[\s_]+'))
          .map((w) {
            if (w.isEmpty) return w;
            return w[0].toUpperCase() + w.substring(1).toLowerCase();
          })
          .join(' ')
          .trim();
    }

    // Discard if too short, pure digits, or contains a phone/ref number
    if (v.length < 2 ||
        _onlyDigits.hasMatch(v) ||
        _containsLongDigits.hasMatch(v)) {
      return null;
    }

    return v;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static int _monthFromName(String name) {
    const months = {
      'jan': 1,
      'feb': 2,
      'mar': 3,
      'apr': 4,
      'may': 5,
      'jun': 6,
      'jul': 7,
      'aug': 8,
      'sep': 9,
      'oct': 10,
      'nov': 11,
      'dec': 12,
    };
    return months[name.toLowerCase().substring(0, 3)] ?? 1;
  }

  static bool _isDebitMessage(String message) {
    final hasAmount = RegExp(
      r'(?:Rs\.?|INR)\s*[\d,]+',
      caseSensitive: false,
    ).hasMatch(message);
    final hasDebitKeyword = RegExp(
      r'\b(debited|spent|paid|sent|transferred|used|charged)\b',
      caseSensitive: false,
    ).hasMatch(message);
    return hasAmount && hasDebitKeyword;
  }

  static bool _isCreditCardMessage(String message) {
    return [
      RegExp(r'credit\s*card', caseSensitive: false),
      RegExp(r'\bCC\b'),
      RegExp(r'card\s+(?:ending|no\.?|number)', caseSensitive: false),
      RegExp(r'(?:used|charged)\s+(?:at|for)', caseSensitive: false),
      RegExp(
        r'(?:Rs\.?|INR)\s*[\d,]+.*(?:used|charged|spent)',
        caseSensitive: false,
      ),
    ].any((p) => p.hasMatch(message));
  }

  static String _inferBankName(String sender) {
    final s = sender.toUpperCase();
    if (s.contains('HDFC')) return 'HDFC Bank';
    if (s.contains('ICICI')) return 'ICICI Bank';
    if (s.contains('SBI')) return 'SBI';
    if (s.contains('AXIS')) return 'Axis Bank';
    if (s.contains('KOTAK')) return 'Kotak Bank';
    if (s.contains('INDUS')) return 'IndusInd Bank';
    if (s.contains('AMEX')) return 'Amex';
    if (s.contains('CITI')) return 'Citi Bank';
    if (s.contains('HSBC')) return 'HSBC Bank';
    if (s.contains('RBL')) return 'RBL Bank';
    if (s.contains('YES')) return 'Yes Bank';
    if (s.contains('BOB')) return 'Bank of Baroda';
    if (s.contains('FED')) return 'Federal Bank';
    if (s.contains('SC') || s.contains('STANC')) return 'Standard Chartered';
    return 'Bank';
  }

  static bool _isUpiMessage(String message) {
    return [
      RegExp(r'UPI', caseSensitive: false),
      RegExp(r'@[\w]+'),
      RegExp(r'paid\s+Rs', caseSensitive: false),
      RegExp(r'received\s+Rs', caseSensitive: false),
    ].any((p) => p.hasMatch(message));
  }

  static List<String> get supportedSenders =>
      _bankPatterns.map((p) => p.sender).toList();
}

class _BankPattern {
  final String bankName;
  final String sender;
  final RegExp accountPattern;
  final RegExp vendorPattern;

  _BankPattern({
    required this.bankName,
    required this.sender,
    required this.accountPattern,
    required this.vendorPattern,
  });
}
