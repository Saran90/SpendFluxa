/// Local merchant → category mapping dictionary.
class MerchantDictionary {
  MerchantDictionary._();

  static const Map<String, String> _merchants = {
    'd-mart': 'Grocery',
    'dmart': 'Grocery',
    'big bazaar': 'Grocery',
    'reliance fresh': 'Grocery',
    'swiggy': 'Food & Dining',
    'zomato': 'Food & Dining',
    'dominos': 'Food & Dining',
    'mcdonalds': 'Food & Dining',
    'starbucks': 'Food & Dining',
    'uber': 'Transport',
    'ola': 'Transport',
    'rapido': 'Transport',
    'irctc': 'Transport',
    'indigo': 'Transport',
    'amazon': 'Shopping',
    'flipkart': 'Shopping',
    'myntra': 'Shopping',
    'netflix': 'Entertainment',
    'spotify': 'Entertainment',
    'hotstar': 'Entertainment',
    'prime video': 'Entertainment',
    'apollo': 'Health',
    'pharmeasy': 'Health',
    '1mg': 'Health',
    'bescom': 'Utilities',
    'tata power': 'Utilities',
    'airtel': 'Bills',
    'jio': 'Bills',
    'vodafone': 'Bills',
    'hdfc': 'Bills',
    'icici': 'Bills',
    'sbi': 'Bills',
    'petrol pump': 'Fuel',
    'hp petrol': 'Fuel',
    'indian oil': 'Fuel',
  };

  /// Returns category label and confidence.
  static ({String? category, double confidence}) lookup(String text) {
    final lower = text.toLowerCase();
    for (final entry in _merchants.entries) {
      if (lower.contains(entry.key)) {
        return (category: entry.value, confidence: 0.93);
      }
    }
    return (category: null, confidence: 0.0);
  }

  static String? categoryFromKeywords(String text) {
    final lower = text.toLowerCase();
    const keywordMap = {
      'groceries': 'Grocery',
      'grocery': 'Grocery',
      'food': 'Food & Dining',
      'restaurant': 'Food & Dining',
      'electricity': 'Utilities',
      'rent': 'Rent',
      'fuel': 'Fuel',
      'petrol': 'Fuel',
      'diesel': 'Fuel',
      'salary': 'Salary',
      'subscription': 'Entertainment',
      'emi': 'Bills',
    };
    for (final entry in keywordMap.entries) {
      if (lower.contains(entry.key)) {
        return entry.value;
      }
    }
    return null;
  }
}
