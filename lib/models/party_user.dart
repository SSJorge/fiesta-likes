import 'package:cloud_firestore/cloud_firestore.dart';

class PartyUser {
  final String uid;
  final String displayName;
  final Timestamp? createdAt;

  PartyUser({
    required this.uid,
    required this.displayName,
    required this.createdAt,
  });

  factory PartyUser.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;

    return PartyUser(
      uid: doc.id,
      displayName: data['displayName'] as String,
      createdAt: data['createdAt'] as Timestamp?,
    );
  }
}