import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/models/account.dart';
import '../../core/services/account_service.dart';
import '../../core/theme/app_colors.dart';

Future<Account?> showAddAccountSheet(
  BuildContext context,
  AccountService accountService, {
  Account? editing,
}) {
  final screenHeight = MediaQuery.of(context).size.height;
  return showModalBottomSheet<Account>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    constraints: BoxConstraints(maxHeight: screenHeight * 0.8),
    builder: (_) =>
        _AddAccountSheet(accountService: accountService, editing: editing),
  );
}

class _AddAccountSheet extends StatefulWidget {
  final AccountService accountService;
  final Account? editing;

  const _AddAccountSheet({required this.accountService, this.editing});

  @override
  State<_AddAccountSheet> createState() => _AddAccountSheetState();
}

class _AddAccountSheetState extends State<_AddAccountSheet> {
  final _nameController = TextEditingController();
  final _balanceController = TextEditingController();
  final _creditLimitController = TextEditingController();
  final _lastFourController = TextEditingController();
  final _nameFocus = FocusNode();

  late AccountType _type;
  late Color _selectedColor;
  bool _isDefault = false;
  int? _billDate; // day of month for credit cards

  String? _nameError;
  String? _balanceError;
  String? _creditLimitError;

  bool get _isEditing => widget.editing != null;
  bool get _isCreditCard => _type == AccountType.creditCard;

  // Color palette for accounts
  static const _colorPalette = [
    Color(0xFF3498DB),
    Color(0xFFE74C3C),
    Color(0xFF9B59B6),
    Color(0xFF2D9E6B),
    Color(0xFFFF9800),
    Color(0xFF1ABC9C),
    Color(0xFF2C3E50),
    Color(0xFFE91E63),
    Color(0xFF607D8B),
    Color(0xFF795548),
    Color(0xFF00BCD4),
    Color(0xFF8BC34A),
  ];

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final e = widget.editing!;
      _nameController.text = e.name;
      _balanceController.text = e.balance.toStringAsFixed(2);
      _lastFourController.text = e.lastFourDigits ?? '';
      _creditLimitController.text = e.creditLimit != null
          ? e.creditLimit!.toStringAsFixed(2)
          : '';
      _billDate = e.billDate;
      _type = e.type;
      _selectedColor = e.color;
      _isDefault = e.isDefault;
    } else {
      _type = AccountType.bank;
      _selectedColor = AccountType.bank.color;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    _creditLimitController.dispose();
    _lastFourController.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  void _save() async {
    final name = _nameController.text.trim();
    final balanceText = _balanceController.text.trim();
    final creditLimitText = _creditLimitController.text.trim();

    bool hasError = false;
    if (name.isEmpty) {
      setState(() => _nameError = 'Please enter an account name');
      hasError = true;
    }
    final balance = double.tryParse(balanceText);
    if (balanceText.isEmpty || balance == null) {
      setState(() => _balanceError = 'Please enter a valid amount');
      hasError = true;
    }
    double? creditLimit;
    if (_isCreditCard) {
      if (creditLimitText.isNotEmpty) {
        creditLimit = double.tryParse(creditLimitText);
        if (creditLimit == null || creditLimit <= 0) {
          setState(
            () => _creditLimitError = 'Please enter a valid credit limit',
          );
          hasError = true;
        } else if (balance != null && balance > creditLimit) {
          setState(
            () => _balanceError = 'Outstanding cannot exceed credit limit',
          );
          hasError = true;
        }
      }
    }
    if (hasError) return;

    final lastFour = _lastFourController.text.trim();
    final id = _isEditing
        ? widget.editing!.id
        : DateTime.now().millisecondsSinceEpoch.toString();

    final account = Account(
      id: id,
      name: name,
      type: _type,
      balance: balance!,
      color: _selectedColor,
      creditLimit: _isCreditCard ? creditLimit : null,
      billDate: _isCreditCard ? _billDate : null,
      lastFourDigits: _isCreditCard && lastFour.isNotEmpty ? lastFour : null,
      isDefault: _isDefault,
    );

    if (_isEditing) {
      await widget.accountService.update(account);
    } else {
      await widget.accountService.add(account);
    }

    if (mounted) Navigator.of(context).pop(account);
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.only(bottom: viewInsets.bottom),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, bottomPadding + 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.textLight,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),

                // Title
                Text(
                  _isEditing ? 'Edit Account' : 'New Account',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 24),

                // Account type selector
                _buildSectionLabel('Account Type'),
                const SizedBox(height: 12),
                _buildTypeSelector(),
                const SizedBox(height: 24),

                // Name field
                _buildSectionLabel('Account Name'),
                const SizedBox(height: 10),
                _buildTextField(
                  controller: _nameController,
                  focusNode: _nameFocus,
                  hint: _type == AccountType.creditCard
                      ? 'e.g. HDFC Credit Card'
                      : _type == AccountType.wallet
                      ? 'e.g. PhonePe Wallet'
                      : 'e.g. SBI Savings',
                  errorText: _nameError,
                  onChanged: (_) {
                    if (_nameError != null) {
                      setState(() => _nameError = null);
                    }
                  },
                ),
                const SizedBox(height: 20),

                // Balance / Outstanding field
                _buildSectionLabel(
                  _isCreditCard ? 'Outstanding Amount' : 'Current Balance',
                ),
                const SizedBox(height: 10),
                _buildTextField(
                  controller: _balanceController,
                  hint: '0.00',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d*\.?\d{0,2}'),
                    ),
                  ],
                  errorText: _balanceError,
                  onChanged: (_) {
                    if (_balanceError != null) {
                      setState(() => _balanceError = null);
                    }
                  },
                ),
                const SizedBox(height: 20),

                // Credit card specific fields
                if (_isCreditCard) ...[
                  _buildSectionLabel('Credit Limit (optional)'),
                  const SizedBox(height: 10),
                  _buildTextField(
                    controller: _creditLimitController,
                    hint: '0.00',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,2}'),
                      ),
                    ],
                    errorText: _creditLimitError,
                    onChanged: (_) {
                      if (_creditLimitError != null) {
                        setState(() => _creditLimitError = null);
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                  _buildSectionLabel('Last 4 Digits (optional)'),
                  const SizedBox(height: 10),
                  _buildTextField(
                    controller: _lastFourController,
                    hint: '1234',
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildSectionLabel('Bill Date — day of month (optional)'),
                  const SizedBox(height: 12),
                  _buildBillDatePicker(),
                  const SizedBox(height: 20),
                ],

                // Color picker
                _buildSectionLabel('Color'),
                const SizedBox(height: 12),
                _buildColorPicker(),
                const SizedBox(height: 20),

                // Set as default toggle
                _buildDefaultToggle(),
                const SizedBox(height: 28),

                // Save button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      _isEditing ? 'Save Changes' : 'Add Account',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Account type selector ─────────────────────────────────────────────────

  Widget _buildTypeSelector() {
    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: AccountType.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, index) {
          final type = AccountType.values[index];
          final isSelected = _type == type;
          return GestureDetector(
            onTap: () => setState(() {
              _type = type;
              _selectedColor = type.color;
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 76,
              decoration: BoxDecoration(
                color: isSelected
                    ? type.color.withValues(alpha: 0.12)
                    : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? type.color : const Color(0xFFEEF0F3),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    type.icon,
                    color: isSelected ? type.color : AppColors.textSecondary,
                    size: 24,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    type.label.split(' ').first, // short label
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: isSelected ? type.color : AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Color picker ──────────────────────────────────────────────────────────

  Widget _buildColorPicker() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _colorPalette.map((color) {
        final isSelected = _selectedColor.toARGB32() == color.toARGB32();
        return GestureDetector(
          onTap: () => setState(() => _selectedColor = color),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: isSelected
                  ? Border.all(color: Colors.white, width: 3)
                  : null,
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.5),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: isSelected
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                : null,
          ),
        );
      }).toList(),
    );
  }

  // ── Default toggle ────────────────────────────────────────────────────────

  Widget _buildDefaultToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.star_rounded, color: Color(0xFFFF9800), size: 20),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Set as default account',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Switch(
            value: _isDefault,
            onChanged: (v) => setState(() => _isDefault = v),
            activeThumbColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  // ── Text field ────────────────────────────────────────────────────────────

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    FocusNode? focusNode,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? errorText,
    String? prefixText,
    void Function(String)? onChanged,
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textCapitalization: TextCapitalization.words,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: hint,
        prefixText: prefixText,
        hintStyle: const TextStyle(
          color: AppColors.textLight,
          fontWeight: FontWeight.w400,
        ),
        errorText: errorText,
        filled: true,
        fillColor: AppColors.background,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
      ),
      onChanged: onChanged,
    );
  }

  // ── Bill date picker ──────────────────────────────────────────────────────

  Widget _buildBillDatePicker() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(31, (i) {
        final day = i + 1;
        final isSelected = _billDate == day;
        return GestureDetector(
          onTap: () => setState(() => _billDate = isSelected ? null : day),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : AppColors.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? AppColors.primary : const Color(0xFFE0E4EA),
                width: 1.5,
              ),
            ),
            child: Center(
              child: Text(
                '$day',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
        letterSpacing: 0.3,
      ),
    );
  }
}
