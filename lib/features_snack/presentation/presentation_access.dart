import 'package:flutter/material.dart';
import 'package:snackautomat_yakup_leandro/features_snack/presentation/presentation_screen.dart';
import 'package:snackautomat_yakup_leandro/features_snack/screens/admin/admin_theme.dart';
import 'package:snackautomat_yakup_leandro/features_snack/services/admin_access.dart';

/// PIN-geschützter Einstieg in die Flutter-Präsentation.
Future<void> openPresentationArea(BuildContext context) async {
  final granted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _PresentationPinDialog(),
  );
  if (granted != true || !context.mounted) return;

  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => const PresentationScreen(),
    ),
  );
}

class _PresentationPinDialog extends StatefulWidget {
  const _PresentationPinDialog();

  @override
  State<_PresentationPinDialog> createState() => _PresentationPinDialogState();
}

class _PresentationPinDialogState extends State<_PresentationPinDialog> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _error = false;
  bool _ok = false;

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _try() async {
    if (_ok) return;
    if (_controller.text.trim() == kDefaultAdminPin) {
      setState(() {
        _ok = true;
        _error = false;
      });
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;
      Navigator.of(context).pop(true);
      return;
    }
    setState(() => _error = true);
    _controller.clear();
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Präsentation'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('PIN eingeben, um die Präsentation zu öffnen.'),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            focusNode: _focus,
            autofocus: true,
            obscureText: true,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'PIN',
              errorText: _error ? 'Falsche PIN.' : null,
              helperText: _ok ? 'PIN korrekt.' : null,
              helperStyle: const TextStyle(
                color: AdminColors.success,
                fontWeight: FontWeight.w600,
              ),
            ),
            onChanged: (_) {
              if (_error) setState(() => _error = false);
            },
            onSubmitted: (_) => _try(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AdminColors.accent),
          onPressed: _ok ? null : _try,
          child: const Text('Öffnen'),
        ),
      ],
    );
  }
}
