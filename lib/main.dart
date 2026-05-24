import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:path_provider/path_provider.dart';

import 'core/app_info.dart';
import 'core/constants/app_constants.dart';
import 'core/localization/app_localizations.dart';
import 'core/services/locale_service.dart';
import 'core/services/theme_service.dart';
import 'injections/injection.dart';
import 'logic/identity/identity_cubit.dart';
import 'logic/localization/locale_cubit.dart';
import 'logic/localization/locale_state.dart';
import 'logic/socket/socket_cubit.dart';
import 'logic/theme/theme_cubit.dart';
import 'logic/theme/theme_state.dart';
import 'routes/routers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HydratedBloc.storage = await HydratedStorage.build(
    storageDirectory: HydratedStorageDirectory(
      (await getApplicationDocumentsDirectory()).path,
    ),
  );
  await initDependencies();
  await AppInfo.init();
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<LocaleCubit>.value(value: sl<LocaleCubit>()),
        BlocProvider<ThemeCubit>.value(value: sl<ThemeCubit>()),
        BlocProvider<SocketCubit>.value(value: sl<SocketCubit>()),
        BlocProvider<IdentityCubit>.value(value: sl<IdentityCubit>()),
      ],
      child: BlocBuilder<LocaleCubit, LocaleState>(
        builder: (context, localeState) {
          return BlocBuilder<ThemeCubit, ThemeState>(
            builder: (context, _) {
              final themeService = sl<ThemeService>();
              return MaterialApp.router(
                title: AppConstants.appName,
                debugShowCheckedModeBanner: false,
                themeMode: themeService.themeMode,
                theme: themeService.lightTheme,
                darkTheme: themeService.darkTheme,
                locale: localeState.locale,
                supportedLocales: sl<LocaleService>().supportedLocales,
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                routerConfig: router,
              );
            },
          );
        },
      ),
    );
  }
}
