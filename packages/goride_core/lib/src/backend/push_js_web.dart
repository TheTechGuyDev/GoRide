import 'dart:js_interop';

@JS('goridePush.permission')
external JSString _permission();

@JS('goridePush.subscribe')
external JSPromise<JSString> _subscribe(JSString key, JSBoolean ask);

String pushPermission() {
  try {
    return _permission().toDart;
  } catch (_) {
    return 'unsupported';
  }
}

Future<String> pushSubscribe(String key, bool ask) async =>
    (await _subscribe(key.toJS, ask.toJS).toDart).toDart;
