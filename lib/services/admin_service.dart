import 'package:cloud_functions/cloud_functions.dart';

class AdminService {
  Future<void> createParticipant({
    required String name,
    required String password,
  }) async {
    final callable = FirebaseFunctions.instance.httpsCallable(
      'createParticipant',
    );

    await callable.call({'displayName': name.trim(), 'password': password});
  }
}
