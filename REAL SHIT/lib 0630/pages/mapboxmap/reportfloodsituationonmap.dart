import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'dart:convert';

// GeoJSON polygon data - replace with your actual polygon coordinates
const String GEOJSON_POLYGON = '''
{
  "type": "Polygon",
  "coordinates": [[[125.592921,7.114225],[125.591204,7.113242],[125.589874,7.111773],[125.588079,7.111252],[125.588231,7.109116],[125.591616,7.107293],[125.592606,7.105708],[125.59404,7.105441],[125.595216,7.105378],[125.596242,7.105747],[125.595984,7.109211],[125.597286,7.111904],[125.597106,7.113642],[125.596897,7.114031],[125.595976,7.114742],[125.594616,7.114887],[125.592921,7.114225]]]
}
''';

// Utility class for geofencing operations
class GeofenceUtil {
  static bool isPointInPolygon(LatLng point, List<List<double>> polygon) {
    double x = point.longitude;
    double y = point.latitude;

    bool inside = false;
    int j = polygon.length - 1;

    for (int i = 0; i < polygon.length; i++) {
      double xi = polygon[i][0];
      double yi = polygon[i][1];
      double xj = polygon[j][0];
      double yj = polygon[j][1];

      if (((yi > y) != (yj > y)) &&
          (x < (xj - xi) * (y - yi) / (yj - yi) + xi)) {
        inside = !inside;
      }
      j = i;
    }

    return inside;
  }

  static List<List<double>> parsePolygonFromGeoJSON(String geoJsonString) {
    try {
      final Map<String, dynamic> geoJson = json.decode(geoJsonString);
      final List<dynamic> coordinates = geoJson['coordinates'][0];

      return coordinates
          .map<List<double>>((coord) =>
              [(coord[0] as num).toDouble(), (coord[1] as num).toDouble()])
          .toList();
    } catch (e) {
      print('❌ Error parsing GeoJSON: $e');
      return [];
    }
  }

  static bool isLocationInAllowedArea(LatLng location) {
    final polygon = parsePolygonFromGeoJSON(GEOJSON_POLYGON);
    if (polygon.isEmpty) return false;

    return isPointInPolygon(location, polygon);
  }
}

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

  String? _floodStatus;
  bool _isSubmitting = false;
  bool _isGettingLocation = false;

  File? _imageFile;
  DateTime? _lastSubmissionTime;
  bool _canSubmit = true;
  int _remainingCooldownSeconds = 0;

  // Location variables
  LatLng? _deviceLocation;
  bool _locationInAllowedArea = false;
  bool _reportLocationInAllowedArea = false;

  @override
  void initState() {
    super.initState();
    _checkLastSubmission();
    _initConnectivity();
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen(_updateConnectionStatus);
    _checkReportLocationInArea();
    _titleController.text = 'Flood Report - Jade Valley';
    _getCurrentLocation();
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

  void _checkReportLocationInArea() {
    setState(() {
      _reportLocationInAllowedArea =
          GeofenceUtil.isLocationInAllowedArea(widget.coordinates);
    });

    print('📍 Report location in allowed area: $_reportLocationInAllowedArea');
    print(
        '📍 Report coordinates: ${widget.coordinates.latitude}, ${widget.coordinates.longitude}');
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isGettingLocation = true;
    });

    try {
      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('❌ Location permissions are denied');
          setState(() {
            _isGettingLocation = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('❌ Location permissions are permanently denied');
        setState(() {
          _isGettingLocation = false;
        });
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      final deviceLocation = LatLng(position.latitude, position.longitude);
      final locationInArea =
          GeofenceUtil.isLocationInAllowedArea(deviceLocation);

      setState(() {
        _deviceLocation = deviceLocation;
        _locationInAllowedArea = locationInArea;
        _isGettingLocation = false;
      });

      print('📱 Device location: ${position.latitude}, ${position.longitude}');
      print('📱 Device location in allowed area: $locationInArea');
    } catch (e) {
      print('❌ Error getting location: $e');
      setState(() {
        _isGettingLocation = false;
      });
    }
  }

  bool _shouldAutoApprove() {
    // Auto-approve if either the report location or device location is in the allowed area
    return _reportLocationInAllowedArea && _locationInAllowedArea;
  }

  String _getApprovalStatus() {
    if (_shouldAutoApprove()) {
      return 'granted'; // Will be auto-approved
    } else {
      return 'pending'; // Will remain pending for manual review
    }
  }

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

  void _startCooldownTimer() {
    if (_remainingCooldownSeconds <= 0) return;

    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _remainingCooldownSeconds--;
          if (_remainingCooldownSeconds <= 0) {
            _canSubmit = true;
          } else {
            _startCooldownTimer();
          }
        });
      }
    });
  }

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

      final imageUrl =
          supabase.storage.from('flood-images').getPublicUrl(filePath);
      return imageUrl;
    } catch (e) {
      print('❌ Error uploading image: $e');
      rethrow;
    }
  }

  Future<void> _submitReport() async {
    if (!_isConnected) {
      _showAlertDialog('No Internet Connection',
          'Please check your internet connection and try again.');
      return;
    }

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
      imageUrl = await _uploadImage();

      // Determine the report status based on geofencing
      final reportStatus = _getApprovalStatus();

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
        'flood_reportstatus':
            reportStatus, // Auto-approved or pending based on location
        'reported_flood_image': imageUrl,
        'created_on': manilaTime.toIso8601String(),
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cooldownKey, manilaTime.toIso8601String());

      debugPrint('✅ Report submitted with status: $reportStatus');
      debugPrint('✅ Report location in area: $_reportLocationInAllowedArea');
      debugPrint('✅ Device location in area: $_locationInAllowedArea');

      setState(() {
        _lastSubmissionTime = manilaTime;
        _canSubmit = false;
        _remainingCooldownSeconds = 60;
      });
      _startCooldownTimer();

      // Show appropriate success message based on approval status
      String successMessage = _shouldAutoApprove()
          ? 'Your report has been automatically approved and published because it\'s within the monitored area.\n\nNote: You can submit another report in 1 minute.'
          : 'Thank you for your report. It will be reviewed by our moderators before being published as it\'s outside the primary monitored area.\n\nNote: You can submit another report in 1 minute.';

      _showAlertDialog('Report Submitted', successMessage, popOnConfirm: true);
    } catch (e) {
      print("❌ Error submitting report: $e");

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
                Navigator.pop(context);
                if (popOnConfirm) {
                  Navigator.pop(context);
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
                maxWidth: constraints.maxWidth * 0.9,
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

                  // Location status indicator
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _shouldAutoApprove()
                          ? Colors.green.shade50
                          : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: _shouldAutoApprove()
                              ? Colors.green.shade200
                              : Colors.orange.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _shouldAutoApprove()
                                  ? Icons.check_circle
                                  : Icons.pending,
                              color: _shouldAutoApprove()
                                  ? Colors.green.shade700
                                  : Colors.orange.shade700,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _shouldAutoApprove()
                                  ? 'Auto-Approval Area'
                                  : 'Manual Review Required',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: _shouldAutoApprove()
                                    ? Colors.green.shade700
                                    : Colors.orange.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _shouldAutoApprove()
                              ? 'This report will be automatically approved as you\'re within the monitored area.'
                              : 'This report will require manual review as it\'s outside the primary monitored area.',
                          style: TextStyle(
                            fontSize: 14,
                            color: _shouldAutoApprove()
                                ? Colors.green.shade700
                                : Colors.orange.shade700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Report location: ${_reportLocationInAllowedArea ? "✓ In area" : "✗ Outside area"}',
                          style:
                              const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        if (_isGettingLocation)
                          const Text(
                            'Device location: Getting location...',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          )
                        else if (_deviceLocation != null)
                          Text(
                            'Device location: ${_locationInAllowedArea ? "✓ In area" : "✗ Outside area"}',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey),
                          )
                        else
                          const Text(
                            'Device location: Unable to determine',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),

                  // Cooldown notice
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

                  // Connection warning
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

                  Column(
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

                  // Approval notice
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _shouldAutoApprove()
                          ? Colors.green.shade50
                          : Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: _shouldAutoApprove()
                              ? Colors.green.shade200
                              : Colors.amber.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _shouldAutoApprove()
                              ? Icons.check_circle_outline
                              : Icons.info_outline,
                          color: _shouldAutoApprove()
                              ? Colors.green
                              : Colors.amber,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _shouldAutoApprove()
                                ? 'Your report will be automatically approved and published immediately.'
                                : 'Your report will be reviewed by moderators before being published.',
                            style: const TextStyle(fontSize: 12),
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
