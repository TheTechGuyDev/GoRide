// Safe-area insets (notch / home bar) for the web preview.
// Native apps get these from the OS automatically; on the web we read them
// from CSS env(safe-area-inset-*) via a helper in web/index.html.
export 'web_insets_stub.dart'
    if (dart.library.js_interop) 'web_insets_web.dart';
