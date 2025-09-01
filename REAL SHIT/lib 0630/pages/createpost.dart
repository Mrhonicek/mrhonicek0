import 'dart:io';
import 'package:flutter/material.dart';
import 'package:gismultiinstancetestingenvironment/pages/newsfeed/newsfeed.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:geolocator/geolocator.dart';

final supabase = Supabase.instance.client;

class CreatePostScreen extends StatefulWidget {
  @override
  _CreatePostScreenState createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final TextEditingController _headerController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  File? _image;
  final ImagePicker _picker = ImagePicker();
  bool _captureLocation = false;
  String? _coordinates;
  bool _isUploading = false;

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.blue),
                title: const Text('Take a Photo',
                    style: TextStyle(fontWeight: FontWeight.w500)),
                onTap: () async {
                  Navigator.pop(context);
                  final pickedFile =
                      await _picker.pickImage(source: ImageSource.camera);
                  if (pickedFile != null) {
                    setState(() {
                      _image = File(pickedFile.path);
                    });
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.image, color: Colors.green),
                title: const Text('Choose from Gallery',
                    style: TextStyle(fontWeight: FontWeight.w500)),
                onTap: () async {
                  Navigator.pop(context);
                  final pickedFile =
                      await _picker.pickImage(source: ImageSource.gallery);
                  if (pickedFile != null) {
                    setState(() {
                      _image = File(pickedFile.path);
                    });
                  }
                },
              ),
              if (_image != null)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Remove Image',
                      style: TextStyle(fontWeight: FontWeight.w500)),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _image = null;
                    });
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _getLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showSnackBar('Location services are disabled.');
      return;
    }

    // Check for permission
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showSnackBar('Location permission denied.');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showSnackBar('Location permissions are permanently denied.');
      return;
    }

    // Get the current position
    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      _coordinates = "${position.latitude}, ${position.longitude}";
    });
    _showSnackBar('Location captured successfully');
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _uploadPost() async {
    // Add image validation along with existing text validation
    if (_headerController.text.isEmpty || _bodyController.text.isEmpty) {
      _showSnackBar('Please fill in all fields');
      return;
    }

    // NEW: Add mandatory image check
    if (_image == null) {
      _showAlertDialog(
          'Image Required', 'Please add an image before submitting your post');
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        _showSnackBar('User not authenticated');
        setState(() {
          _isUploading = false;
        });
        return;
      }

      String? imageUrl;

      // Since image is now mandatory, we can remove the null check
      // OLD: if (_image != null) {
      final fileName = const Uuid().v4();
      final storagePath = 'posts/$fileName.jpg';

      // Upload the image
      final uploadResponse = await supabase.storage
          .from('post-images')
          .upload(storagePath, _image!);

      if (uploadResponse == null || uploadResponse.isEmpty) {
        _showSnackBar('Image upload failed');
        setState(() {
          _isUploading = false;
        });
        return;
      }

      // Get the public URL of the uploaded image
      imageUrl = supabase.storage.from('post-images').getPublicUrl(storagePath);
      // Remove the closing brace here since image is mandatory

      // Insert the post into the database
      final response = await supabase.from('posts').insert({
        'user_id': userId,
        'post_header': _headerController.text,
        'post_body': _bodyController.text,
        'post_image_url': imageUrl,
        'area_coordinates': _coordinates,
      });

      setState(() {
        _isUploading = false;
      });

      if (response == null ||
          (response is Map && response.containsKey('error'))) {
        _showSnackBar('Post uploaded successfully');

        _headerController.clear();
        _bodyController.clear();
        setState(() {
          _image = null;
          _captureLocation = false;
          _coordinates = null;
        });

        // Navigate back to NewsFeed after success
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => NewsFeed()),
        );
      } else {
        _showSnackBar('An error occurred. Please try again.');
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      _showSnackBar('Failed to upload post: $e');
    }
  }

  void _showAlertDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Main Content
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.blue.shade50, Colors.white],
              ),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 100.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(
                        child: Text(
                          'Create Post',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Post Header
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              spreadRadius: 1,
                              blurRadius: 3,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: TextField(
                            controller: _headerController,
                            decoration: const InputDecoration(
                              labelText: 'Title',
                              border: InputBorder.none,
                              labelStyle: TextStyle(color: Colors.blue),
                            ),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Post Body
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              spreadRadius: 1,
                              blurRadius: 3,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: TextField(
                            controller: _bodyController,
                            decoration: const InputDecoration(
                              labelText: 'Description',
                              border: InputBorder.none,
                              labelStyle: TextStyle(color: Colors.blue),
                              alignLabelWithHint: true,
                            ),
                            maxLines: 5,
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Image Preview
                      if (_image != null)
                        Stack(
                          children: [
                            Container(
                              height: 200,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.2),
                                    spreadRadius: 1,
                                    blurRadius: 5,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(
                                  _image!,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                ),
                              ),
                            ),
                            Positioned(
                              right: 8,
                              top: 8,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.6),
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.close,
                                      color: Colors.white),
                                  onPressed: () {
                                    setState(() {
                                      _image = null;
                                    });
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      Text(
                        '*A photo is required to create a post',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Media and Location Options
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: _pickImage,
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12.0),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border:
                                      Border.all(color: Colors.blue.shade100),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.photo_library,
                                      color: Colors.blue.shade400,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _image == null
                                          ? 'Add Photo'
                                          : 'Change Photo',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        color: Colors.blue.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          /*Expanded(
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _captureLocation = !_captureLocation;
                                  if (_captureLocation) {
                                    _getLocation();
                                  } else {
                                    _coordinates = null;
                                  }
                                });
                              },
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12.0),
                                decoration: BoxDecoration(
                                  color: _captureLocation
                                      ? Colors.blue.shade50
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _captureLocation
                                        ? Colors.blue
                                        : Colors.blue.shade100,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.location_on,
                                      color: _captureLocation
                                          ? Colors.blue
                                          : Colors.blue.shade400,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Location',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        color: _captureLocation
                                            ? Colors.blue
                                            : Colors.blue.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),*/
                        ],
                      ),
                      // Location data display
                      if (_coordinates != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 16.0),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.shade100),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.location_on,
                                    color: Colors.blue, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    "Location captured: $_coordinates",
                                    style: TextStyle(
                                        color: Colors.blue.shade800,
                                        fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Floating back button
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.8),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black87),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
          // Post button
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    spreadRadius: 1,
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _isUploading ? null : _uploadPost,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF22CB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isUploading
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Uploading...',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      )
                    : const Text(
                        'Share Post',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
