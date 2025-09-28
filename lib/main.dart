import 'package:charity/admin/admin_home.dart';
import 'package:charity/client/home.dart';
import 'package:charity/forgot_pd.dart';
import 'package:charity/login.dart';
import 'package:charity/org/org_home.dart';
import 'package:charity/org/waiting_verification.dart';
import 'package:charity/onboarding/get_started.dart';
import 'package:charity/org/verify.dart';
import 'package:charity/register.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  ).then((_) {
    print("✅ Firebase Initialized");
  }).catchError((error) {
    print("❌ Firebase initialization error: $error");
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Charity Connect',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C63FF),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C63FF),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: FutureBuilder(
        future: _determineInitialScreen(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return SplashScreen(); // Show splash while loading
          }
          return snapshot.data ?? const GetStarted();
        },
      ),
      routes: {
        '/login': (context) => const LoginPage(),
        '/getStarted': (context) => const GetStarted(),
        '/home': (context) => const Home(),
        '/adminHome': (context) => const AdminHome(),
        '/orgHome': (context) => const OrgHome(),
        '/VerifyAccount': (_) => VerifyAccountPage(),
        '/WaitingVerification': (_) => WaitingVerificationPage(),
        '/forgotPassword': (context) => ForgotPasswordPage(),
        '/register': (context) => RegisterPage(),
      },
    );
  }

  /// ✅ Logic to determine initial screen
  Future<Widget?> _determineInitialScreen() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        // Not logged in
        return const GetStarted();
      }

      // Fetch user role from Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        return const GetStarted();
      }

      final role = userDoc.data()?['role'] ?? 'client';

      switch (role) {
        case 'admin':
          return const AdminHome();
        case 'org':
          return const OrgHome();
        case 'client':
        default:
          return const Home();
      }
    } catch (e) {
      print("❌ Error determining initial screen: $e");
      return const GetStarted();
    }
  }
}

class SplashScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF6C63FF),
              Color(0xFF4A90E2),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Hero(
                tag: 'app-logo',
                child: AnimatedContainer(
                  duration: const Duration(seconds: 1),
                  curve: Curves.easeInOut,
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.favorite,
                    size: 80,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 30),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 5,
              ),
              const SizedBox(height: 20),
              const Text(
                'Charity Connect',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}