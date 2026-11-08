import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:goride_core/goride_core.dart'
    show AuthService, Backend, FunctionException, parseTime;

import '../../core/theme/admin_theme.dart';
import '../../core/widgets/ui.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../overview/overview_page.dart';

/// One key or setting an outside service needs.
class _Field {
  const _Field(this.key, this.label, {this.secret = false, this.hint = ''});
  final String key;
  final String label;

  /// Secret keys are encrypted on the server and never shown again.
  final bool secret;
  final String hint;
}

/// An outside service GoRide connects to.
class _Service {
  const _Service({
    required this.title,
    required this.icon,
    required this.what,
    required this.fields,
    required this.steps,
    this.copy = const [],
    this.applyToAuth = false,
    this.optional = false,
  });
  final String title;
  final IconData icon;
  final String what;
  final List<_Field> fields;
  final List<String> steps;

  /// Values the steps ask you to paste into the other service.
  final List<(String, String)> copy;

  /// Email and Google keys must be pushed to Supabase sign-in.
  final bool applyToAuth;
  final bool optional;
}

const _projectUrl = 'https://xucckoofhmbyrnvvbxii.supabase.co';

const _services = [
  _Service(
    title: 'Paystack (payments)',
    icon: Icons.payments_outlined,
    what: 'Wallet top-ups for riders and commission payments for drivers. Use the test keys while testing, then the live keys after Paystack verifies your business.',
    fields: [
      _Field(
        'paystack_public_key',
        'Public key',
        hint: 'pk_test_... or pk_live_...',
      ),
      _Field(
        'paystack_secret_key',
        'Secret key',
        secret: true,
        hint: 'sk_test_... or sk_live_...',
      ),
    ],
    steps: [
      'Sign in at dashboard.paystack.com (create a free account if needed).',
      'Click Settings (bottom left), then the "API Keys & Webhooks" tab.',
      'Copy the Public Key and paste it below. Click "Reveal" on the Secret Key, copy it and paste it below.',
      'On the same page, paste the Webhook URL shown below into "Test Webhook URL" (and "Live Webhook URL" when you go live), then click Save changes.',
      'Test mode uses Paystack\'s test cards, e.g. 4084 0840 8408 4081, any future date, CVV 408, PIN 0000, OTP 123456.',
    ],
    copy: [('Webhook URL', '$_projectUrl/functions/v1/paystack')],
  ),
  _Service(
    title: 'Email for sign-in codes',
    icon: Icons.mail_outline,
    what: 'Sends the 6-digit sign-in codes. Gmail works for up to about 500 emails a day; switch to a business email service later.',
    fields: [
      _Field('smtp_user', 'Gmail address (login)', hint: 'you@gmail.com'),
      _Field(
        'smtp_password',
        'Gmail app password',
        secret: true,
        hint: '16 letters, no spaces',
      ),
      _Field(
        'smtp_sender',
        'Send codes from (optional)',
        hint: 'Same as the Gmail address',
      ),
      _Field('smtp_host', 'Mail server (optional)', hint: 'smtp.gmail.com'),
      _Field('smtp_port', 'Port (optional)', hint: '465'),
    ],
    steps: [
      'Sign in to the Gmail account at myaccount.google.com and open Security.',
      'Turn on 2-Step Verification if it is off.',
      'Open myaccount.google.com/apppasswords, name it GoRide and click Create.',
      'Copy the 16-letter password, paste it below with the Gmail address, then click "Apply to sign-in".',
    ],
    applyToAuth: true,
  ),
  _Service(
    title: 'Google sign-in',
    icon: Icons.account_circle_outlined,
    what: 'The "Continue with Google" button in the rider and driver apps.',
    fields: [
      _Field(
        'google_client_id',
        'Client ID',
        hint: '...apps.googleusercontent.com',
      ),
      _Field(
        'google_client_secret',
        'Client secret',
        secret: true,
        hint: 'GOCSPX-...',
      ),
    ],
    steps: [
      'Go to console.cloud.google.com and pick (or create) the GoRide project.',
      'Open "Google Auth Platform", then Clients, then "Create client". Choose "Web application".',
      'Under "Authorised JavaScript origins" add the app address below. Under "Authorised redirect URIs" add the callback address below. Click Create.',
      'Copy the Client ID and Client secret into the boxes below, then click "Apply to sign-in".',
      'In Google Auth Platform > Audience, make sure the app is "In production" so everyone can sign in.',
    ],
    copy: [
      ('App address', 'https://thetechguydev.github.io'),
      ('Callback address', '$_projectUrl/auth/v1/callback'),
    ],
    applyToAuth: true,
  ),
  _Service(
    title: 'Supabase access token',
    icon: Icons.key_outlined,
    what: 'Lets this dashboard apply email and Google sign-in changes to Supabase for you. Stored encrypted; only used by the server.',
    fields: [
      _Field(
        'supabase_access_token',
        'Access token',
        secret: true,
        hint: 'sbp_...',
      ),
    ],
    steps: [
      'Sign in at supabase.com with the account that owns GoRide-App.',
      'Click your profile picture (top right), then Account preferences, then Access Tokens.',
      'Click "Generate new token", name it "GoRide dashboard", copy it and paste it below.',
      'If you ever delete that token in Supabase, paste a new one here.',
    ],
  ),
  _Service(
    title: 'Firebase (push notifications on Android)',
    icon: Icons.notifications_active_outlined,
    what: 'Lets the Android apps get trip and payment alerts even when the app is closed. Free. The web apps already have push without this.',
    fields: [
      _Field(
        'firebase_service_account',
        'Service account key (JSON)',
        secret: true,
        hint: 'Paste the whole contents of the downloaded .json file',
      ),
    ],
    steps: [
      'Go to console.firebase.google.com and click "Create a project". Name it GoRide (turn off Google Analytics, not needed).',
      'Click the Android icon to add an app. Package name: com.goride.goride_rider. Download google-services.json and send it to your developer.',
      'Add a second Android app with package name com.goride.goride_driver and download its google-services.json too.',
      'Click the gear icon (Project settings), then the "Service accounts" tab, then "Generate new private key". A .json file downloads.',
      'Open that file, copy everything in it and paste it below. Keep the file private: it is a password.',
    ],
  ),
  _Service(
    title: 'Map style',
    icon: Icons.map_outlined,
    what: 'GoRide uses free OpenStreetMap maps by default, so nothing is needed. Add a map style link only if you want faster or nicer maps from a provider such as MapTiler or Mapbox.',
    fields: [
      _Field(
        'map_tile_url',
        'Map tile link',
        hint: 'https://api.maptiler.com/maps/streets-v2/256/{z}/{x}/{y}.png?key=...',
      ),
    ],
    steps: [
      'Create a free account at cloud.maptiler.com.',
      'Open Maps, choose "Streets", then copy the "Raster tiles (256)" link. It must contain {z}/{x}/{y}.',
      'Under API keys, restrict the key to thetechguydev.github.io so nobody else can use it.',
      'Paste the link below. Apps pick it up the next time they open. Remove it to go back to OpenStreetMap.',
    ],
    optional: true,
  ),
  _Service(
    title: 'SMS codes (later)',
    icon: Icons.sms_outlined,
    what: 'Optional, for sending sign-in codes by SMS instead of email (costs about 4 to 8 naira per SMS). Saved for when we switch it on.',
    fields: [
      _Field('termii_api_key', 'Termii API key', secret: true),
      _Field('termii_sender_id', 'Sender ID', hint: 'GoRide'),
    ],
    steps: [
      'Create an account at termii.com and verify your business.',
      'Register a Sender ID such as "GoRide" (approval takes a few days).',
      'Copy your API key from the dashboard and paste it below with the Sender ID.',
    ],
    optional: true,
  ),
];

class IntegrationsPage extends ConsumerStatefulWidget {
  const IntegrationsPage({super.key});

  @override
  ConsumerState<IntegrationsPage> createState() => _IntegrationsPageState();
}

class _IntegrationsPageState extends ConsumerState<IntegrationsPage> {
  Map<String, Map<String, dynamic>> _saved = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await Backend.db.rpc('admin_integrations');
      setState(() {
        _saved = {
          for (final r in rows as List)
            (r as Map)['key'] as String: Map<String, dynamic>.from(r),
        };
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      toast(context, AuthService.message(e));
    }
  }

  bool get _canEdit => ref.read(sessionProvider)?.role == AdminRole.superAdmin;

  Future<void> _edit(_Field f) async {
    final ctrl = TextEditingController(
      text: f.secret ? '' : (_saved[f.key]?['value'] as String? ?? ''),
    );
    var hide = f.secret;
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(f.label),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  obscureText: hide,
                  decoration: InputDecoration(
                    hintText: f.hint,
                    suffixIcon: f.secret
                        ? IconButton(
                            icon: Icon(
                              hide
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () => setD(() => hide = !hide),
                          )
                        : null,
                  ),
                ),
                if (f.secret) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Stored encrypted on the server. After saving, only the last 4 characters are shown, and it never goes into the apps.',
                    style: TextStyle(color: AC.muted, fontSize: 12.5),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (value == null || value.isEmpty) return;
    try {
      await Backend.db.rpc(
        'admin_set_integration',
        params: {'p_key': f.key, 'p_value': value, 'p_secret': f.secret},
      );
      if (mounted) toast(context, '${f.label} saved');
    } catch (e) {
      if (mounted) toast(context, AuthService.message(e));
    }
    _load();
  }

  Future<void> _remove(_Field f) async {
    final ok = await confirm(
      context,
      title: 'Remove ${f.label}?',
      body: 'Anything that uses it stops working until you add it again.',
      ok: 'Remove',
    );
    if (!ok) return;
    try {
      await Backend.db.rpc('admin_clear_integration', params: {'p_key': f.key});
    } catch (e) {
      if (mounted) toast(context, AuthService.message(e));
    }
    _load();
  }

  Future<void> _applyAuth() async {
    try {
      await Backend.db.functions.invoke('apply-auth');
      if (mounted)
        toast(context, 'Applied. Sign-in uses the new settings now.');
    } on FunctionException catch (e) {
      final d = e.details;
      if (mounted) {
        toast(
          context,
          d is Map ? '${d['error']}' : 'Could not apply the settings.',
        );
      }
    } catch (e) {
      if (mounted) toast(context, AuthService.message(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageBody(
      children: [
        const PageHeader(
          title: 'Integrations & API keys',
          subtitle: 'Connect outside services yourself. Secret keys are encrypted on the server and never appear in the apps or the code.',
        ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()),
          )
        else
          for (final s in _services) ...[
            _serviceCard(s),
            const SizedBox(height: 16),
          ],
      ],
    );
  }

  Widget _serviceCard(_Service s) {
    final required = s.fields.where((f) => !f.label.contains('optional'));
    final connected = required.every((f) => _saved.containsKey(f.key));
    final any = s.fields.any((f) => _saved.containsKey(f.key));
    return Panel(
      title: s.title,
      subtitle: s.what,
      action: Pill(
        connected
            ? 'Connected'
            : any
            ? 'Incomplete'
            : (s.optional ? 'Not used' : 'Not set'),
        color: connected ? AC.primary : (any ? AC.orange : AC.muted),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final f in s.fields) _fieldRow(f),
          if (s.applyToAuth && _canEdit) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: GhostButton(
                label: 'Apply to sign-in',
                icon: Icons.sync,
                onPressed: _applyAuth,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(
                'How to get ${s.fields.length > 1 ? 'these' : 'this'}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AC.primary,
                ),
              ),
              childrenPadding: const EdgeInsets.only(bottom: 8),
              children: [
                for (var i = 0; i < s.steps.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          alignment: Alignment.center,
                          margin: const EdgeInsets.only(right: 10, top: 1),
                          decoration: const BoxDecoration(
                            color: AC.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${i + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            s.steps[i],
                            style: const TextStyle(height: 1.45),
                          ),
                        ),
                      ],
                    ),
                  ),
                for (final (label, value) in s.copy)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AC.field,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AC.border),
                    ),
                    child: Row(
                      children: [
                        Text(
                          '$label: ',
                          style: TextStyle(color: AC.muted, fontSize: 13),
                        ),
                        Expanded(
                          child: SelectableText(
                            value,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Copy',
                          icon: const Icon(Icons.copy, size: 18),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: value));
                            toast(context, '$label copied');
                          },
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _fieldRow(_Field f) {
    final saved = _saved[f.key];
    final when = parseTime(saved?['updated_at']);
    final shown = saved == null
        ? 'Not set'
        : f.secret
        ? '•••• •••• ${saved['last4']}'
        : (saved['value'] as String? ?? '');
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AC.border)),
      ),
      child: Row(
        children: [
          Icon(
            f.secret ? Icons.lock_outline : Icons.public,
            size: 18,
            color: saved == null ? AC.muted : AC.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  f.label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  shown,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: saved == null ? AC.muted : null,
                    fontSize: 13,
                  ),
                ),
                if (when != null)
                  Text(
                    'Updated ${ago(when)}${saved?['updated_by'] == null ? '' : ' by ${saved!['updated_by']}'}',
                    style: TextStyle(color: AC.faint, fontSize: 11.5),
                  ),
              ],
            ),
          ),
          if (_canEdit) ...[
            TextButton(
              onPressed: () => _edit(f),
              child: Text(saved == null ? 'Add' : 'Change'),
            ),
            if (saved != null)
              IconButton(
                tooltip: 'Remove',
                icon: Icon(Icons.delete_outline, color: AC.muted, size: 20),
                onPressed: () => _remove(f),
              ),
          ],
        ],
      ),
    );
  }
}
