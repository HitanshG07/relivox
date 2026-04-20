import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'services/identity_service.dart';
import 'services/database_service.dart';
import 'services/communication_service.dart';
import 'services/settings_service.dart';
import 'services/notification_service.dart';
import 'services/foreground_service.dart';
import 'blocs/discovery/discovery_bloc.dart';
import 'blocs/settings/settings_bloc.dart';
import 'ui/screens/splash_screen.dart';
import 'blocs/chats/chats_bloc.dart';
import 'blocs/mic/mic_bloc.dart';
import 'blocs/mic/mic_event.dart';
import 'blocs/sos/sos_bloc.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Parallelise all independent startup inits — none depend on each other.
  // Total wait = slowest single task instead of sum of all tasks.
  final identityService = IdentityService();

  await Future.wait([
    SettingsService().init(),
    NotificationService().init(),
    ForegroundService().init(),
    identityService.init(),
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]),
  ]);

  final databaseService = DatabaseService();
  final communicationService =
      CommunicationService(identityService, databaseService);

  runApp(
    RelivoxApp(
      identityService: identityService,
      databaseService: databaseService,
      communicationService: communicationService,
    ),
  );
}

class RelivoxApp extends StatelessWidget {
  final IdentityService identityService;
  final DatabaseService databaseService;
  final CommunicationService communicationService;

  const RelivoxApp({
    super.key,
    required this.identityService,
    required this.databaseService,
    required this.communicationService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: identityService),
        RepositoryProvider.value(value: databaseService),
        RepositoryProvider.value(value: communicationService),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => DiscoveryBloc(communicationService),
          ),
          BlocProvider(
            create: (_) =>
                SettingsBloc(SettingsService())..add(SettingsLoaded()),
          ),
          BlocProvider<MicBloc>(
            create: (_) => MicBloc()..add(const LoadMicEvent()),
          ),
          BlocProvider<SosBloc>(
            create: (context) => SosBloc(
              mic: context.read<MicBloc>(),
              comm: context.read<CommunicationService>(),
            ),
          ),
          BlocProvider<ChatsBloc>(
            create: (context) => ChatsBloc(
              db: context.read<DatabaseService>(),
              comm: context.read<CommunicationService>(),
              identity: context.read<IdentityService>(),
            ),
          ),
        ],
        child: MaterialApp(
          title: 'Relivox',
          navigatorKey: NotificationService.navigatorKey,
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF6C63FF),
              brightness: Brightness.dark,
            ),
            scaffoldBackgroundColor: const Color(0xFF0D0D1A),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF13132B),
              elevation: 0,
              titleTextStyle: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600),
            ),
            useMaterial3: true,
          ),
          home: const SplashScreen(),
        ),
      ),
    );
  }
}
