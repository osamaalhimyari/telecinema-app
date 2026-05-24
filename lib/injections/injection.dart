import 'package:get_it/get_it.dart';

import 'inject_factories.dart';
import 'inject_singletons.dart';

/// GetIt shorthand, exported for the whole app (`sl<T>()`).
final sl = GetIt.instance;

/// Call from `main()` before `runApp`.
Future<void> initDependencies() async {
  await injectSingletons(sl);
  await initFactories(sl);
}
