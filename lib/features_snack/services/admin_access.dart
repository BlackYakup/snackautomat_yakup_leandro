import 'package:flutter/material.dart';
import 'package:snackautomat_yakup_leandro/features_snack/screens/admin/admin_screen.dart';
import 'package:snackautomat_yakup_leandro/features_snack/screens/admin/admin_theme.dart';

/// Standard-PIN für den Admin-Bereich (Schulprojekt).
const kDefaultAdminPin = '1234';

enum _PinValidationState { neutral, error, success }

Future<void> openAdminArea(
  BuildContext context, {
  WidgetBuilder? adminScreenBuilder,
}) async {
  final granted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _AdminPinDialog(),
  );

  if (granted != true || !context.mounted) {
    return;
  }

  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: adminScreenBuilder ?? (_) => const AdminScreen(),
    ),
  );
}

class _AdminPinDialog extends StatefulWidget {
  const _AdminPinDialog();

  @override
  State<_AdminPinDialog> createState() => _AdminPinDialogState();
}

class _AdminPinDialogState extends State<_AdminPinDialog> {
  static const _successFeedbackDuration = Duration(milliseconds: 400);

  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  _PinValidationState _validationState = _PinValidationState.neutral;

  bool get _hasError => _validationState == _PinValidationState.error;
  bool get _isSuccessful => _validationState == _PinValidationState.success;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _tryUnlock() async {
    if (_isSuccessful) {
      return;
    }

    if (_controller.text.trim() == kDefaultAdminPin) {
      setState(() {
        _validationState = _PinValidationState.success;
      });

      await Future<void>.delayed(_successFeedbackDuration);

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
      return;
    }

    setState(() {
      _validationState = _PinValidationState.error;
    });

    _controller.clear();
    _focusNode.requestFocus();
  }

  void _handlePinChanged(String value) {
    if (_validationState == _PinValidationState.neutral) {
      return;
    }

    setState(() {
      _validationState = _PinValidationState.neutral;
    });
  }

  OutlineInputBorder _pinBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  @override
  Widget build(BuildContext context) {
    final validationColor = switch (_validationState) {
      _PinValidationState.neutral => AdminColors.border,
      _PinValidationState.error => AdminColors.danger,
      _PinValidationState.success => AdminColors.success,
    };

    final validationBorderWidth =
        _validationState == _PinValidationState.neutral ? 1.0 : 2.0;

    final focusedColor = _validationState == _PinValidationState.neutral
        ? AdminColors.accent
        : validationColor;

    final focusedBorderWidth = _validationState == _PinValidationState.neutral
        ? 1.5
        : 2.0;

    return AlertDialog(
      title: const Text('Admin-Zugang'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Bitte Admin-PIN eingeben.'),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('admin-pin-field'),
            controller: _controller,
            focusNode: _focusNode,
            autofocus: true,
            obscureText: true,
            readOnly: _isSuccessful,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'PIN',
              border: _pinBorder(validationColor, width: validationBorderWidth),
              enabledBorder: _pinBorder(
                validationColor,
                width: validationBorderWidth,
              ),
              focusedBorder: _pinBorder(
                focusedColor,
                width: focusedBorderWidth,
              ),
              errorBorder: _pinBorder(AdminColors.danger, width: 2),
              focusedErrorBorder: _pinBorder(AdminColors.danger, width: 2),
              errorText: _hasError
                  ? 'Falsche PIN. Bitte erneut versuchen.'
                  : null,
              errorStyle: const TextStyle(color: AdminColors.danger),
              helperText: _isSuccessful ? 'PIN korrekt.' : null,
              helperStyle: const TextStyle(
                color: AdminColors.success,
                fontWeight: FontWeight.w600,
              ),
            ),
            onChanged: _handlePinChanged,
            onSubmitted: (_) => _tryUnlock(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSuccessful
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AdminColors.accent),
          onPressed: _isSuccessful ? null : _tryUnlock,
          child: const Text('Öffnen'),
        ),
      ],
    );
  }
}
