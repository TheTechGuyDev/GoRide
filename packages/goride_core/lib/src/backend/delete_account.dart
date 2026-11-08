import 'package:flutter/material.dart';

import 'package:supabase_flutter/supabase_flutter.dart' show FunctionException;

import 'backend.dart';

/// "Delete my account": asks the user to type DELETE, then removes the
/// account on the server. Returns true when deleted (the caller signs out).
Future<bool> confirmDeleteAccount(BuildContext context) async {
  final text = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: const Text('Delete your account?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This permanently deletes your profile, photo, saved places, '
              'cards and contacts. You will be signed out and cannot undo this.\n\n'
              'Trip and payment records are kept without your name, as the law '
              'requires. Any money left in your wallet is lost.',
            ),
            const SizedBox(height: 14),
            TextField(
              controller: text,
              onChanged: (_) => set(() {}),
              decoration: const InputDecoration(
                labelText: 'Type DELETE to confirm',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: text.text.trim().toUpperCase() == 'DELETE'
                ? () => Navigator.pop(ctx, true)
                : null,
            child: const Text('Delete account'),
          ),
        ],
      ),
    ),
  );
  if (ok != true || !context.mounted) return false;
  final messenger = ScaffoldMessenger.of(context);
  try {
    await Backend.db.functions.invoke('delete-account');
    messenger.showSnackBar(
      const SnackBar(content: Text('Your account has been deleted.')),
    );
    return true;
  } catch (e) {
    final msg = e is FunctionException && e.details is Map
        ? (e.details as Map)['error']?.toString()
        : null;
    messenger.showSnackBar(
      SnackBar(
        content: Text(msg ?? 'Could not delete the account. Try again.'),
      ),
    );
    return false;
  }
}
