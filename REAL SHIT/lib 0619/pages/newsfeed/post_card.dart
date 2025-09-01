import 'package:flutter/material.dart';
import 'package:gismultiinstancetestingenvironment/pages/editpost.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:photo_view/photo_view.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:gismultiinstancetestingenvironment/pages/newsfeed/post_comments.dart';

class PostCard extends StatefulWidget {
  final String name;
  final String timeAgo;
  final String postHeader;
  final String postBody;
  final String? imageUrl;
  final String postId;
  final String creatorUserId;
  final String currentUserId;
  final VoidCallback onDelete;

  const PostCard({
    Key? key,
    required this.name,
    required this.timeAgo,
    required this.postHeader,
    required this.postBody,
    this.imageUrl,
    required this.postId,
    required this.creatorUserId,
    required this.currentUserId,
    required this.onDelete,
  }) : super(key: key);

  @override
  _PostCardState createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  // Report dialog functionality
  Future<void> _showReportDialog(BuildContext context) async {
    List<String> reportReasons = [
      "Irrelevant",
      "Unwanted content",
      "False report",
      "Contains suspicious link",
      "Others"
    ];
    Map<String, bool> selectedReasons = {
      for (var reason in reportReasons) reason: false
    };
    TextEditingController otherReasonController = TextEditingController();

    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text("Report Post"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...reportReasons.map((reason) => CheckboxListTile(
                          title: Text(reason),
                          value: selectedReasons[reason],
                          onChanged: (bool? value) {
                            setState(() {
                              selectedReasons[reason] = value ?? false;
                            });
                          },
                        )),
                    if (selectedReasons["Others"] == true) ...[
                      TextField(
                        controller: otherReasonController,
                        decoration:
                            InputDecoration(hintText: "Describe the issue..."),
                        maxLines: 3,
                      ),
                    ]
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("Cancel", style: TextStyle(color: Colors.grey)),
                ),
                TextButton(
                  onPressed: () async {
                    List<String> selected = selectedReasons.entries
                        .where((entry) => entry.value)
                        .map((entry) => entry.key)
                        .toList();

                    if (selected.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Please select a reason.")),
                      );
                      return;
                    }

                    String reportReason = selected.join(", ");
                    String? reportDesc = selected.contains("Others")
                        ? otherReasonController.text
                        : null;

                    await _submitReport(widget.postId, widget.currentUserId,
                        reportReason, reportDesc);
                    Navigator.pop(context);
                  },
                  child: Text("Submit", style: TextStyle(color: Colors.red)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Report submission functionality
  Future<void> _submitReport(String postId, String userId, String reportReason,
      String? reportDesc) async {
    final supabase = Supabase.instance.client;
    try {
      await supabase.from('reports').insert({
        'postid': postId,
        'reported_by': userId,
        'report_reason': reportReason,
        'report_status': 'pending',
        'reported_at': DateTime.now().toIso8601String(),
        'report_desc': reportDesc
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Report submitted successfully.")),
      );
    } catch (error) {
      print('Error submitting report: $error');
    }
  }

  // Navigate to comments page
  void _navigateToComments() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CommentsScreen(
          postId: widget.postId,
          postHeader: widget.postHeader,
          currentUserId: widget.currentUserId,
          imageUrl: widget.imageUrl, // ← ADD THIS
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isOwner = widget.currentUserId == widget.creatorUserId;

    return GestureDetector(
      onTap: _navigateToComments,
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      widget.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        widget.timeAgo,
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(width: 8),
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert),
                        onSelected: (String value) {
                          switch (value) {
                            case 'Edit':
                              if (isOwner) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        EditPostScreen(postId: widget.postId),
                                  ),
                                ).then((updated) {
                                  if (updated == true) {
                                    setState(() {}); // Refresh UI
                                  }
                                });
                              }
                              break;
                            case 'Delete':
                              if (isOwner) _showDeleteConfirmation(context);
                              break;
                            case 'Report':
                              _showReportDialog(context);
                              break;
                            case 'Comments':
                              _navigateToComments();
                              break;
                          }
                        },
                        itemBuilder: (BuildContext context) {
                          List<PopupMenuItem<String>> items = [];

                          // Add Edit/Delete options for post owner
                          if (isOwner) {
                            items.addAll([
                              PopupMenuItem<String>(
                                value: 'Edit',
                                child: Text('Edit'),
                              ),
                              /* PopupMenuItem<String>(
                                value: 'Delete',
                                child: Text('Delete'),
                              ),*/
                            ]);
                          } else {
                            items.add(PopupMenuItem<String>(
                              value: 'Report',
                              child: Text('Report'),
                            ));
                          }

                          // Add Comments option for all users
                          items.add(PopupMenuItem<String>(
                            value: 'Comments',
                            child: Text('Comments'),
                          ));

                          return items;
                        },
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(widget.postHeader,
                  style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text(widget.postBody),
              if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty) ...[
                SizedBox(height: 10),
                Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: 200,
                      maxHeight: double.infinity,
                    ),
                    child: Image.network(
                      widget.imageUrl!,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ],

              // Comment indicator
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: Row(
                  children: [
                    Icon(Icons.comment_outlined, size: 16, color: Colors.grey),
                    SizedBox(width: 4),
                    Text(
                      "View comments",
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showDeleteConfirmation(BuildContext context) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Delete Post"),
          content: Text("Are you sure you want to delete this post?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("No", style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await _deletePost();
              },
              child: Text("Yes", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deletePost() async {
    final supabase = Supabase.instance.client;
    try {
      await supabase.from('posts').delete().match({'postid': widget.postId});
      widget.onDelete();
    } catch (error) {
      print('Error deleting post: $error');
    }
  }
}
