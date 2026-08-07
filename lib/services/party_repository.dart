import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/party_user.dart';

class PartyRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get currentUid => _auth.currentUser!.uid;

  Stream<List<PartyUser>> watchUsers() {
    return _db
        .collection('profiles')
        .orderBy('createdAt')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(PartyUser.fromFirestore)
              .toList(),
        );
  }

  Stream<Set<String>> watchMyLikes() {
    return _db
        .collection('likes')
        .where('fromUid', isEqualTo: currentUid)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => doc.data()['targetUid'] as String)
              .toSet(),
        );
  }

  Future<void> toggleLike({
    required String targetUid,
    required bool currentlyLiked,
  }) async {
    if (targetUid == currentUid) return;

    final likeId = '${currentUid}_$targetUid';

    final likeRef = _db.collection('likes').doc(likeId);
    final eventRef = _db.collection('likeEvents').doc();

    final batch = _db.batch();

    if (currentlyLiked) {
      batch.delete(likeRef);

      batch.set(eventRef, {
        'fromUid': currentUid,
        'targetUid': targetUid,
        'action': 'unlike',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      batch.set(likeRef, {
        'fromUid': currentUid,
        'targetUid': targetUid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      batch.set(eventRef, {
        'fromUid': currentUid,
        'targetUid': targetUid,
        'action': 'like',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }
}