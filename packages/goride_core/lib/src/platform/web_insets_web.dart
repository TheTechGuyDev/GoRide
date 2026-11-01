import 'dart:js_interop';

import 'package:flutter/widgets.dart';

@JS('gorideSafeInsets')
external JSArray<JSNumber>? _gorideSafeInsets();

EdgeInsets readWebSafeInsets() {
  try {
    final values = _gorideSafeInsets()?.toDart;
    if (values == null || values.length < 2) return EdgeInsets.zero;
    return EdgeInsets.only(
      top: values[0].toDartDouble,
      bottom: values[1].toDartDouble,
    );
  } catch (_) {
    return EdgeInsets.zero;
  }
}
