import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:goride_core/goride_core.dart';

import '../../core/theme/admin_theme.dart';
import '../../core/widgets/ui.dart';

/// Pricing engine rules: rush hours, long-pickup fee, live demand,
/// Power Driver days and airport fees. Saved straight to Supabase.
class EnginePanel extends StatefulWidget {
  const EnginePanel({super.key});

  @override
  State<EnginePanel> createState() => _EnginePanelState();
}

class _EnginePanelState extends State<EnginePanel> {
  Map<String, dynamic>? _s;
  List<Map<String, dynamic>> _airports = [];
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await Backend.db
          .from('app_settings')
          .select(
            'rush_factor, rush_windows, rush_weekdays_only, demand_surge_enabled, '
            'free_pickup_km, pickup_fee_per_km, max_pickup_fee, '
            'power_driver_enabled, power_driver_trips, power_driver_rate',
          )
          .eq('id', 1)
          .single();
      final a = await Backend.db.from('airports').select().order('name');
      if (!mounted) return;
      setState(() {
        _s = Map<String, dynamic>.from(s);
        _airports = [for (final r in a) Map<String, dynamic>.from(r)];
      });
    } catch (e) {
      if (mounted) setState(() => _error = AuthService.message(e));
    }
  }

  Future<void> _save(Map<String, dynamic> patch, String done) async {
    setState(() => _busy = true);
    try {
      await Backend.db.from('app_settings').update(patch).eq('id', 1);
      setState(() => _s = {..._s!, ...patch});
      if (mounted) toast(context, done);
    } catch (e) {
      if (mounted) toast(context, AuthService.message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  List<List<int>> get _windows => [
    for (final w in (_s!['rush_windows'] as List))
      [(w[0] as num).toInt(), (w[1] as num).toInt()],
  ];

  String _hour(int h) {
    final am = h < 12;
    final x = h % 12 == 0 ? 12 : h % 12;
    return '$x${am ? 'am' : 'pm'}';
  }

  Future<void> _editWindow(int? index) async {
    final ws = _windows;
    var from = index == null ? 7 : ws[index][0];
    var to = index == null ? 10 : ws[index][1];
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: Text(index == null ? 'Add rush hour' : 'Edit rush hour'),
          content: Row(
            children: [
              Expanded(
                child: _hourPicker('From', from, (v) => set(() => from = v)),
              ),
              const SizedBox(width: 12),
              Expanded(child: _hourPicker('To', to, (v) => set(() => to = v))),
            ],
          ),
          actions: [
            if (index != null)
              TextButton(
                onPressed: () {
                  ws.removeAt(index);
                  Navigator.pop(c, true);
                },
                child: const Text('Remove', style: TextStyle(color: AC.red)),
              ),
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: to > from
                  ? () {
                      if (index == null) {
                        ws.add([from, to]);
                      } else {
                        ws[index] = [from, to];
                      }
                      Navigator.pop(c, true);
                    }
                  : null,
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (ok == true) {
      ws.sort((a, b) => a[0].compareTo(b[0]));
      await _save({'rush_windows': ws}, 'Rush hours saved');
    }
  }

  Widget _hourPicker(String label, int value, ValueChanged<int> onChanged) {
    return DropdownButtonFormField<int>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: [
        for (var h = 0; h <= 24; h++)
          DropdownMenuItem(
            value: h,
            child: Text(h == 24 ? 'Midnight' : _hour(h)),
          ),
      ],
      onChanged: (v) => v == null ? null : onChanged(v),
    );
  }

  Future<void> _editAirport(Map<String, dynamic>? a) async {
    final name = TextEditingController(text: a?['name'] as String? ?? '');
    final city = TextEditingController(text: a?['city'] as String? ?? '');
    final lat = TextEditingController(text: a == null ? '' : '${a['lat']}');
    final lng = TextEditingController(text: a == null ? '' : '${a['lng']}');
    final radius = TextEditingController(text: '${a?['radius_m'] ?? 1500}');
    final fee = TextEditingController(text: '${a?['fee'] ?? 1000}');
    var active = a?['active'] as bool? ?? true;
    final row = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: Text(a == null ? 'Add airport' : 'Edit airport'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Airport name'),
                ),
                TextField(
                  controller: city,
                  decoration: const InputDecoration(
                    labelText: 'City (e.g. Lagos)',
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: lat,
                        decoration: const InputDecoration(
                          labelText: 'Latitude',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: lng,
                        decoration: const InputDecoration(
                          labelText: 'Longitude',
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: fee,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Fee',
                          prefixText: '₦',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: radius,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Area size',
                          suffixText: 'm',
                        ),
                      ),
                    ),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: active,
                  onChanged: (v) => set(() => active = v),
                  title: const Text('Charge this fee'),
                ),
                Text(
                  'Tip: find latitude and longitude by right-clicking the airport on Google Maps.',
                  style: TextStyle(fontSize: 12, color: AC.muted),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final la = double.tryParse(lat.text.trim());
                final lo = double.tryParse(lng.text.trim());
                if (name.text.trim().isEmpty || la == null || lo == null)
                  return;
                Navigator.pop(c, {
                  'id':
                      a?['id'] ??
                      name.text.trim().toLowerCase().replaceAll(
                        RegExp(r'[^a-z0-9]+'),
                        '_',
                      ),
                  'name': name.text.trim(),
                  'city': city.text.trim().isEmpty ? null : city.text.trim(),
                  'lat': la,
                  'lng': lo,
                  'radius_m': int.tryParse(radius.text) ?? 1500,
                  'fee': int.tryParse(fee.text) ?? 0,
                  'active': active,
                });
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (row == null) return;
    try {
      await Backend.db.from('airports').upsert(row);
      await _load();
      if (mounted) toast(context, '${row['name']} saved');
    } catch (e) {
      if (mounted) {
        toast(
          context,
          AuthService.message(e).contains('foreign')
              ? 'City must be one of your GoRide cities'
              : AuthService.message(e),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    return Panel(
      title: 'Pricing engine',
      subtitle: 'Rush hours, airport fees, long pickups and Power Driver days',
      child: s == null
          ? Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                _error ?? 'Loading...',
                style: TextStyle(color: AC.muted),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _head('Rush hours (Nigeria time)'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final (i, w) in _windows.indexed)
                      ActionChip(
                        avatar: const Icon(Icons.schedule, size: 16),
                        label: Text(
                          '${_hour(w[0])} - ${w[1] == 24 ? 'midnight' : _hour(w[1])}',
                        ),
                        onPressed: _busy ? null : () => _editWindow(i),
                      ),
                    ActionChip(
                      avatar: const Icon(Icons.add, size: 16),
                      label: const Text('Add'),
                      onPressed: _busy ? null : () => _editWindow(null),
                    ),
                  ],
                ),
                _num(
                  'Rush hour time factor',
                  ((s['rush_factor'] as num) * 100 - 100).round(),
                  suffix: '%',
                  help: 'Extra trip minutes charged in traffic (max 100)',
                  onSave: (v) => _save({
                    'rush_factor': 1 + v.clamp(0, 100) / 100,
                  }, 'Rush factor saved'),
                ),
                _switch(
                  'Weekdays only',
                  'No rush pricing on Saturday and Sunday',
                  s['rush_weekdays_only'] == true,
                  (v) => _save({'rush_weekdays_only': v}, 'Saved'),
                ),
                _switch(
                  'Live demand pricing',
                  'Raise prices a little when riders outnumber free drivers (never above the surge cap)',
                  s['demand_surge_enabled'] == true,
                  (v) => _save({'demand_surge_enabled': v}, 'Saved'),
                ),
                const Divider(height: 28),
                _head('Long pickup fee'),
                _num(
                  'Free pickup distance',
                  (s['free_pickup_km'] as num).round(),
                  suffix: 'km',
                  onSave: (v) => _save({'free_pickup_km': v}, 'Saved'),
                ),
                _num(
                  'Fee per extra km (car)',
                  (s['pickup_fee_per_km'] as num).toInt(),
                  prefix: '₦',
                  help: 'Bikes pay half, kekes three quarters',
                  onSave: (v) => _save({'pickup_fee_per_km': v}, 'Saved'),
                ),
                _num(
                  'Maximum pickup fee',
                  (s['max_pickup_fee'] as num).toInt(),
                  prefix: '₦',
                  onSave: (v) => _save({'max_pickup_fee': v}, 'Saved'),
                ),
                const Divider(height: 28),
                _head('Power Driver days'),
                _switch(
                  'Power Driver days',
                  'Lower commission for the whole day once a driver hits the target',
                  s['power_driver_enabled'] == true,
                  (v) => _save({'power_driver_enabled': v}, 'Saved'),
                ),
                _num(
                  'Trips in a day',
                  (s['power_driver_trips'] as num).toInt(),
                  help: 'At least 5',
                  onSave: (v) =>
                      _save({'power_driver_trips': v < 5 ? 5 : v}, 'Saved'),
                ),
                _num(
                  'Commission on Power days',
                  (s['power_driver_rate'] as num).round(),
                  suffix: '%',
                  help: 'Between 5% and 10%, so we never lose money',
                  onSave: (v) =>
                      _save({'power_driver_rate': v.clamp(5, 10)}, 'Saved'),
                ),
                const Divider(height: 28),
                Row(
                  children: [
                    Expanded(child: _head('Airport fees')),
                    TextButton.icon(
                      onPressed: () => _editAirport(null),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add airport'),
                    ),
                  ],
                ),
                for (final a in _airports)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.flight,
                      color: a['active'] == true ? AC.primary : AC.faint,
                    ),
                    title: Text(a['name'] as String),
                    subtitle: Text(
                      '${a['city'] ?? ''}${a['active'] == true ? '' : ' · off'}',
                      style: TextStyle(color: AC.muted, fontSize: 12),
                    ),
                    trailing: Text(
                      naira((a['fee'] as num).toInt()),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    onTap: () => _editAirport(a),
                  ),
              ],
            ),
    );
  }

  Widget _head(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      t,
      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
    ),
  );

  Widget _switch(String title, String sub, bool v, ValueChanged<bool> on) =>
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: v,
        onChanged: _busy ? null : on,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(sub, style: TextStyle(color: AC.muted, fontSize: 12.5)),
      );

  Widget _num(
    String label,
    int value, {
    required ValueChanged<int> onSave,
    String? prefix,
    String? suffix,
    String? help,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (help != null)
                  Text(help, style: TextStyle(fontSize: 12, color: AC.muted)),
              ],
            ),
          ),
          SizedBox(
            width: 120,
            child: TextField(
              key: ValueKey('$label$value'),
              controller: TextEditingController(text: '$value'),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                prefixText: prefix,
                suffixText: suffix,
                helperText: 'Press Enter',
              ),
              onSubmitted: (v) {
                final n = int.tryParse(v);
                if (n != null && n != value) onSave(n);
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Which ride types can be booked in each city, and when. Closed types
/// still show in the rider app, greyed out with the reason.
class RideRulesPanel extends StatefulWidget {
  const RideRulesPanel({super.key});

  @override
  State<RideRulesPanel> createState() => _RideRulesPanelState();
}

class _RideRulesPanelState extends State<RideRulesPanel> {
  List<String> _cities = [];
  List<Map<String, dynamic>> _types = [];
  Map<String, Map<String, dynamic>> _rules = {}; // key: city|type
  String? _city;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final c = await Backend.db.from('cities').select('name').order('name');
      final t = await Backend.db
          .from('ride_types')
          .select('id, name')
          .eq('active', true)
          .order('minimum_fare');
      final r = await Backend.db.from('city_ride_rules').select();
      if (!mounted) return;
      setState(() {
        _cities = [for (final x in c) x['name'] as String];
        _types = [for (final x in t) Map<String, dynamic>.from(x)];
        _rules = {
          for (final x in r)
            '${x['city']}|${x['ride_type_id']}': Map<String, dynamic>.from(x),
        };
        _city ??= _cities.contains('Ibadan') ? 'Ibadan' : _cities.firstOrNull;
      });
    } catch (e) {
      if (mounted) setState(() => _error = AuthService.message(e));
    }
  }

  Map<String, dynamic> _rule(String type) =>
      _rules['$_city|$type'] ??
      {
        'city': _city,
        'ride_type_id': type,
        'enabled': true,
        'opens': null,
        'closes': null,
      };

  Future<void> _save(Map<String, dynamic> row, String done) async {
    try {
      await Backend.db.from('city_ride_rules').upsert(row);
      setState(() => _rules['${row['city']}|${row['ride_type_id']}'] = row);
      if (mounted) toast(context, done);
    } catch (e) {
      if (mounted) toast(context, AuthService.message(e));
    }
  }

  TimeOfDay? _parse(Object? v) {
    if (v is! String || v.length < 5) return null;
    return TimeOfDay(
      hour: int.parse(v.substring(0, 2)),
      minute: int.parse(v.substring(3, 5)),
    );
  }

  String _fmt(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    return '$h:${t.minute.toString().padLeft(2, '0')}${t.period == DayPeriod.am ? 'am' : 'pm'}';
  }

  String _db(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _editHours(String type, String name) async {
    final r = _rule(type);
    final allDay = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('$name hours in $_city'),
        content: const Text(
          'Choose set hours, or let riders book this ride type all day.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('All day'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Set hours'),
          ),
        ],
      ),
    );
    if (allDay == null || !mounted) return;
    if (allDay) {
      await _save({...r, 'opens': null, 'closes': null}, '$name: all day');
      return;
    }
    final opens = await showTimePicker(
      context: context,
      helpText: 'Opens at',
      initialTime: _parse(r['opens']) ?? const TimeOfDay(hour: 5, minute: 30),
    );
    if (opens == null || !mounted) return;
    final closes = await showTimePicker(
      context: context,
      helpText: 'Closes at',
      initialTime: _parse(r['closes']) ?? const TimeOfDay(hour: 22, minute: 30),
    );
    if (closes == null) return;
    await _save({
      ...r,
      'opens': _db(opens),
      'closes': _db(closes),
    }, '$name: ${_fmt(opens)} to ${_fmt(closes)}');
  }

  @override
  Widget build(BuildContext context) {
    return Panel(
      title: 'Ride types by city',
      subtitle: 'Turn a ride type off or set its hours. Riders see closed types greyed out with the reason.',
      child: _city == null
          ? Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                _error ?? 'Loading...',
                style: TextStyle(color: AC.muted),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final c in _cities)
                      ChoiceChip(
                        label: Text(c),
                        selected: c == _city,
                        onSelected: (_) => setState(() => _city = c),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                for (final t in _types)
                  Builder(
                    builder: (context) {
                      final id = t['id'] as String, name = t['name'] as String;
                      final r = _rule(id);
                      final on = r['enabled'] != false;
                      final o = _parse(r['opens']), cl = _parse(r['closes']);
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          !on
                              ? 'Off in $_city'
                              : (o == null || cl == null)
                              ? 'All day'
                              : '${_fmt(o)} to ${_fmt(cl)}',
                          style: TextStyle(
                            color: on ? AC.muted : AC.red,
                            fontSize: 12.5,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton(
                              onPressed: on ? () => _editHours(id, name) : null,
                              child: const Text('Hours'),
                            ),
                            Switch(
                              value: on,
                              onChanged: (v) => _save(
                                {...r, 'enabled': v},
                                v
                                    ? '$name is on in $_city'
                                    : '$name is off in $_city',
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
    );
  }
}
