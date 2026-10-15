import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/shell.dart';
import 'screens/welcome_screen.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
  );
  final state = await AppState.load();
  runApp(DolabimApp(state: state));
  // Hava durumu arka planda gelir, ekranlar gelince kendini günceller.
  state.refreshWeather();
}

class DolabimApp extends StatefulWidget {
  const DolabimApp({super.key, required this.state});

  final AppState state;

  @override
  State<DolabimApp> createState() => _DolabimAppState();
}

class _DolabimAppState extends State<DolabimApp> {
  // Başlangıç ekranı sadece açılışta belirlenir, sonradan değişmez.
  late final bool _startOnboarded = widget.state.onboarded;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: widget.state,
      child: ListenableBuilder(
        listenable: widget.state,
        builder: (context, _) => MaterialApp(
          title: 'Dolabım',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(widget.state.palette),
          themeAnimationDuration: const Duration(milliseconds: 600),
          themeAnimationCurve: Curves.easeOutCubic,
          home: _startOnboarded ? const AppShell() : const WelcomeScreen(),
        ),
      ),
    );
  }
}
