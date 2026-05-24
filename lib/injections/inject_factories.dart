import 'package:get_it/get_it.dart';

import '/features/rooms/injections/rooms_injection.dart';
import '/features/watch/injections/watch_injection.dart';

/// Short-lived bloc/cubit factories — a fresh instance every time a page opens.
Future<void> initFactories(GetIt sl) async {
  await injectRoomsFactories(sl);
  await injectWatchFactories(sl);
}
