import 'dart:math' as math;

/// Expression evaluator for the calculator. Supports + - * / ^, %, !, parentheses, unary minus,
/// sin cos tan asin acos atan, log (base 10), ln, sqrt, cbrt, abs, exp, and the constants pi and e.
/// Angle mode applies to trigonometric functions.
class CalculatorEngine {
  CalculatorEngine({this.degrees = true});

  bool degrees;

  static const _functions = {
    'sin', 'cos', 'tan', 'asin', 'acos', 'atan', 'log', 'ln', 'sqrt', 'cbrt', 'abs', 'exp',
  };

  double evaluate(String expression) {
    final tokens = _tokenize(expression);
    final rpn = _toRpn(tokens);
    return _evalRpn(rpn);
  }

  /// Trims float noise (for example 0.1 + 0.2) so results read like a real calculator.
  static String format(double value) {
    if (value.isNaN || value.isInfinite) throw const FormatException('Result is undefined');
    if (value == value.roundToDouble() && value.abs() < 1e15) return value.toStringAsFixed(0);
    final text = double.parse(value.toStringAsPrecision(12)).toString();
    return text.contains('e') ? value.toStringAsExponential(8) : text;
  }

  // ---- tokenizer ----

  List<_Tok> _tokenize(String input) {
    final s = input.replaceAll('×', '*').replaceAll('÷', '/').replaceAll('−', '-').replaceAll(' ', '');
    final out = <_Tok>[];
    var i = 0;
    while (i < s.length) {
      final ch = s[i];
      if (RegExp(r'[0-9.]').hasMatch(ch)) {
        final start = i;
        while (i < s.length && RegExp(r'[0-9.]').hasMatch(s[i])) {
          i++;
        }
        final text = s.substring(start, i);
        if ('.'.allMatches(text).length > 1) throw const FormatException('Invalid number');
        out.add(_Tok(_T.num, text, value: double.tryParse(text) ?? (throw const FormatException('Invalid number'))));
      } else if (RegExp(r'[a-z]').hasMatch(ch)) {
        final start = i;
        while (i < s.length && RegExp(r'[a-z]').hasMatch(s[i])) {
          i++;
        }
        final word = s.substring(start, i);
        if (word == 'pi') {
          out.add(_Tok(_T.num, word, value: math.pi));
        } else if (word == 'e') {
          out.add(_Tok(_T.num, word, value: math.e));
        } else if (_functions.contains(word)) {
          out.add(_Tok(_T.func, word));
        } else {
          throw FormatException('Unknown function "$word"');
        }
      } else if ('+-*/^%!'.contains(ch)) {
        out.add(_Tok(_T.op, ch));
        i++;
      } else if (ch == '(') {
        out.add(_Tok(_T.lparen, ch));
        i++;
      } else if (ch == ')') {
        out.add(_Tok(_T.rparen, ch));
        i++;
      } else {
        throw FormatException('Unexpected "$ch"');
      }
    }
    return _markUnaryMinus(out);
  }

  /// A minus sign at the start, after an operator or after "(" is a sign, not a subtraction.
  List<_Tok> _markUnaryMinus(List<_Tok> tokens) {
    final out = <_Tok>[];
    for (var i = 0; i < tokens.length; i++) {
      final t = tokens[i];
      final prev = i == 0 ? null : tokens[i - 1];
      final isSign = t.type == _T.op && t.text == '-' &&
          (prev == null || prev.type == _T.op || prev.type == _T.lparen || prev.type == _T.func);
      out.add(isSign ? _Tok(_T.op, 'neg') : t);
    }
    return out;
  }

  // ---- shunting-yard ----

  static int _prec(String op) => switch (op) {
        '+' || '-' => 1,
        '*' || '/' => 2,
        'neg' => 3,
        '^' => 4,
        '%' || '!' => 5,
        _ => 0,
      };

  static bool _rightAssoc(String op) => op == '^' || op == 'neg';

  List<_Tok> _toRpn(List<_Tok> tokens) {
    final output = <_Tok>[];
    final stack = <_Tok>[];
    for (final t in tokens) {
      switch (t.type) {
        case _T.num:
          output.add(t);
        case _T.func:
          stack.add(t);
        case _T.op:
          if (t.text == '%' || t.text == '!') {
            // Postfix operators bind to the value just produced.
            output.add(t);
            continue;
          }
          if (t.text == 'neg') {
            // A prefix sign never pops other operators; it waits for its operand.
            stack.add(t);
            continue;
          }
          while (stack.isNotEmpty && stack.last.type == _T.op) {
            final top = stack.last.text;
            final higher = _prec(top) > _prec(t.text) || (_prec(top) == _prec(t.text) && !_rightAssoc(t.text));
            if (!higher) break;
            output.add(stack.removeLast());
          }
          stack.add(t);
        case _T.lparen:
          stack.add(t);
        case _T.rparen:
          while (stack.isNotEmpty && stack.last.type != _T.lparen) {
            output.add(stack.removeLast());
          }
          if (stack.isEmpty) throw const FormatException('Unmatched )');
          stack.removeLast();
          if (stack.isNotEmpty && stack.last.type == _T.func) output.add(stack.removeLast());
      }
    }
    while (stack.isNotEmpty) {
      final t = stack.removeLast();
      if (t.type == _T.lparen) throw const FormatException('Unmatched (');
      output.add(t);
    }
    return output;
  }

  // ---- evaluation ----

  double _evalRpn(List<_Tok> rpn) {
    final st = <double>[];
    double pop() {
      if (st.isEmpty) throw const FormatException('Incomplete expression');
      return st.removeLast();
    }

    for (final t in rpn) {
      if (t.type == _T.num) {
        st.add(t.value!);
      } else if (t.type == _T.func) {
        st.add(_applyFunc(t.text, pop()));
      } else {
        switch (t.text) {
          case 'neg':
            st.add(-pop());
          case '%':
            st.add(pop() / 100);
          case '!':
            st.add(_factorial(pop()));
          default:
            final b = pop();
            final a = pop();
            st.add(switch (t.text) {
              '+' => a + b,
              '-' => a - b,
              '*' => a * b,
              '/' => b == 0 ? throw const FormatException('Cannot divide by zero') : a / b,
              '^' => math.pow(a, b).toDouble(),
              _ => throw FormatException('Unknown operator ${t.text}'),
            });
        }
      }
    }
    if (st.length != 1) throw const FormatException('Incomplete expression');
    return st.single;
  }

  double _applyFunc(String name, double x) {
    double trig(double v) => degrees ? v * math.pi / 180 : v;
    double inv(double v) => degrees ? v * 180 / math.pi : v;
    return switch (name) {
      'sin' => math.sin(trig(x)),
      'cos' => math.cos(trig(x)),
      'tan' => math.tan(trig(x)),
      'asin' => inv(math.asin(x)),
      'acos' => inv(math.acos(x)),
      'atan' => inv(math.atan(x)),
      'log' => math.log(x) / math.ln10,
      'ln' => math.log(x),
      'sqrt' => math.sqrt(x),
      'cbrt' => x < 0 ? -math.pow(-x, 1 / 3).toDouble() : math.pow(x, 1 / 3).toDouble(),
      'abs' => x.abs(),
      'exp' => math.exp(x),
      _ => throw FormatException('Unknown function $name'),
    };
  }

  double _factorial(double x) {
    if (x < 0 || x != x.roundToDouble() || x > 170) throw const FormatException('Factorial needs a whole number from 0 to 170');
    var r = 1.0;
    for (var i = 2; i <= x; i++) {
      r *= i;
    }
    return r;
  }
}

enum _T { num, op, func, lparen, rparen }

class _Tok {
  const _Tok(this.type, this.text, {this.value});

  final _T type;
  final String text;
  final double? value;
}
