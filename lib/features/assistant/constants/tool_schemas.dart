/// Whitelisted tool names for Flux AI.
class FluxAiTools {
  FluxAiTools._();

  static const createTransaction = 'createTransaction';
  static const getSpendingSummary = 'getSpendingSummary';
  static const comparePeriods = 'comparePeriods';
  static const getRecurringTransactions = 'getRecurringTransactions';
  static const getBudgetStatus = 'getBudgetStatus';
  static const getForecast = 'getForecast';

  static const all = {
    createTransaction,
    getSpendingSummary,
    comparePeriods,
    getRecurringTransactions,
    getBudgetStatus,
    getForecast,
  };
}

/// JSON schema constraints for tool argument validation.
class FluxAiToolSchemas {
  FluxAiToolSchemas._();

  static const createTransactionRequired = {'amount', 'type'};
  static const createTransactionTypes = {'expense', 'income', 'transfer'};

  static const getSpendingSummaryRequired = {'period'};
  static const comparePeriodsRequired = {'current', 'previous'};
  static const getForecastRequired = {'days'};

  static const validPeriods = {
    'today',
    'yesterday',
    'this_week',
    'last_week',
    'this_month',
    'last_month',
    'this_year',
    'last_year',
  };
}
