
import 'package:flutter/material.dart';
import 'package:smart_lock/screens/auth.dart';
import 'package:smart_lock/screens/home.dart';
import 'package:smart_lock/screens/splash.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:smart_lock/providers/auth_provider.dart';


import 'package:flutter_riverpod/flutter_riverpod.dart';
void main()async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
  runApp(
     const ProviderScope(child: App()),
    );
}

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return MaterialApp(
      title: 'SmartLock',
      debugShowCheckedModeBanner: false,
      theme: ThemeData().copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 63, 17, 177),
        ),
      ),
      home: authState.when(
        loading: () => const SplashScreen(),
        error: (e, _) => const AuthScreen(),
        data: (user) {
          if (user == null) {
            return AuthScreen();
          }
          return const HomeScreen();
        },
      ),
    );
  }
}
