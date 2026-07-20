import 'package:flutter/material.dart';

import 'package:snackautomat_yakup_leandro/features_snack/screens/admin/admin_screen.dart';

import 'package:snackautomat_yakup_leandro/features_snack/screens/admin/admin_theme.dart';



/// Standard-PIN für den Admin-Bereich (Schulprojekt).

const kDefaultAdminPin = '1234';



Future<void> openAdminArea(BuildContext context) async {

  final granted = await showDialog<bool>(

    context: context,

    barrierDismissible: false,

    builder: (_) => const _AdminPinDialog(),

  );



  if (granted != true || !context.mounted) {

    return;

  }



  await Navigator.of(context).push(

    MaterialPageRoute(builder: (_) => const AdminScreen()),

  );

}



class _AdminPinDialog extends StatefulWidget {

  const _AdminPinDialog();



  @override

  State<_AdminPinDialog> createState() => _AdminPinDialogState();

}



class _AdminPinDialogState extends State<_AdminPinDialog> {

  final _controller = TextEditingController();



  @override

  void dispose() {

    _controller.dispose();

    super.dispose();

  }



  void _tryUnlock() {

    if (_controller.text.trim() == kDefaultAdminPin) {

      Navigator.of(context).pop(true);

      return;

    }



    ScaffoldMessenger.of(context).showSnackBar(

      const SnackBar(content: Text('Falsche PIN.')),

    );

  }



  @override

  Widget build(BuildContext context) {

    return AlertDialog(

      title: const Text('Admin-Zugang'),

      content: Column(

        mainAxisSize: MainAxisSize.min,

        crossAxisAlignment: CrossAxisAlignment.stretch,

        children: [

          const Text('Bitte Admin-PIN eingeben.'),

          const SizedBox(height: 12),

          TextField(

            controller: _controller,

            autofocus: true,

            obscureText: true,

            keyboardType: TextInputType.number,

            decoration: const InputDecoration(

              labelText: 'PIN',

              border: OutlineInputBorder(),

            ),

            onSubmitted: (_) => _tryUnlock(),

          ),

        ],

      ),

      actions: [

        TextButton(

          onPressed: () => Navigator.of(context).pop(false),

          child: const Text('Abbrechen'),

        ),

        FilledButton(

          style: FilledButton.styleFrom(

            backgroundColor: AdminColors.accent,

          ),

          onPressed: _tryUnlock,

          child: const Text('Öffnen'),

        ),

      ],

    );

  }

}


