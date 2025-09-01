import 'package:supabase_flutter/supabase_flutter.dart';

class PostService {
  Future<Map<String, String>> fetchUserDetails() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return {"username": "Guest", "email": "No Email"};

    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select('username, email')
          .eq('id', user.id)
          .single();

      return {
        "username": response['username'] ?? "Unknown",
        "email": response['email'] ?? "No Email",
      };
    } catch (e) {
      return {"username": "Error", "email": "Failed to load"};
    }
  }

  Future<void> signOut() async {
    await Supabase.instance.client.auth.signOut();
  }
}
