import 'package:flutter/material.dart';

import '../models/party_user.dart';
import '../services/party_repository.dart';

class VotingScreen extends StatelessWidget {
  const VotingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = PartyRepository();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Votación'),
        automaticallyImplyLeading: false,
      ),
      body: StreamBuilder<List<PartyUser>>(
        stream: repository.watchUsers(),
        builder: (context, usersSnapshot) {
          if (!usersSnapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final users = usersSnapshot.data!;

          return StreamBuilder<Set<String>>(
            stream: repository.watchMyLikes(),
            builder: (context, likesSnapshot) {
              final likes = likesSnapshot.data ?? {};

              final visibleUsers = users
                  .where(
                    (user) => user.uid != repository.currentUid,
                  )
                  .toList();

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: visibleUsers.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1),
                itemBuilder: (context, index) {
                  final user = visibleUsers[index];

                  final liked = likes.contains(user.uid);

                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(
                        '${index + 1}',
                      ),
                    ),
                    title: Text(
                      user.displayName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    trailing: IconButton(
                      iconSize: 32,
                      onPressed: () {
                        repository.toggleLike(
                          targetUid: user.uid,
                          currentlyLiked: liked,
                        );
                      },
                      icon: Icon(
                        liked
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: liked ? Colors.red : null,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}