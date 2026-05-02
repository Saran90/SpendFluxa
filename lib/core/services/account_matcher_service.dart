import '../models/account.dart';

/// Service for matching SMS account information with app accounts
class AccountMatcherService {
  /// Match an SMS transaction to an app account
  ///
  /// Matching logic:
  /// 1. Match by last 4 digits (if available)
  /// 2. Match by bank name + account type
  /// 3. Match by bank name only
  /// 4. Return default account
  static Account? matchAccount({
    required List<Account> accounts,
    String? bankName,
    String? accountUsed, // e.g., "a/c ****4567" or "@upi"
  }) {
    if (accounts.isEmpty) return null;

    // Extract last 4 digits from accountUsed
    final last4Digits = _extractLast4Digits(accountUsed);

    // Priority 1: Match by last 4 digits
    if (last4Digits != null) {
      final matchByDigits = accounts.firstWhere(
        (acc) => acc.lastFourDigits == last4Digits,
        orElse: () => accounts.first,
      );
      if (matchByDigits.lastFourDigits == last4Digits) {
        return matchByDigits;
      }
    }

    // Priority 2: Match by bank name + account type
    if (bankName != null) {
      final accountType = _inferAccountType(bankName, accountUsed);
      final matchByBankAndType = accounts.firstWhere(
        (acc) =>
            _accountMatchesBankName(acc, bankName) && acc.type == accountType,
        orElse: () => accounts.first,
      );
      if (_accountMatchesBankName(matchByBankAndType, bankName) &&
          matchByBankAndType.type == accountType) {
        return matchByBankAndType;
      }
    }

    // Priority 3: Match by bank name only
    if (bankName != null) {
      final matchByBank = accounts.firstWhere(
        (acc) => _accountMatchesBankName(acc, bankName),
        orElse: () => accounts.first,
      );
      if (_accountMatchesBankName(matchByBank, bankName)) {
        return matchByBank;
      }
    }

    // Priority 4: Return default account
    final defaultAccount = accounts.firstWhere(
      (acc) => acc.isDefault,
      orElse: () => accounts.first,
    );
    return defaultAccount;
  }

  /// Extract last 4 digits from account string
  /// Examples: "a/c ****4567" -> "4567", "****1234" -> "1234"
  static String? _extractLast4Digits(String? accountUsed) {
    if (accountUsed == null) return null;

    // Pattern to match last 4 digits after asterisks
    final regex = RegExp(r'\*+(\d{4})');
    final match = regex.firstMatch(accountUsed);

    if (match != null && match.groupCount >= 1) {
      return match.group(1);
    }

    // Try to find any 4 consecutive digits
    final digitsRegex = RegExp(r'\d{4}');
    final digitsMatch = digitsRegex.firstMatch(accountUsed);

    return digitsMatch?.group(0);
  }

  /// Check if account name matches bank name
  static bool _accountMatchesBankName(Account account, String bankName) {
    final accountNameLower = account.name.toLowerCase();
    final bankNameLower = bankName.toLowerCase();

    // Direct match
    if (accountNameLower.contains(bankNameLower)) {
      return true;
    }

    // Bank name abbreviations and variations
    final bankMappings = {
      'hdfc': ['hdfc', 'hdfc bank'],
      'icici': ['icici', 'icici bank'],
      'sbi': ['sbi', 'state bank', 'state bank of india'],
      'axis': ['axis', 'axis bank'],
      'yes': ['yes', 'yes bank'],
      'kotak': ['kotak', 'kotak mahindra', 'kotak bank'],
      'indusind': ['indusind', 'indusind bank'],
      'idbi': ['idbi', 'idbi bank'],
      'pnb': ['pnb', 'punjab national', 'punjab national bank'],
      'canara': ['canara', 'canara bank'],
      'phonepe': ['phonepe', 'phone pe', 'wallet'],
      'paytm': ['paytm', 'paytm wallet', 'wallet'],
      'gpay': ['gpay', 'google pay', 'googlepay', 'wallet'],
      'upi': ['upi', 'wallet'],
    };

    // Check if bank name matches any mapping
    for (final entry in bankMappings.entries) {
      if (bankNameLower.contains(entry.key)) {
        for (final variant in entry.value) {
          if (accountNameLower.contains(variant)) {
            return true;
          }
        }
      }
    }

    return false;
  }

  /// Infer account type from bank name and account string
  static AccountType _inferAccountType(String bankName, String? accountUsed) {
    final bankNameLower = bankName.toLowerCase();
    final accountUsedLower = accountUsed?.toLowerCase() ?? '';

    // Check for wallet/UPI indicators
    if (bankNameLower.contains('phonepe') ||
        bankNameLower.contains('paytm') ||
        bankNameLower.contains('gpay') ||
        bankNameLower.contains('google pay') ||
        bankNameLower.contains('upi') ||
        accountUsedLower.contains('@')) {
      return AccountType.wallet;
    }

    // Check for credit card indicators
    if (bankNameLower.contains('card') ||
        accountUsedLower.contains('card') ||
        accountUsedLower.contains('cc')) {
      return AccountType.creditCard;
    }

    // Default to bank account
    return AccountType.bank;
  }

  /// Get a confidence score for the match (0.0 to 1.0)
  static double getMatchConfidence({
    required Account account,
    String? bankName,
    String? accountUsed,
  }) {
    double confidence = 0.0;

    // Extract last 4 digits
    final last4Digits = _extractLast4Digits(accountUsed);

    // Perfect match: last 4 digits
    if (last4Digits != null && account.lastFourDigits == last4Digits) {
      confidence += 0.6;
    }

    // Good match: bank name
    if (bankName != null && _accountMatchesBankName(account, bankName)) {
      confidence += 0.3;
    }

    // Decent match: account type
    if (bankName != null) {
      final inferredType = _inferAccountType(bankName, accountUsed);
      if (account.type == inferredType) {
        confidence += 0.1;
      }
    }

    return confidence.clamp(0.0, 1.0);
  }

  /// Get all possible matches sorted by confidence
  static List<AccountMatch> getAllMatches({
    required List<Account> accounts,
    String? bankName,
    String? accountUsed,
  }) {
    final matches = accounts.map((account) {
      final confidence = getMatchConfidence(
        account: account,
        bankName: bankName,
        accountUsed: accountUsed,
      );
      return AccountMatch(account: account, confidence: confidence);
    }).toList();

    // Sort by confidence (highest first)
    matches.sort((a, b) => b.confidence.compareTo(a.confidence));

    return matches;
  }
}

/// Represents an account match with confidence score
class AccountMatch {
  final Account account;
  final double confidence; // 0.0 to 1.0

  AccountMatch({required this.account, required this.confidence});

  /// Is this a high confidence match?
  bool get isHighConfidence => confidence >= 0.6;

  /// Is this a medium confidence match?
  bool get isMediumConfidence => confidence >= 0.3 && confidence < 0.6;

  /// Is this a low confidence match?
  bool get isLowConfidence => confidence < 0.3;
}
