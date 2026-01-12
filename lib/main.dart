import 'package:compus_connect/bloc/auth_bloc.dart';
import 'package:compus_connect/pages/app_loading.dart';
import 'package:compus_connect/pages/loginPage.dart';
import 'package:compus_connect/pages/role_gate.dart';
import 'package:compus_connect/utilities/supabase_keys.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AppBootstrap());
}

class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key});

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  late final Future<Supabase> _initFuture;

  @override
  void initState() {
    super.initState();
    _initFuture = Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Supabase>(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: _buildTheme(),
            home: const AppLoadingPage(),
          );
        }

        if (snapshot.hasError) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: _buildTheme(),
            home: const AppLoadingPage(
              message: 'Startup failed. Please restart.',
              showSpinner: false,
            ),
          );
        }

        return ProviderScope(
          child: MultiBlocProvider(
            providers: [
              BlocProvider(
                create: (_) => AuthBloc()..add(const AuthCheckRequested()),
              ),
            ],
            child: const MyApp(),
          ),
        );
      },
    );
  }
}

ThemeData _buildTheme() {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.cyan),
    fontFamily: 'inter',
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      home: const RoleGate(fallback: LoginPage()),
    );
  }
}
