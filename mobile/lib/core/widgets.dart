import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'api_client.dart';
import 'theme.dart';

/// A surface card with the MONOVA border and radius. Use for every grouped block so spacing stays consistent.
class MonovaCard extends StatelessWidget {
  const MonovaCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap, this.gradient});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final content = Padding(padding: padding, child: child);
    final card = Material(
      color: gradient == null ? c.glassFill : Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        decoration: BoxDecoration(
          gradient: gradient,
          color: gradient == null ? c.glassFill : null,
          borderRadius: BorderRadius.circular(20),
          // A thin light edge makes the glass read as a surface, the way frosted cards do.
          border: Border.all(color: gradient == null ? c.border : Colors.transparent),
        ),
        child: onTap == null
            ? content
            : InkWell(borderRadius: BorderRadius.circular(20), onTap: onTap, child: content),
      ),
    );
    if (gradient != null) return card;
    // Frosted glass: blur whatever is behind the card, so the ambient light softly shows through.
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14), child: card),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
        if (action != null)
          TextButton(
            onPressed: onAction,
            child: Text(action!, style: TextStyle(color: context.monova.accentStart, fontWeight: FontWeight.w700)),
          ),
      ],
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.message, this.actionLabel, this.onAction});

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(gradient: c.aurora, shape: BoxShape.circle),
              child: Icon(icon, color: c.onAccent, size: 34),
            ),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(message, style: TextStyle(color: c.muted), textAlign: TextAlign.center),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final message = error is ApiException ? error.toString() : 'Something went wrong. Please try again.';
    return EmptyState(
      icon: Icons.cloud_off_rounded,
      title: 'Could not load this',
      message: message,
      actionLabel: 'Try again',
      onAction: onRetry,
    );
  }
}

/// Shows a spinner, an error with retry, or the child, for an AsyncValue-like load.
class LoadingBox extends StatelessWidget {
  const LoadingBox({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.all(48),
        child: Center(child: CircularProgressIndicator()),
      );
}

/// A bottom sheet frame with a title, a drag handle and safe bottom padding. All forms use it.
class FormSheet extends StatelessWidget {
  const FormSheet({super.key, required this.title, required this.child, this.asDialog = false});

  final String title;
  final Widget child;

  /// True when shown as a centred card on wide screens: rounded on all corners, no drag handle.
  final bool asDialog;

  /// Phones get a bottom sheet. Wide screens (web, desktop) get a card centred near the top of the window,
  /// which is where people expect a form to appear on a computer.
  static Future<T?> show<T>(BuildContext context, {required String title, required Widget child}) {
    final size = MediaQuery.sizeOf(context);
    if (size.width >= 900) {
      return showDialog<T>(
        context: context,
        builder: (_) => Dialog(
          alignment: Alignment.topCenter,
          insetPadding: const EdgeInsets.fromLTRB(24, 56, 24, 24),
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 560, maxHeight: size.height - 80),
            child: FormSheet(title: title, child: child, asDialog: true),
          ),
        ),
      );
    }
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FormSheet(title: title, child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    return Container(
      decoration: BoxDecoration(
        color: c.raised,
        borderRadius: asDialog ? BorderRadius.circular(24) : const BorderRadius.vertical(top: Radius.circular(28)),
        border: asDialog ? Border.all(color: c.border) : null,
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!asDialog)
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(4)),
                ),
              ),
            SizedBox(height: asDialog ? 4 : 16),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            _UnsavedGuard(child: child),
          ],
        ),
      ),
    );
  }
}

/// Runs an async action from a button, showing progress and surfacing the server's message on failure.
Future<bool> runAction(BuildContext context, Future<void> Function() action, {String success = 'Saved'}) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await action();
    messenger.showSnackBar(SnackBar(content: Text(success)));
    return true;
  } on ApiException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
    return false;
  } catch (_) {
    messenger.showSnackBar(const SnackBar(content: Text('Something went wrong. Please try again.')));
    return false;
  }
}

/// Coloured amount text. Income is green, expenses rose, neutral is ink.
class AmountText extends StatelessWidget {
  const AmountText(this.text, {super.key, this.tone = AmountTone.neutral, this.size = 16});

  final String text;
  final AmountTone tone;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final color = switch (tone) {
      AmountTone.income => c.income,
      AmountTone.expense => c.expense,
      AmountTone.warning => c.warning,
      AmountTone.neutral => c.ink,
    };
    return Text(
      text,
      style: TextStyle(color: color, fontSize: size, fontWeight: FontWeight.w700, fontFeatures: const [FontFeature.tabularFigures()]),
    );
  }
}

enum AmountTone { neutral, income, expense, warning }

/// Thin progress bar in the accent gradient, coloured by status when given.
class ProgressBar extends StatelessWidget {
  const ProgressBar({super.key, required this.value, this.color});

  final double value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final fraction = (value / 100).clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: LinearProgressIndicator(
        value: fraction,
        minHeight: 8,
        backgroundColor: c.border,
        color: color ?? c.accentStart,
      ),
    );
  }
}

/// Watches the text typed in a form. Closing the form while text has changed asks first: Stay, or Discard.
/// Changes made only with dropdowns, switches or date pickers are not counted.
class _UnsavedGuard extends StatefulWidget {
  const _UnsavedGuard({required this.child});

  final Widget child;

  @override
  State<_UnsavedGuard> createState() => _UnsavedGuardState();
}

class _UnsavedGuardState extends State<_UnsavedGuard> {
  /// The text as it was when the form opened, taken after its first frame so prefilled values count as saved.
  List<String>? _initial;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _initial = _typedText();
    });
  }

  /// Every text field's text under this guard, in screen order.
  List<String> _typedText() {
    final out = <String>[];
    void visit(Element e) {
      final w = e.widget;
      if (w is EditableText) out.add(w.controller.text);
      e.visitChildren(visit);
    }

    (context as Element).visitChildren(visit);
    return out;
  }

  bool get _hasUnsavedChanges {
    final initial = _initial;
    if (initial == null) return false;
    final now = _typedText();
    if (now.length != initial.length) return true;
    for (var i = 0; i < now.length; i++) {
      if (now[i] != initial[i]) return true;
    }
    return false;
  }

  Future<void> _close() async {
    if (!_hasUnsavedChanges) {
      Navigator.of(context).pop();
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('You have changes that are not saved yet. Stay to keep editing, or discard them.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Stay')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Discard')),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: widget.child,
    );
  }
}

/// Shows a message as a dialog. Used where a snackbar would be hidden behind an open form sheet (for example, contacts access).
Future<void> showContactsProblem(BuildContext context, String message) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Contacts'),
      content: Text(message),
      actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
    ),
  );
}
