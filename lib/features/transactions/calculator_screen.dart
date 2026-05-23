import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class CalculatorBottomSheet extends StatefulWidget {
  final double? initialAmount;

  const CalculatorBottomSheet({super.key, this.initialAmount});

  @override
  State<CalculatorBottomSheet> createState() => _CalculatorBottomSheetState();
}

class _CalculatorBottomSheetState extends State<CalculatorBottomSheet> {
  late String _display;
  late String _operator;
  late double _previousValue;
  bool _shouldResetDisplay = false;

  @override
  void initState() {
    super.initState();
    _display = widget.initialAmount?.toStringAsFixed(2) ?? '0';
    _operator = '';
    _previousValue = 0;
    _shouldResetDisplay = false;
  }

  void _onNumberPressed(String number) {
    setState(() {
      if (_shouldResetDisplay) {
        _display = number;
        _shouldResetDisplay = false;
      } else {
        if (_display == '0' && number != '.') {
          _display = number;
        } else if (number == '.' && _display.contains('.')) {
          return;
        } else {
          _display += number;
        }
      }
    });
  }

  void _onOperatorPressed(String op) {
    final currentValue = double.tryParse(_display) ?? 0;

    if (_operator.isNotEmpty) {
      _calculate();
    } else {
      _previousValue = currentValue;
    }

    setState(() {
      _operator = op;
      _shouldResetDisplay = true;
    });
  }

  void _calculate() {
    final currentValue = double.tryParse(_display) ?? 0;
    double result = 0;

    switch (_operator) {
      case '+':
        result = _previousValue + currentValue;
        break;
      case '-':
        result = _previousValue - currentValue;
        break;
      case '×':
        result = _previousValue * currentValue;
        break;
      case '÷':
        if (currentValue != 0) {
          result = _previousValue / currentValue;
        } else {
          setState(() => _display = 'Error');
          return;
        }
        break;
      default:
        return;
    }

    setState(() {
      _display = result.toStringAsFixed(2);
      _operator = '';
      _shouldResetDisplay = true;
    });
  }

  void _onEquals() {
    if (_operator.isNotEmpty) {
      _calculate();
    }
  }

  void _onClear() {
    setState(() {
      _display = '0';
      _operator = '';
      _previousValue = 0;
      _shouldResetDisplay = false;
    });
  }

  void _onBackspace() {
    setState(() {
      if (_display.length > 1) {
        _display = _display.substring(0, _display.length - 1);
      } else {
        _display = '0';
      }
    });
  }

  void _onSubmit() {
    final amount = double.tryParse(_display) ?? 0;
    Navigator.of(context).pop(amount);
  }

  Widget _buildButton(
    String label, {
    Color? backgroundColor,
    Color? textColor,
    VoidCallback? onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor ?? Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: textColor ?? AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Display
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.textSecondary.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _operator.isEmpty ? 'Amount' : _operator,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _display,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),

          // Calculator buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              children: [
                // Row 1: 7, 8, 9, ÷
                SizedBox(
                  height: 50,
                  child: Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: _buildButton(
                            '7',
                            onPressed: () => _onNumberPressed('7'),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: _buildButton(
                            '8',
                            onPressed: () => _onNumberPressed('8'),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: _buildButton(
                            '9',
                            onPressed: () => _onNumberPressed('9'),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: _buildButton(
                            '÷',
                            backgroundColor: const Color(0xFF4ECDC4),
                            textColor: Colors.white,
                            onPressed: () => _onOperatorPressed('÷'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Row 2: 4, 5, 6, ×
                SizedBox(
                  height: 50,
                  child: Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: _buildButton(
                            '4',
                            onPressed: () => _onNumberPressed('4'),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: _buildButton(
                            '5',
                            onPressed: () => _onNumberPressed('5'),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: _buildButton(
                            '6',
                            onPressed: () => _onNumberPressed('6'),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: _buildButton(
                            '×',
                            backgroundColor: const Color(0xFF4ECDC4),
                            textColor: Colors.white,
                            onPressed: () => _onOperatorPressed('×'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Row 3: 1, 2, 3, -
                SizedBox(
                  height: 50,
                  child: Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: _buildButton(
                            '1',
                            onPressed: () => _onNumberPressed('1'),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: _buildButton(
                            '2',
                            onPressed: () => _onNumberPressed('2'),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: _buildButton(
                            '3',
                            onPressed: () => _onNumberPressed('3'),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: _buildButton(
                            '-',
                            backgroundColor: const Color(0xFF4ECDC4),
                            textColor: Colors.white,
                            onPressed: () => _onOperatorPressed('-'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Row 4: 0, ., =, +
                SizedBox(
                  height: 50,
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: _buildButton(
                            '0',
                            onPressed: () => _onNumberPressed('0'),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: _buildButton(
                            '.',
                            onPressed: () => _onNumberPressed('.'),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: _buildButton(
                            '+',
                            backgroundColor: const Color(0xFF4ECDC4),
                            textColor: Colors.white,
                            onPressed: () => _onOperatorPressed('+'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Row 5: ⌫, C, =
                SizedBox(
                  height: 50,
                  child: Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: _buildButton(
                            '⌫',
                            backgroundColor: const Color(0xFFFF6B6B),
                            textColor: Colors.white,
                            onPressed: _onBackspace,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: _buildButton(
                            'C',
                            backgroundColor: const Color(0xFFFF6B6B),
                            textColor: Colors.white,
                            onPressed: _onClear,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: _buildButton(
                            '=',
                            backgroundColor: const Color(0xFF2D9E6B),
                            textColor: Colors.white,
                            onPressed: _onEquals,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Submit button
          Padding(
            padding: const EdgeInsets.all(12),
            child: GestureDetector(
              onTap: _onSubmit,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4ECDC4), Color(0xFF2D9E8F)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4ECDC4).withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 6),
                    Text(
                      'Use Amount',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }
}
