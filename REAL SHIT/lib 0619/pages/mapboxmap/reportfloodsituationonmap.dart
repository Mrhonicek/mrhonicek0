import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';

// Function to show the report modal window
void showReportFloodModal(
    BuildContext context, LatLng coordinates, String address) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: ReportFloodForm(coordinates: coordinates, address: address),
      );
    },
  );
}

// Form Widget for Flood Report Submission
class ReportFloodForm extends StatefulWidget {
  final LatLng coordinates;
  final String address;

  const ReportFloodForm(
      {Key? key, required this.coordinates, required this.address})
      : super(key: key);

  @override
  _ReportFloodFormState createState() => _ReportFloodFormState();
}

class _ReportFloodFormState extends State<ReportFloodForm> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final _cooldownKey =
      'flood_report_cooldown_${Supabase.instance.client.auth.currentUser?.id}';

  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  bool _isConnected = true;

  String? _floodStatus; // Default flood status
  bool _isSubmitting = false;

  File? _imageFile; // To store the selected image
  DateTime? _lastSubmissionTime; // Track last submission time
  bool _canSubmit = true; // Track if user can submit
  int _remainingCooldownSeconds = 0; // Remaining cooldown time

  @override
  void initState() {
    super.initState();
    _checkLastSubmission();
    _initConnectivity();
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen(_updateConnectionStatus);
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  Future<void> _initConnectivity() async {
    try {
      final List<ConnectivityResult> results =
          await Connectivity().checkConnectivity();
      _updateConnectionStatus(results);
    } catch (e) {
      print('❌ Error checking initial connectivity: $e');
      setState(() {
        _isConnected = false;
      });
    }
  }

  // Update connection status from stream
  void _updateConnectionStatus(List<ConnectivityResult> results) {
    final bool isConnected = results.any((result) =>
        result == ConnectivityResult.mobile ||
        result == ConnectivityResult.wifi ||
        result == ConnectivityResult.ethernet);

    if (mounted) {
      setState(() {
        _isConnected = isConnected;
      });
    }
  }

  // Check the user's last submission time and enforce cooldown
  Future<void> _checkLastSubmission() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSubmissionString = prefs.getString(_cooldownKey);
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) return;

    if (lastSubmissionString != null) {
      _lastSubmissionTime = DateTime.parse(lastSubmissionString);
      final now = DateTime.now().toUtc().add(const Duration(hours: 8));
      final timeDifference = now.difference(_lastSubmissionTime!);
      const cooldownDuration = Duration(minutes: 1);

      if (timeDifference < cooldownDuration) {
        setState(() {
          _canSubmit = false;
          _remainingCooldownSeconds =
              (cooldownDuration - timeDifference).inSeconds;
        });
        _startCooldownTimer();
      }
    }
  }

  // Start countdown timer for cooldown period
  void _startCooldownTimer() {
    if (_remainingCooldownSeconds <= 0) return;

    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _remainingCooldownSeconds--;
          if (_remainingCooldownSeconds <= 0) {
            _canSubmit = true;
          } else {
            _startCooldownTimer(); // Continue countdown
          }
        });
      }
    });
  }

  // Format remaining time for display
  String _formatCooldownTime() {
    final minutes = _remainingCooldownSeconds ~/ 60;
    final seconds = _remainingCooldownSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _pickImage({required ImageSource source}) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source);

    if (image != null) {
      setState(() {
        _imageFile = File(image.path);
      });
    }
  }

  Future<String?> _uploadImage() async {
    if (_imageFile == null) return null;

    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) return null;

    try {
      final fileExt = path.extension(_imageFile!.path);
      final fileName = '${DateTime.now().millisecondsSinceEpoch}$fileExt';
      final filePath = '${user.id}/flood_reports/$fileName';

      await supabase.storage.from('flood-images').upload(
            filePath,
            _imageFile!,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );

      // Get the public URL for the uploaded image
      final imageUrl =
          supabase.storage.from('flood-images').getPublicUrl(filePath);
      return imageUrl;
    } catch (e) {
      print('❌ Error uploading image: $e');
      rethrow; // Let the calling method handle the error
    }
  }

  Future<void> _submitReport() async {
    // Basic connectivity check only
    if (!_isConnected) {
      _showAlertDialog('No Internet Connection',
          'Please check your internet connection and try again.');
      return;
    }

    // Check cooldown before submission
    if (!_canSubmit) {
      _showAlertDialog('Submission Cooldown',
          'Please wait for ${_formatCooldownTime()} before submitting another report.');
      return;
    }

    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    final manilaTime = DateTime.now().toUtc().add(const Duration(hours: 8));

    if (user == null) {
      _showAlertDialog('Authentication Required',
          'You must be logged in to submit a report.');
      return;
    }

    // Validate required fields
    // Validate required fields including mandatory image
    if (_titleController.text.trim().isEmpty ||
        _descriptionController.text.trim().isEmpty ||
        _floodStatus == null ||
        _imageFile == null) {
      String missingFields = '';
      if (_titleController.text.trim().isEmpty) missingFields += '• Title\n';
      if (_descriptionController.text.trim().isEmpty)
        missingFields += '• Description\n';
      if (_floodStatus == null) missingFields += '• Flood Status\n';
      if (_imageFile == null) missingFields += '• Image (required)\n';

      _showAlertDialog('Missing Information',
          'Please fill in all required fields:\n\n$missingFields');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    String? imageUrl;

    try {
      // Only upload image if the checkbox is checked and an image is selected
      imageUrl = await _uploadImage();

      await supabase.from('reportfloodsituations').insert({
        'flood_reportedby': user.id,
        'floodreport_title': _titleController.text.trim(),
        'floodreport_description': _descriptionController.text.trim(),
        'location_address': widget.address,
        'address_coordinates':
            'SRID=4326;POINT(${widget.coordinates.longitude} ${widget.coordinates.latitude})',
        'flood_status': _floodStatus,
        'upvote_count': 0,
        'downvote_count': 0,
        'flood_reportstatus': 'pending', // Setting default status to pending
        'reported_flood_image': imageUrl, // Add the image URL if available
        'created_on':
            manilaTime.toIso8601String(), // <- Explicitly pass Manila time
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cooldownKey, manilaTime.toIso8601String());

      debugPrint('✅ Flood time frame: ${manilaTime.toIso8601String()}');

      // Update last submission time and start cooldown
      setState(() {
        _lastSubmissionTime = manilaTime;
        _canSubmit = false;
        _remainingCooldownSeconds = 60; // 3 minutes in seconds
      });
      _startCooldownTimer();

      // Show success dialog with moderation message
      _showAlertDialog('Report Submitted',
          'Thank you for your report. It will be reviewed by our moderators before being published to ensure legitimacy.\n\nNote: You can submit another report in 1 minute.',
          popOnConfirm: true);
    } catch (e) {
      print("❌ Error submitting report: $e");

      // Handle specific error types
      String errorMessage = 'Failed to submit report. Please try again.';
      if (e.toString().contains('network') ||
          e.toString().contains('connection') ||
          e.toString().contains('timeout')) {
        errorMessage =
            'Network error occurred. Please check your internet connection and try again.';
      }

      _showAlertDialog('Error', errorMessage);
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  void _showAlertDialog(String title, String message,
      {bool popOnConfirm = false}) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close the dialog
                if (popOnConfirm) {
                  Navigator.pop(context); // Close the modal if success
                }
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
    return LayoutBuilder(
      builder: (context, constraints) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: constraints.maxWidth * 0.9, // Adaptive modal width
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Report Flood Situation',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 15),

                  // Cooldown notice (only show if user is in cooldown)
                  if (!_canSubmit) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.timer, color: Colors.orange.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'You can submit another report in ${_formatCooldownTime()}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.orange.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 15),
                  ],

                  // Connection warning (only show if no network connection)
                  if (!_isConnected) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.wifi_off, color: Colors.red.shade700),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'No internet connection. Please check your connection to submit reports.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.red,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 15),
                  ],

                  TextField(
                    controller: _titleController,
                    enabled: _canSubmit,
                    decoration: const InputDecoration(
                        labelText: 'Report Title',
                        hintText: 'Enter a brief title for your report'),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: _descriptionController,
                    maxLines: 3,
                    enabled: _canSubmit,
                    decoration: const InputDecoration(
                        labelText: 'Description',
                        hintText: 'Describe the flood situation in detail'),
                  ),
                  const SizedBox(height: 15),
                  DropdownButtonFormField<String>(
                    value: _floodStatus,
                    items: [
                      {
                        'status': 'Not Flooded',
                        'description': 'No significant flood accumulation.'
                      },
                      {
                        'status': 'Passable',
                        'description': 'Flood present but still crossable.'
                      },
                      {
                        'status': 'Rising Water',
                        'description':
                            'Flood level increasing, might become impassable.'
                      },
                      {
                        'status': 'Impassable',
                        'description': 'Flood is too deep to cross.'
                      },
                      {
                        'status': 'Flood Surge',
                        'description':
                            'Sudden, strong water movement, high risk.'
                      }
                    ].map((data) {
                      return DropdownMenuItem(
                        value: data['status'],
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data['status']!,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              data['description']!,
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: _canSubmit
                        ? (value) {
                            setState(() {
                              _floodStatus = value!;
                            });
                          }
                        : null,
                    selectedItemBuilder: (BuildContext context) {
                      return [
                        'Not Flooded',
                        'Passable',
                        'Rising Water',
                        'Impassable',
                        'Flood Surge'
                      ].map<Widget>((status) {
                        return Text(status,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold));
                      }).toList();
                    },
                    decoration:
                        const InputDecoration(labelText: 'Flood Status'),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    'Address: ${widget.address}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),

                  // Image upload section
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.camera_alt, color: Colors.blue.shade700),
                            const SizedBox(width: 8),
                            const Text(
                              'Image Required *',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'An image of the flood situation is required to submit this report.',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Only show image upload if checkbox is checked

                  Row(
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Take Photo'),
                        onPressed: _canSubmit
                            ? () => _pickImage(source: ImageSource.camera)
                            : null,
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Select Image'),
                        onPressed: _canSubmit
                            ? () => _pickImage(source: ImageSource.gallery)
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_imageFile != null) ...[
                    Text(
                      'Image selected: ${path.basename(_imageFile!.path)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        _imageFile!,
                        height: 100,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 10),

                  // Moderation notice
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.amber),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Your report will be reviewed by moderators before being published.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed:
                            (_isSubmitting || !_canSubmit || !_isConnected)
                                ? null
                                : _submitReport,
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(!_canSubmit
                                ? _formatCooldownTime()
                                : !_isConnected
                                    ? 'No Connection'
                                    : 'Submit'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
