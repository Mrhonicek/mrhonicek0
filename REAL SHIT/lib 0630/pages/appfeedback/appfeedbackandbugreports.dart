import 'package:flutter/material.dart';
import 'package:gismultiinstancetestingenvironment/pages/appfeedback/myreportspage.dart';
import 'package:gismultiinstancetestingenvironment/pages/newsfeed/newsfeed.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';

// Import your NewsFeed page - adjust the import path as needed
// import 'package:your_app/pages/news_feed.dart';

class FeedbackBugReportsPage extends StatefulWidget {
  @override
  _FeedbackBugReportsPageState createState() => _FeedbackBugReportsPageState();
}

class _FeedbackBugReportsPageState extends State<FeedbackBugReportsPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool isBugReport = false;
  File? screenshot;
  bool isSubmitting = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _pickScreenshot() async {
    try {
      final pickedFile = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          screenshot = File(pickedFile.path);
        });

        // Show confirmation
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Screenshot attached successfully'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      _showErrorSnackBar('Failed to pick image: $e');
    }
  }

  Future<void> _removeScreenshot() async {
    setState(() {
      screenshot = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.info, color: Colors.white),
            SizedBox(width: 8),
            Text('Screenshot removed'),
          ],
        ),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<String?> _uploadScreenshot() async {
    if (screenshot == null) return null;

    try {
      final fileName =
          'screenshot_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final bytes = await screenshot!.readAsBytes();

      await supabase.storage
          .from('feedback-screenshots')
          .uploadBinary('$fileName', bytes);

      final publicUrl =
          supabase.storage.from('feedback-screenshots').getPublicUrl(fileName);

      return publicUrl;
    } catch (e) {
      print('Screenshot upload error: $e');
      return null;
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isSubmitting = true;
    });

    try {
      // Upload screenshot if exists
      String? screenshotUrl;
      if (screenshot != null) {
        screenshotUrl = await _uploadScreenshot();
      }

      // Get current user
      final user = supabase.auth.currentUser;

      // Insert into database
      await supabase.from('bugreportsandfeedback').insert({
        'user_id': user?.id,
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'is_bug_report': isBugReport,
        'screenshot_url': screenshotUrl,
        'status': 'open',
        'priority': isBugReport ? 'high' : 'medium',
      });

      // Show success message
      _showSuccessDialog();
    } catch (e) {
      _showErrorSnackBar('Failed to submit: $e');
    } finally {
      setState(() {
        isSubmitting = false;
      });
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 64,
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Thank You!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              SizedBox(height: 8),
              Text(
                isBugReport
                    ? 'Your bug report has been submitted successfully. We\'ll investigate and get back to you soon.'
                    : 'Your feedback has been submitted successfully. Thank you!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => NewsFeed(),
                      ),
                      (route) => false, // This removes all previous routes
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Continue'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error, color: Colors.white),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Feedback & Bug Report',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: Icon(Icons.chat),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => MyReportsPage()),
              );
            },
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header section
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Icon(
                        isBugReport ? Icons.bug_report : Icons.feedback,
                        size: 48,
                        color: isBugReport ? Colors.red : Colors.blue,
                      ),
                      SizedBox(height: 12),
                      Text(
                        isBugReport ? 'Report a Bug' : 'Share Feedback',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        isBugReport
                            ? 'Help us fix issues and improve the app'
                            : 'Help us make the app better for everyone',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 24),

                // Type selector
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Type of Report',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              isBugReport
                                  ? 'Bug Report - Something isn\'t working'
                                  : 'Feedback - Suggestions or comments',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        value: isBugReport,
                        onChanged: (val) {
                          setState(() => isBugReport = val);
                        },
                        activeColor: Colors.red,
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 20),

                // Title field
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextFormField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: 'Title *',
                      hintText: isBugReport
                          ? 'Brief description of the bug'
                          : 'Summary of your feedback',
                      prefixIcon: Icon(Icons.title),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Please enter a title'
                        : null,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ),

                SizedBox(height: 20),

                // Description field
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextFormField(
                    controller: _descriptionController,
                    decoration: InputDecoration(
                      labelText: 'Description *',
                      hintText: isBugReport
                          ? 'Please describe the bug in detail. Include steps to reproduce if possible.'
                          : 'Please share your feedback or suggestions in detail.',
                      prefixIcon: Icon(Icons.description),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      alignLabelWithHint: true,
                    ),
                    maxLines: 6,
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Please enter a description'
                        : null,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ),

                SizedBox(height: 20),

                // Screenshot section
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.image, color: Colors.grey[600]),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Screenshot (Optional)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  'A picture can help us understand better',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      if (screenshot == null)
                        OutlinedButton.icon(
                          onPressed: _pickScreenshot,
                          icon: Icon(Icons.add_a_photo),
                          label: Text('Add Screenshot'),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        )
                      else
                        Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                screenshot!,
                                height: 120,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                            SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _pickScreenshot,
                                    icon: Icon(Icons.swap_horiz),
                                    label: Text('Change'),
                                    style: OutlinedButton.styleFrom(
                                      padding:
                                          EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _removeScreenshot,
                                    icon: Icon(Icons.delete_outline,
                                        color: Colors.red),
                                    label: Text('Remove',
                                        style: TextStyle(color: Colors.red)),
                                    style: OutlinedButton.styleFrom(
                                      padding:
                                          EdgeInsets.symmetric(vertical: 12),
                                      side: BorderSide(
                                          color: Colors.red.withOpacity(0.5)),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                    ],
                  ),
                ),

                SizedBox(height: 32),

                // Submit button
                Container(
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: isSubmitting ? null : _submitForm,
                    icon: isSubmitting
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Icon(isBugReport ? Icons.bug_report : Icons.send),
                    label: Text(
                      isSubmitting
                          ? 'Submitting...'
                          : 'Submit ${isBugReport ? "Bug Report" : "Feedback"}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isBugReport ? Colors.red : Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 2,
                    ),
                  ),
                ),

                SizedBox(height: 16),

                // Footer note
                Text(
                  'Your report will be reviewed by our team. We\'ll get back to you if we need more information.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
