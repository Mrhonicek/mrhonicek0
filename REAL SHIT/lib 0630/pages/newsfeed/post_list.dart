import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'post_card.dart';

class PostList extends StatefulWidget {
  const PostList({Key? key}) : super(key: key);

  @override
  _PostListState createState() => _PostListState();
}

class _PostListState extends State<PostList> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> posts = [];
  bool isLoading = true;
  String currentUserId = '';

  @override
  void initState() {
    super.initState();
    fetchUserAndPosts();
  }

  Future<void> fetchUserAndPosts() async {
    try {
      // Fetch current user ID
      final user = supabase.auth.currentUser;
      if (user != null) {
        setState(() {
          currentUserId = user.id;
        });
      }

      // Fetch posts
      final response = await supabase
          .from('posts')
          .select(
              'postid, post_header, post_body, post_image_url, posted_at,  post_status,profiles(username, id)')
          .eq('post_status', 'active')
          .order('posted_at', ascending: false);

      setState(() {
        posts = response;
        isLoading = false;
      });
    } catch (error) {
      print('Error fetching posts: $error');
      setState(() {
        isLoading = false;
      });
    }
  }

  void _removePost(String postId) {
    setState(() {
      posts.removeWhere((post) => post['postid'] == postId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return isLoading
        ? Center(child: CircularProgressIndicator())
        : ListView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              return PostCard(
                postId: post['postid'],
                name: post['profiles']?['username'] ?? 'Unknown User',
                creatorUserId: post['profiles']?['id'] ?? '', // Owner's ID
                currentUserId: currentUserId, // Logged-in user ID
                timeAgo: DateFormat('MMM d, y hh:mm a')
                    .format(DateTime.parse(post['posted_at'])),
                postHeader: post['post_header'] ?? 'No title available',
                postBody: post['post_body'] ?? 'No content available',
                imageUrl: post['post_image_url'],
                onDelete: () => _removePost(post['postid']),
              );
            },
          );
  }
}
