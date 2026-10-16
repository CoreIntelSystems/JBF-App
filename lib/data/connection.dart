// The database opens through SQLite compiled to native code on phones and
// through SQLite compiled to WebAssembly in the browser.
export 'connection_native.dart'
    if (dart.library.js_interop) 'connection_web.dart';
