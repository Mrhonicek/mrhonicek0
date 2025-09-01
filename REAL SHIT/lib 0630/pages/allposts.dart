import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AllPosts extends StatefulWidget {
  const AllPosts({super.key});

  @override
  _AllPostsState createState() => _AllPostsState();
}

class _AllPostsState extends State<AllPosts> {
  final SupabaseClient supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _fetchPosts();
  }

  List<dynamic> _posts = [];

  Future<void> _fetchPosts() async {
    final postData = await supabase
        .from('posts')
        .select('''user_id, post_body, from:user_id( username )''').order(
            'posted_at',
            ascending: false);

    setState(() {
      _posts = postData as List<dynamic>;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      child: _posts.isEmpty
          ? Text('No posts yet')
          : ListView.builder(
              itemCount: _posts.length,
              itemBuilder: (context, index) {
                final post = _posts[index];
                return Card(
                  margin: EdgeInsets.symmetric(vertical: 10),
                  child: ListTile(
                    title: Text('${post['post_header']}'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${post['from']}'),
                        Text(post['post_body']),
                        SizedBox(height: 5),
                        Text(
                          'Posted at: ${post['posted_at']}',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
