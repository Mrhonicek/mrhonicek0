import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:photo_view/photo_view.dart';
import 'package:timeago/timeago.dart' as timeago;

// Comments Screen
class CommentsScreen extends StatefulWidget {
  final String postId;
  final String postHeader;
  final String currentUserId;
  final String? imageUrl;

  const CommentsScreen({
    Key? key,
    required this.postId,
    required this.postHeader,
    required this.currentUserId,
    this.imageUrl,
  }) : super(key: key);

  @override
  _CommentsScreenState createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  final TextEditingController _commentController = TextEditingController();
  List<CommentData> _comments = [];
  bool _isLoading = true;
  String? _editingCommentId;

  // Vote related state
  PostVoteData? _currentUserVote;
  int _upvoteCount = 0;
  int _downvoteCount = 0;
  bool _isVoting = false;

  @override
  void initState() {
    super.initState();
    _fetchComments();
    _fetchVoteData();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _fetchComments() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final supabase = Supabase.instance.client;

      // Fetch comments with join to profiles to get username
      final response = await supabase
          .from('comments_on_posts')
          .select('''
            comment_id, 
            comment_content, 
            created_at, 
            commented_by,
            profiles:commented_by (username, first_name, last_name)
          ''')
          .eq('postid', widget.postId)
          .order('created_at', ascending: false);

      if (response != null) {
        setState(() {
          _comments = (response as List<dynamic>).map((item) {
            // Get profile info from the joined table
            final profile = item['profiles'] as Map<String, dynamic>;
            final String displayName = _getDisplayName(profile);

            return CommentData(
              id: item['comment_id'],
              content: item['comment_content'],
              createdAt: DateTime.parse(item['created_at']),
              userId: item['commented_by'],
              userName: displayName,
            );
          }).toList();
          _isLoading = false;
        });
      }
    } catch (error) {
      print('Error fetching comments: $error');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchVoteData() async {
    try {
      final supabase = Supabase.instance.client;

      // Fetch current user's vote
      final userVoteResponse = await supabase
          .from('posts_users_vote')
          .select('id, post_vote_type')
          .eq('post_id', widget.postId)
          .eq('user_id', widget.currentUserId)
          .maybeSingle();

      // Fetch vote counts
      final voteCountsResponse = await supabase
          .from('posts_users_vote')
          .select('post_vote_type')
          .eq('post_id', widget.postId);

      setState(() {
        // Set current user vote
        if (userVoteResponse != null) {
          _currentUserVote = PostVoteData(
            id: userVoteResponse['id'],
            voteType: userVoteResponse['post_vote_type'],
          );
        } else {
          _currentUserVote = null;
        }

        // Calculate vote counts
        if (voteCountsResponse != null) {
          final votes = voteCountsResponse as List<dynamic>;
          _upvoteCount =
              votes.where((vote) => vote['post_vote_type'] == 'upvote').length;
          _downvoteCount = votes
              .where((vote) => vote['post_vote_type'] == 'downvote')
              .length;
        }
      });
    } catch (error) {
      print('Error fetching vote data: $error');
    }
  }

  Future<void> _handleVote(String voteType) async {
    if (_isVoting) return;

    setState(() {
      _isVoting = true;
    });

    try {
      final supabase = Supabase.instance.client;

      // If user already has the same vote, remove it
      if (_currentUserVote?.voteType == voteType) {
        await supabase
            .from('posts_users_vote')
            .delete()
            .eq('id', _currentUserVote!.id);
      }
      // If user has a different vote, update it
      else if (_currentUserVote != null) {
        await supabase.from('posts_users_vote').update(
            {'post_vote_type': voteType}).eq('id', _currentUserVote!.id);
      }
      // If user has no vote, create new one
      else {
        await supabase.from('posts_users_vote').insert({
          'post_id': widget.postId,
          'user_id': widget.currentUserId,
          'post_vote_type': voteType,
        });
      }

      // Refresh vote data
      await _fetchVoteData();
    } catch (error) {
      print('Error handling vote: $error');
    } finally {
      setState(() {
        _isVoting = false;
      });
    }
  }

  String _getDisplayName(Map<String, dynamic> profile) {
    // Always show username if available
    if (profile['username'] != null &&
        profile['username'].toString().trim().isNotEmpty) {
      return profile['username'];
    } else if (profile['first_name'] != null && profile['last_name'] != null) {
      return '${profile['first_name']} ${profile['last_name']}';
    } else if (profile['first_name'] != null) {
      return profile['first_name'];
    } else {
      return 'Anonymous';
    }
  }

  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty) return;

    try {
      final supabase = Supabase.instance.client;

      if (_editingCommentId != null) {
        // Update existing comment
        await supabase.from('comments_on_posts').update({
          'comment_content': _commentController.text.trim(),
        }).match({'comment_id': _editingCommentId!});

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Comment updated")),
        );
      } else {
        // Add new comment
        await supabase.from('comments_on_posts').insert({
          'postid': widget.postId,
          'comment_content': _commentController.text.trim(),
          'commented_by': widget.currentUserId,
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Comment added")),
        );
      }

      // Clear input and refresh comments
      _commentController.clear();
      setState(() {
        _editingCommentId = null;
      });
      _fetchComments();
    } catch (error) {
      print('Error saving comment: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to save comment")),
      );
    }
  }

  void _editComment(CommentData comment) {
    setState(() {
      _editingCommentId = comment.id;
      _commentController.text = comment.content;
    });

    // Focus on the text field
    FocusScope.of(context).requestFocus(FocusNode());
  }

  Future<void> _deleteComment(String commentId) async {
    try {
      final supabase = Supabase.instance.client;
      await supabase
          .from('comments_on_posts')
          .delete()
          .match({'comment_id': commentId});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Comment deleted")),
      );

      _fetchComments();
    } catch (error) {
      print('Error deleting comment: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to delete comment")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Comments'),
        elevation: 1,
      ),
      body: Column(
        children: [
          // Post header
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.postHeader,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 12),
                  // Vote buttons
                  Row(
                    children: [
                      // Upvote button
                      GestureDetector(
                        onTap: _isVoting ? null : () => _handleVote('upvote'),
                        child: Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _currentUserVote?.voteType == 'upvote'
                                ? Colors.green.shade100
                                : Colors.transparent,
                            border: Border.all(
                              color: _currentUserVote?.voteType == 'upvote'
                                  ? Colors.green
                                  : Colors.grey.shade400,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.thumb_up,
                                size: 16,
                                color: _currentUserVote?.voteType == 'upvote'
                                    ? Colors.green
                                    : Colors.grey.shade600,
                              ),
                              SizedBox(width: 4),
                              Text(
                                _upvoteCount.toString(),
                                style: TextStyle(
                                  color: _currentUserVote?.voteType == 'upvote'
                                      ? Colors.green
                                      : Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      // Downvote button
                      GestureDetector(
                        onTap: _isVoting ? null : () => _handleVote('downvote'),
                        child: Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _currentUserVote?.voteType == 'downvote'
                                ? Colors.red.shade100
                                : Colors.transparent,
                            border: Border.all(
                              color: _currentUserVote?.voteType == 'downvote'
                                  ? Colors.red
                                  : Colors.grey.shade400,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.thumb_down,
                                size: 16,
                                color: _currentUserVote?.voteType == 'downvote'
                                    ? Colors.red
                                    : Colors.grey.shade600,
                              ),
                              SizedBox(width: 4),
                              Text(
                                _downvoteCount.toString(),
                                style: TextStyle(
                                  color:
                                      _currentUserVote?.voteType == 'downvote'
                                          ? Colors.red
                                          : Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: GestureDetector(
                onTap: () => _showZoomableImage(widget.imageUrl!),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    widget.imageUrl!,
                    width: double.infinity,
                    height: 200, // medium‑height "banner" style
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),

          // Comments list
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _comments.isEmpty
                    ? Center(
                        child:
                            Text('No comments yet. Be the first to comment!'))
                    : ListView.builder(
                        itemCount: _comments.length,
                        padding: EdgeInsets.all(16),
                        itemBuilder: (context, index) {
                          final comment = _comments[index];
                          final bool isOwner =
                              comment.userId == widget.currentUserId;

                          return Card(
                            margin: EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          comment.userName,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          Text(
                                            timeago.format(comment.createdAt),
                                            style: TextStyle(
                                              color: Colors.grey,
                                              fontSize: 12,
                                            ),
                                          ),
                                          if (isOwner)
                                            PopupMenuButton<String>(
                                              icon: Icon(Icons.more_vert,
                                                  size: 18),
                                              onSelected: (String value) {
                                                if (value == 'Edit') {
                                                  _editComment(comment);
                                                } else if (value == 'Delete') {
                                                  _showDeleteCommentConfirmation(
                                                      context, comment.id);
                                                }
                                              },
                                              itemBuilder:
                                                  (BuildContext context) => [
                                                PopupMenuItem<String>(
                                                  value: 'Edit',
                                                  child: Text('Edit'),
                                                ),
                                                PopupMenuItem<String>(
                                                  value: 'Delete',
                                                  child: Text('Delete'),
                                                ),
                                              ],
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    comment.content,
                                    style: TextStyle(fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),

          // Comment input
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: _editingCommentId != null
                          ? 'Edit your comment...'
                          : 'Add a comment...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    maxLines: null,
                  ),
                ),
                SizedBox(width: 8),
                if (_editingCommentId != null)
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () {
                      setState(() {
                        _editingCommentId = null;
                        _commentController.clear();
                      });
                    },
                  ),
                IconButton(
                  icon: Icon(Icons.send),
                  color: Theme.of(context).primaryColor,
                  onPressed: _addComment,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showZoomableImage(String imageUrl) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Center(
              child: PhotoView(
                imageProvider: NetworkImage(imageUrl),
                backgroundDecoration: BoxDecoration(color: Colors.black),
                minScale: PhotoViewComputedScale.contained * 1.0,
                maxScale: PhotoViewComputedScale.covered * 2.5,
              ),
            ),
            Positioned(
              top: 24,
              right: 24,
              child: IconButton(
                icon: Icon(Icons.close, color: Colors.white, size: 32),
                onPressed: () {
                  Navigator.of(dialogContext).pop(); // Use dialogContext!
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDeleteCommentConfirmation(
      BuildContext context, String commentId) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Delete Comment"),
          content: Text("Are you sure you want to delete this comment?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _deleteComment(commentId);
              },
              child: Text("Delete", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }
}

// Class to hold comment data
class CommentData {
  final String id;
  final String content;
  final DateTime createdAt;
  final String userId;
  final String userName;

  CommentData({
    required this.id,
    required this.content,
    required this.createdAt,
    required this.userId,
    required this.userName,
  });
}

// Class to hold vote data
class PostVoteData {
  final String id;
  final String voteType;

  PostVoteData({
    required this.id,
    required this.voteType,
  });
}
