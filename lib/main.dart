import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:helpers/helpers.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:window_manager/window_manager.dart';

import 'active_window/active_window.dart';
import 'app.dart';
import 'app/app.dart';
import 'app_version/app_version.dart';
import 'apps_list/apps_list.dart';
import 'argument_parser/argument_parser.dart';
import 'autostart/autostart_service.dart';
import 'hotkey/hotkey_service.dart';
import 'logs/logs.dart';
import 'native_platform/native_platform.dart';
import 'settings/cubit/settings_cubit.dart';
import 'storage/storage_repository.dart';
import 'system_tray/system_tray_manager.dart';
import 'theme/theme.dart';
import 'updates/updates.dart';
import 'window/app_window.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  // Parse command-line arguments.
  final argParser = ArgumentParser() //
    ..parseArgs(args);

  final storage = await StorageRepository.initialize(Hive);
  final nativePlatform = NativePlatform();
  await LoggingManager.initialize(verbose: argParser.verbose);

  // Handle platform errors not caught by Flutter.
  PlatformDispatcher.instance.onError = (error, stack) {
    log.e('Uncaught platform error', error, stack);
    return true;
  };

  final processRepository = ProcessRepository.init();

  final activeWindow = ActiveWindow(
    nativePlatform,
    processRepository,
    storage,
  );

  // If we receive the toggle argument, suspend or resume the active
  // window and then exit without showing the GUI.
  if (argParser.toggleActiveWindow) {
    await activeWindow.toggle();
    exit(0);
  } else {}

  final hotkeyService = HotkeyService(activeWindow);

  final appWindow = AppWindow(storage);
  appWindow.initialize();

  final settingsCubit = await SettingsCubit.init(
    autostartService: AutostartService(),
    hotkeyService: hotkeyService,
    storage: storage,
  );

  final themeCubit = await ThemeCubit.init(storage);

  // Provides information on this app from the pubspec.yaml.
  final packageInfo = await PackageInfo.fromPlatform();

  final appCubit = AppCubit(
    ReleaseNotesService(
      client: http.Client(),
      repository: 'merrit/nyrna',
    ),
    storage,
    UpdateService(),
  );

  final systemTray = SystemTrayManager(appWindow);
  await systemTray.initialize();

  final appsListCubit = AppsListCubit(
    hotkeyService: hotkeyService,
    nativePlatform: nativePlatform,
    prefsCubit: settingsCubit,
    processRepository: processRepository,
    storage: storage,
    systemTrayManager: systemTray,
    appVersion: AppVersion(packageInfo),
  );

  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider.value(value: appCubit),
        BlocProvider.value(value: appsListCubit),
        BlocProvider.value(value: settingsCubit),
        BlocProvider.value(value: themeCubit),
      ],
      child: const App(),
    ),
  );
}
