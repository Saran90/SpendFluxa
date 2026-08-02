/// Whitelisted tool names for Flux AI.
class FluxAiTools {
  FluxAiTools._();

  // ── Transaction tools ─────────────────────────────────────────────────────
  static const createTransaction = 'createTransaction';
  static const updateTransaction = 'updateTransaction';
  static const deleteTransaction = 'deleteTransaction';
  static const searchTransactions = 'searchTransactions';
  static const createRecurringTransaction = 'createRecurringTransaction';
  static const cancelRecurringTransaction = 'cancelRecurringTransaction';

  // ── Query / analysis tools ────────────────────────────────────────────────
  static const getSpendingSummary = 'getSpendingSummary';
  static const comparePeriods = 'comparePeriods';
  static const getRecurringTransactions = 'getRecurringTransactions';
  static const getBudgetStatus = 'getBudgetStatus';
  static const getForecast = 'getForecast';
  static const getBalanceForecast = 'getBalanceForecast';
  static const getAnomalies = 'getAnomalies';
  static const getSavingsRate = 'getSavingsRate';
  static const getFinancialSummary = 'getFinancialSummary';

  // ── Plan tools ────────────────────────────────────────────────────────────
  static const getFinancialPlans = 'getFinancialPlans';
  static const createFinancialPlan = 'createFinancialPlan';
  static const updateFinancialPlan = 'updateFinancialPlan';
  static const deleteFinancialPlan = 'deleteFinancialPlan';

  /// The complete whitelist — used by [ToolCallValidator].
  static const all = {
    createTransaction,
    updateTransaction,
    deleteTransaction,
    searchTransactions,
    createRecurringTransaction,
    cancelRecurringTransaction,
    getSpendingSummary,
    comparePeriods,
    getRecurringTransactions,
    getBudgetStatus,
    getForecast,
    getBalanceForecast,
    getAnomalies,
    getSavingsRate,
    getFinancialSummary,
    getFinancialPlans,
    createFinancialPlan,
    updateFinancialPlan,
    deleteFinancialPlan,
  };
}

/// JSON schema constraints for tool argument validation.
class FluxAiToolSchemas {
  FluxAiToolSchemas._();

  // ── createTransaction ─────────────────────────────────────────────────────
  static const createTransactionRequired = {'amount', 'type'};
  static const createTransactionTypes = {'expense', 'income', 'transfer'};

  // ── updateTransaction ─────────────────────────────────────────────────────
  static const updateTransactionRequired = {'id'};

  // ── deleteTransaction ─────────────────────────────────────────────────────
  static const deleteTransactionRequired = {'id'};

  // ── createRecurringTransaction ────────────────────────────────────────────
  static const createRecurringTransactionRequired = {
    'amount',
    'type',
    'title',
    'category',
    'frequency',
    'startDateIso',
  };
  static const validFrequencies = {'daily', 'weekly', 'monthly', 'yearly'};

  // ── cancelRecurringTransaction ────────────────────────────────────────────
  static const cancelRecurringTransactionRequired = {'id'};

  // ── getSpendingSummary ────────────────────────────────────────────────────
  static const getSpendingSummaryRequired = {'period'};

  // ── comparePeriods ────────────────────────────────────────────────────────
  static const comparePeriodsRequired = {'current', 'previous'};

  // ── getBudgetStatus ───────────────────────────────────────────────────────
  static const getBudgetStatusRequired = {'period'};

  // ── getForecast ───────────────────────────────────────────────────────────
  static const getForecastRequired = {'days'};

  // ── getSavingsRate ────────────────────────────────────────────────────────
  static const getSavingsRateRequired = {'period'};

  // ── getFinancialSummary ───────────────────────────────────────────────────
  static const getFinancialSummaryRequired = {'period'};

  // ── createFinancialPlan ───────────────────────────────────────────────────
  static const createFinancialPlanRequired = {
    'name',
    'type',
    'targetAmount',
    'targetDate',
    'contributionFrequency',
  };
  static const validPlanTypes = {'goal', 'event'};
  static const validContributionFrequencies = {'weekly', 'monthly'};
  static const validPlanPriorities = {'low', 'medium', 'high'};

  // ── updateFinancialPlan ───────────────────────────────────────────────────
  static const updateFinancialPlanRequired = {'id'};

  // ── deleteFinancialPlan ───────────────────────────────────────────────────
  static const deleteFinancialPlanRequired = {'id'};

  // ── Shared ────────────────────────────────────────────────────────────────
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
