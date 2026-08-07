import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String normalizeName(String name) {
    return name.trim().toLowerCase();
  }

  Future<void> login({
    required String name,
    required String password,
  }) async {
    final loginKey = normalizeName(name);

    final alias = await _firestore
        .collection('loginAliases')
        .doc(loginKey)
        .get();

    if (!alias.exists) {
      throw Exception('Nombre o contraseña incorrectos.');
    }

    final email = alias.data()!['email'] as String;

    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException {
      throw Exception('Nombre o contraseña incorrectos.');
    }
  }

  Stream<User?> authStateChanges() {
    return _auth.authStateChanges();
  }

  Future<bool> isAdmin(String uid) async {
    final doc = await _firestore
        .collection('admins')
        .doc(uid)
        .get();

    return doc.exists;
  }
}