import 'package:compus_connect/bloc/auth_bloc.dart';
import 'package:compus_connect/pages/loginPage.dart';
import 'package:compus_connect/pages/role_gate.dart';
import 'package:compus_connect/utilities/supabase_keys.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );
  runApp(
    ProviderScope(
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => AuthBloc()..add(const AuthCheckRequested()),
          ),
        ],
        child: const MyApp(),
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.cyan),
        fontFamily: 'inter',
      ),

      home: const RoleGate(fallback: LoginPage()),
    );
  }
}
