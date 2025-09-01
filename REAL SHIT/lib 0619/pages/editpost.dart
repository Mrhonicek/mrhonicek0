import 'dart:io';
import 'package:flutter/material.dart';
import 'package:gismultiinstancetestingenvironment/pages/newsfeed/newsfeed.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';

final supabase = Supabase.instance.client;

class EditPostScreen extends StatefulWidget {
  final String postId;

  EditPostScreen({required this.postId});

  @override
  _EditPostScreenState createState() => _EditPostScreenState();
}

class _EditPostScreenState extends State<EditPostScreen> {
  final TextEditingController _headerController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  File? _image;
  final ImagePicker _picker = ImagePicker();
  bool _captureLocation = false;
  String? _coordinates;
  String? _existingImageUrl;
  bool _isLoading = true;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _fetchPostDetails();
  }

  Future<void> _fetchPostDetails() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await supabase
          .from('posts')
          .select()
          .eq('postid', widget.postId)
          .single();

      if (response != null) {
        setState(() {
          _headerController.text = response['post_header'];
          _bodyController.text = response['post_body'];
          _existingImageUrl = response['post_image_url'];
          _coordinates = response['area_coordinates'];
        });
      }
    } catch (e) {
      print('Error fetching post details: $e');
      _showSnackBar('Failed to fetch post details');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

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
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Remove Image',
                    style: TextStyle(fontWeight: FontWeight.w500)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _image = null;
                    _existingImageUrl = null;
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
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showSnackBar('Location services are disabled');
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showSnackBar('Location permission denied');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showSnackBar('Location permissions permanently denied');
      return;
    }

    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      _coordinates = "${position.latitude}, ${position.longitude}";
    });
    _showSnackBar('Location updated successfully');
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _updatePost() async {
    if (_headerController.text.isEmpty || _bodyController.text.isEmpty) {
      _showSnackBar('Please fill in all fields');
      return;
    }

    setState(() {
      _isUpdating = true;
    });

    try {
      String? imageUrl = _existingImageUrl;

      if (_image != null) {
        final fileName = const Uuid().v4();
        final storagePath = 'posts/$fileName.jpg';

        await supabase.storage.from('post-images').upload(storagePath, _image!);
        imageUrl =
            supabase.storage.from('post-images').getPublicUrl(storagePath);
      }

      await supabase.from('posts').update({
        'post_header': _headerController.text,
        'post_body': _bodyController.text,
        'post_image_url': imageUrl,
        'area_coordinates': _coordinates,
      }).eq('postid', widget.postId);

      setState(() {
        _isUpdating = false;
      });

      _showSnackBar('Post updated successfully');

      Future.delayed(Duration(seconds: 1), () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => NewsFeed()),
        );
      });
    } catch (e) {
      setState(() {
        _isUpdating = false;
      });
      _showSnackBar('Failed to update post: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(),
            )
          : Stack(
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
                        padding:
                            const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 100.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Center(
                              child: Text(
                                'Edit Post',
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
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16.0),
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
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16.0),
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
                            if (_image != null || _existingImageUrl != null)
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
                                      child: _image != null
                                          ? Image.file(
                                              _image!,
                                              fit: BoxFit.cover,
                                              width: double.infinity,
                                            )
                                          : _existingImageUrl != null
                                              ? Image.network(
                                                  _existingImageUrl!,
                                                  fit: BoxFit.cover,
                                                  width: double.infinity,
                                                  loadingBuilder: (context,
                                                      child, loadingProgress) {
                                                    if (loadingProgress == null)
                                                      return child;
                                                    return Center(
                                                      child:
                                                          CircularProgressIndicator(
                                                        value: loadingProgress
                                                                    .expectedTotalBytes !=
                                                                null
                                                            ? loadingProgress
                                                                    .cumulativeBytesLoaded /
                                                                loadingProgress
                                                                    .expectedTotalBytes!
                                                            : null,
                                                      ),
                                                    );
                                                  },
                                                )
                                              : Container(),
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
                                            _existingImageUrl = null;
                                          });
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            const SizedBox(height: 24),
                            // Media and Location Options
                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: _pickImage,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12.0),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                            color: Colors.blue.shade100),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.photo_library,
                                            color: Colors.blue.shade400,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            (_image != null ||
                                                    _existingImageUrl != null)
                                                ? 'Change Photo'
                                                : 'Add Photo',
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
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12.0),
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
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
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
                                    border:
                                        Border.all(color: Colors.blue.shade100),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.location_on,
                                          color: Colors.blue, size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          "Location: $_coordinates",
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
                // Update button
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
                      onPressed: _isUpdating ? null : _updatePost,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: _isUpdating
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
                                  'Updating...',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            )
                          : const Text(
                              'Update Post',
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
