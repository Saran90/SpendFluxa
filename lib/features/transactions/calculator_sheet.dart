import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Calculator bottom sheet for entering amounts with calculations
class CalculatorSheet extends StatefulWidget {
  final String initialValue;
  final Color accentColor;

  const CalculatorSheet({
    super.key,
    this.initialValue = '',
    this.accentColor = AppColors.primary,
  });

  @override
  State<CalculatorSheet> createState() => _CalculatorSheetState();
}

class _CalculatorSheetState extends State<CalculatorSheet> {
  String _display = '';
  String _expression = '';
  String _operator = '';
  double _firstOperand = 0;
  bool _shouldResetDisplay = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialValue.isNotEmpty) {
      _display = widget.initialValue;
    }
  }

  void _onNumberPressed(String number) {
    setState(() {
      if (_shouldResetDisplay) {
        _display = number;
        _shouldResetDisplay = false;
      } else {
        if (_display == '0' || _display.isEmpty) {
          _display = number;
        } else {
          _display += number;
        }
      }
      _expression = _buildExpression();
    });
  }

  void _onOperatorPressed(String operator) {
    if (_display.isEmpty) return;

    setState(() {
      if (_operator.isNotEmpty) {
        _calculate();
      }
      _firstOperand = double.tryParse(_display) ?? 0;
      _operator = operator;
      _shouldResetDisplay = true;
      _expression = _buildExpression();
    });
  }

  void _onDecimalPressed() {
    setState(() {
      if (_shouldResetDisplay) {
        _display = '0.';
        _shouldResetDisplay = false;
      } else if (!_display.contains('.')) {
        _display = _display.isEmpty ? '0.' : '$_display.';
      }
      _expression = _buildExpression();
    });
  }

  void _calculate() {
    if (_operator.isEmpty || _display.isEmpty) return;

    final secondOperand = double.tryParse(_display) ?? 0;
    double result = _firstOperand;

    switch (_operator) {
      case '+':
        result = _firstOperand + secondOperand;
        break;
      case '-':
        result = _firstOperand - secondOperand;
        break;
      case '×':
        result = _firstOperand * secondOperand;
        break;
      case '÷':
        result = secondOperand != 0 ? _firstOperand / secondOperand : 0;
        break;
    }

    setState(() {
      _display = _formatNumber(result);
      _operator = '';
      _firstOperand = 0;
      _shouldResetDisplay = true;
      _expression = '';
    });
  }

  String _formatNumber(double number) {
    if (number == number.toInt()) {
      return number.toInt().toString();
    }
    return number.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
  }

  String _buildExpression() {
    if (_operator.isEmpty) {
      return _display;
    }
    final first = _formatNumber(_firstOperand);
    if (_shouldResetDisplay) {
      return '$first $_operator';
    }
    return '$first $_operator $_display';
  }

  void _onClearPressed() {
    setState(() {
      _display = '';
      _expression = '';
      _operator = '';
      _firstOperand = 0;
      _shouldResetDisplay = false;
    });
  }

  void _onBackspacePressed() {
    setState(() {
      if (_display.isNotEmpty) {
        _display = _display.substring(0, _display.length - 1);
        _expression = _buildExpression();
      }
    });
  }

  void _onDonePressed() {
    if (_operator.isNotEmpty && !_shouldResetDisplay) {
      _calculate();
    }
    Navigator.of(context).pop(_display.isEmpty ? '0' : _display);
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
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
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
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Expression
                  if (_expression.isNotEmpty)
                    Text(
                      _expression,
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.textSecondary.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 8),
                  // Result
                  Text(
                    _display.isEmpty ? '0' : _display,
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Calculator grid
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildRow(['7', '8', '9', '÷']),
                  const SizedBox(height: 12),
                  _buildRow(['4', '5', '6', '×']),
                  const SizedBox(height: 12),
                  _buildRow(['1', '2', '3', '-']),
                  const SizedBox(height: 12),
                  _buildRow(['.', '0', '⌫', '+']),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildButton(
                          'C',
                          isOperator: true,
                          isSecondary: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: _buildButton(
                          '=',
                          isOperator: true,
                          isPrimary: true,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(List<String> buttons) {
    return Row(
      children: buttons.map((button) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _buildButton(
              button,
              isOperator: ['+', '-', '×', '÷'].contains(button),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildButton(
    String label, {
    bool isOperator = false,
    bool isPrimary = false,
    bool isSecondary = false,
  }) {
    final isActive = _operator == label && !_shouldResetDisplay;

    return SizedBox(
      height: 64,
      child: Material(
        color: isPrimary
            ? widget.accentColor
            : isSecondary
            ? AppColors.background
            : isOperator
            ? (isActive
                  ? widget.accentColor
                  : widget.accentColor.withValues(alpha: 0.1))
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        elevation: isOperator || isPrimary || isSecondary ? 0 : 2,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            if (label == 'C') {
              _onClearPressed();
            } else if (label == '⌫') {
              _onBackspacePressed();
            } else if (label == '=') {
              _onDonePressed();
            } else if (label == '.') {
              _onDecimalPressed();
            } else if (['+', '-', '×', '÷'].contains(label)) {
              _onOperatorPressed(label);
            } else {
              _onNumberPressed(label);
            }
          },
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: label == '⌫' ? 20 : 24,
                fontWeight: FontWeight.w600,
                color: isPrimary
                    ? Colors.white
                    : isOperator
                    ? (isActive ? Colors.white : widget.accentColor)
                    : isSecondary
                    ? AppColors.textSecondary
                    : AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
