import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'screens/admin_screen.dart';
import 'screens/login_screen.dart';
import 'screens/voting_screen.dart';
import 'services/auth_service.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final user = snapshot.data;

        if (user == null) {
          return const LoginScreen();
        }

        return FutureBuilder<bool>(
          future: AuthService().isAdmin(user.uid),
          builder: (context, adminSnapshot) {
            if (!adminSnapshot.hasData) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }

            if (adminSnapshot.data!) {
              return const AdminScreen();
            }

            return const VotingScreen();
          },
        );
      },
    );
  }
}