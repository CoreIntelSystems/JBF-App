// Field-phone batches are built from database copies, which only exist on
// phones.
export 'collection_batch_native.dart'
    if (dart.library.js_interop) 'collection_batch_web.dart';
