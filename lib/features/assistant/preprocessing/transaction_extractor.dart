import 'amount_parser.dart';
import 'date_parser.dart';
import 'merchant_dictionary.dart';

/// Structured extraction from natural-language transaction input.
class ExtractedTransaction {
  const ExtractedTransaction({
    this.amount,
    this.amountConfidence = 0,
    this.type,
    this.typeConfidence = 0,
    this.category,
    this.categoryConfidence = 0,
    this.dateIso,
    this.dateConfidence = 0,
    this.payee,
    this.note,
    this.needsClarification = false,
    this.clarificationQuestion,
  });

  final double? amount;
  final double amountConfidence;
  final String? type;
  final double typeConfidence;
  final String? category;
  final double categoryConfidence;
  final String? dateIso;
  final double dateConfidence;
  final String? payee;
  final String? note;
  final bool needsClarification;
  final String? clarificationQuestion;

  double get overallConfidence {
    final scores = [
      amountConfidence,
      typeConfidence,
      if (category != null) categoryConfidence,
      dateConfidence,
    ];
    if (scores.isEmpty) return 0;
    return scores.reduce((a, b) => a + b) / scores.length;
  }

  Map<String, dynamic> toPrefillJson() => {
    if (amount != null) 'amount': amount,
    if (type != null) 'type': type,
    if (category != null) 'category': category,
    if (dateIso != null) 'dateIso': dateIso,
    if (payee != null) 'payee': payee,
    if (note != null) 'note': note,
  };
}

class TransactionExtractor {
  TransactionExtractor({DateTime? reference})
    : _dateParser = RelativeDateParser(reference: reference);

  final RelativeDateParser _dateParser;

  static final RegExp _incomePattern = RegExp(
    r'\b(received|got|earned|salary|credited|paid me|income)\b',
    caseSensitive: false,
  );

  static final RegExp _expensePattern = RegExp(
    r'\b(spent|paid|bought|purchase|expense|debited|charged)\b',
    caseSensitive: false,
  );

  static final RegExp _transferPattern = RegExp(
    r'\b(transfer|transferred|moved)\b',
    caseSensitive: false,
  );

  static final RegExp _atPattern = RegExp(
    r'\bat\s+([A-Za-z0-9][A-Za-z0-9\s&\-\.]{1,40})',
    caseSensitive: false,
  );

  ExtractedTransaction extract(String text) {
    final amountResult = AmountParser.parse(text);
    final dateResult = _dateParser.parse(text);
    final merchantResult = MerchantDictionary.lookup(text);
    final keywordCategory = MerchantDictionary.categoryFromKeywords(text);

    String? type;
    double typeConfidence = 0.5;
    if (_incomePattern.hasMatch(text)) {
      type = 'income';
      typeConfidence = 0.9;
    } else if (_transferPattern.hasMatch(text)) {
      type = 'transfer';
      typeConfidence = 0.85;
    } else if (_expensePattern.hasMatch(text) || amountResult.amount != null) {
      type = 'expense';
      typeConfidence = 0.88;
    }

    String? category = merchantResult.category ?? keywordCategory;
    var categoryConfidence = merchantResult.confidence;
    if (category != null && categoryConfidence == 0) {
      categoryConfidence = 0.8;
    }

    String? payee;
    final atMatch = _atPattern.firstMatch(text);
    if (atMatch != null) {
      payee = atMatch.group(1)!.trim();
    }

    var needsClarification = false;
    String? clarification;

    if (amountResult.amount == null || amountResult.confidence < 0.7) {
      needsClarification = true;
      clarification = 'How much was the transaction amount?';
    } else if (type == null) {
      needsClarification = true;
      clarification = 'Was this an expense, income, or transfer?';
    }

    final overall = _overallConfidence(
      amountResult.confidence,
      typeConfidence,
      categoryConfidence,
      dateResult.confidence,
    );

    if (overall >= 0.9) {
      needsClarification = false;
      clarification = null;
    }

    return ExtractedTransaction(
      amount: amountResult.amount,
      amountConfidence: amountResult.confidence,
      type: type,
      typeConfidence: typeConfidence,
      category: category,
      categoryConfidence: categoryConfidence,
      dateIso: dateResult.dateIso,
      dateConfidence: dateResult.confidence,
      payee: payee,
      note: payee,
      needsClarification: needsClarification,
      clarificationQuestion: clarification,
    );
  }

  double _overallConfidence(
    double amount,
    double type,
    double category,
    double date,
  ) {
    return (amount + type + category + date) / 4;
  }
}
