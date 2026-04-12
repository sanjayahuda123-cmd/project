import 'package:flutter/material.dart';
import 'package:transignition/view/Dashboard/dashboard_page.dart';
import 'package:transignition/view/Login/login_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'firebase_options.dart';

// Global ValueNotifier to handle ThemeMode dynamically without bulky packages
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);
// Global ValueNotifier for Language
final ValueNotifier<String> languageNotifier = ValueNotifier('en');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await GoogleSignIn.instance.initialize(
    serverClientId: '663205153036-0kqb11m1789n659nvfk2ajm53nh8des9.apps.googleusercontent.com',
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(393, 852), // iPhone 14 size as common baseline
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return ValueListenableBuilder<ThemeMode>(
          valueListenable: themeNotifier,
          builder: (_, ThemeMode currentMode, __) {
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              themeMode: currentMode,
              theme: ThemeData(
                useMaterial3: true,
                colorScheme: ColorScheme.fromSeed(
                  brightness: Brightness.light,
                  seedColor: const Color(0xFF1DB954),
                ),
              ),
              darkTheme: ThemeData(
                useMaterial3: true,
                colorScheme: ColorScheme.fromSeed(
                  brightness: Brightness.dark,
                  seedColor: const Color(0xFF1DB954),
                ),
              ),
              home: StreamBuilder<User?>(
                stream: FirebaseAuth.instance.authStateChanges(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Scaffold(
                      body: Center(
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  if (snapshot.hasData) {
                    return const DashboardPage();
                  }
                  return const LoginPage();
                },
              ),
            );
          },
        );
      },
    );
  }
}
