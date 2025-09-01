import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart' as geoloc;
import 'package:gismultiinstancetestingenvironment/pages/mapboxmap/mapboxfuturefunctions.dart';
import 'package:http/http.dart' as http;
import 'package:gismultiinstancetestingenvironment/pages/mapboxmap/reportfloodsituationonmap.dart';
import 'package:latlong2/latlong.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:gismultiinstancetestingenvironment/pages/mapboxmap/mapboxfuturefunctions.dart'
    as mapbox_functions;
//import 'package:gismultiinstancetestingenvironment/pages/mapboxmap/mapboxfuturefunctions.dart';
import 'package:gismultiinstancetestingenvironment/pages/mapboxmap/mapboxgeocoding.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:expressions/expressions.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:io';
//import 'package:mapbox_gl/mapbox_gl.dart' as mapboxgl;

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  MapboxMap? mapboxMapController;
  CameraState? lastCameraState; // Store the last known camera state
  PointAnnotationManager? pointAnnotationManager;

  StreamSubscription? userPositionStream;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isConnected = true;
  bool _showingOfflineMessage = false;

  String _selectedInterval = '';
  List<String> _availableIntervals = [];
  bool _debugEnabled = false;
  DateTime? startOfDay;
  Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'not flooded':
        return Colors.green;
      case 'passable':
        return Colors.lightGreen;
      case 'rising water':
        return Colors.yellow;
      case 'impassable':
        return Colors.orange;
      case 'flood surge':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  String getStatusEmoji(String status) {
    switch (status.toLowerCase()) {
      case 'not flooded':
      case 'notflooded':
        return '●'; // Solid circle - will be colored green
      case 'passable':
        return '▲'; // Triangle - caution
      case 'rising water':
        return '◆'; // Diamond - rising water
      case 'impassable':
        return '■'; // Square - blocked/impassable
      case 'flood surge':
        return '✖'; // X mark - danger/emergency
      default:
        return '?'; // Question mark - unknown status
    }
  }

  String _getCurrentInterval() {
    final now = DateTime.now();
    final hour = now.hour;
    final intervalStart = hour - (hour % 3);
    final intervalEnd = intervalStart + 3;
    return '${intervalStart.toString().padLeft(2, '0')}:00-'
        '${intervalEnd.toString().padLeft(2, '0')}:00';
  }

  Future<bool> _checkInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }

// Generate available time intervals for the selected date
  List<String> _getAvailableIntervals(DateTime date) {
    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;

    final intervals = <String>[];
    final maxHour = isToday ? now.hour : 24;

    // Start from midnight and add 3-hour intervals up to current hour
    for (int hour = 0; hour <= maxHour; hour += 3) {
      final endHour = min(hour + 3, 24);
      intervals.add(
          '${hour.toString().padLeft(2, '0')}:00-${endHour.toString().padLeft(2, '0')}:00');
    }

    return intervals;
  }

// Get the start and end time for a given interval string
  Map<String, DateTime> parseInterval(String interval, DateTime selectedDate) {
    final parts = interval.split('-');
    final startTime = parts[0].trim();
    final endTime = parts[1].trim();

    final startHour = int.parse(startTime.split(':')[0]);
    final endHour = int.parse(endTime.split(':')[0]);

    return {
      'start': DateTime(
          selectedDate.year, selectedDate.month, selectedDate.day, startHour),
      'end': DateTime(
          selectedDate.year, selectedDate.month, selectedDate.day, endHour),
    };
  }

  DateTime selectedDate = DateTime.now();
  final List<Map<String, dynamic>> _allReports = [];
  StreamSubscription<SupabaseStreamEvent>? _realtimeSubscription;

  Map<String, Map<String, dynamic>> markerToReportMap = {};
  Point createPoint(LatLng latLng) {
    return Point(
        coordinates:
            Position(latLng.longitude, latLng.latitude)); // Always use Position
  }

  Point createPointForCamera(LatLng latLng) {
    return Point(coordinates: Position(latLng.longitude, latLng.latitude));
  }

// ✅ Function to get report count from Supabase
  Future<Object> _getReportCount(String? locationAddress) async {
    if (locationAddress == null) return 0;

    final supabase = Supabase.instance.client;

    // Get today's date in YYYY-MM-DD format
    final today = DateTime.now();
    final todayString =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    final response = await supabase
        .from('reportfloodsituations')
        .select('location_address')
        .eq('location_address', locationAddress)
        .gte('created_on', '${todayString} 00:00:00')
        .lt('created_on', '${todayString} 23:59:59')
        .count();

    return response.count ?? 0;
  }

  void _initConnectivityListener() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      (List<ConnectivityResult> results) async {
        final bool hasConnection = await _checkInternetConnection();

        if (hasConnection != _isConnected) {
          setState(() {
            _isConnected = hasConnection;
          });

          if (!hasConnection && !_showingOfflineMessage) {
            _showingOfflineMessage = true;
            _showOfflineDialog();
          } else if (hasConnection && _showingOfflineMessage) {
            _showingOfflineMessage = false;
            Navigator.of(context, rootNavigator: true)
                .pop(); // Close offline dialog
            _showConnectionRestoredSnackBar();
          }
        }
      },
    );
  }

  void _showOfflineDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.wifi_off, color: Colors.red),
              SizedBox(width: 8),
              Text('No Internet Connection'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Please check your internet connection and try again.'),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  final hasConnection = await _checkInternetConnection();
                  if (hasConnection) {
                    setState(() {
                      _isConnected = true;
                      _showingOfflineMessage = false;
                    });
                    Navigator.of(context).pop();
                    _showConnectionRestoredSnackBar();
                  }
                },
                child: Text('Retry'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showConnectionRestoredSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.wifi, color: Colors.white),
            SizedBox(width: 8),
            Text('Connection restored'),
          ],
        ),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _onMapClickReport(MapContentGestureContext gestureContext) async {
    LatLng latLng = LatLng(
      gestureContext.point.coordinates.lat.toDouble(),
      gestureContext.point.coordinates.lng.toDouble(),
    );
    MapboxGeocoding geocoding = MapboxGeocoding();
    String? streetaddressname =
        await geocoding.getAddressFromCoordinates(latLng);
    Object reportCount =
        await _getReportCount(streetaddressname); // ✅ Fetch count
    debugPrint(
        'Map clicked for report at: ${latLng.latitude}, ${latLng.longitude}');

    // You can customize the report dialog or action here.
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Report this location?',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              /* Text('Latitude: ${latLng.latitude}'),
              Text('Longitude: ${latLng.longitude}'),*/
              Text('Number of reports issued today: $reportCount'),
              Text('Address: $streetaddressname'),
              const SizedBox(height: 20),
              // ✅ Centered buttons placed next to each other
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 10), // Space between buttons
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red, // ✅ Submit button in red
                    ),
                    onPressed: () {
                      _submitReport(latLng);
                      Navigator.pop(context); // Close the bottom sheet
                    },
                    child: const Text('Submit Report'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _refreshMap() async {
    if (!_isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.wifi_off, color: Colors.white),
              SizedBox(width: 8),
              Text('No internet connection. Cannot refresh map.'),
            ],
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    try {
      debugPrint("Refreshing map data...");

      // Clear existing markers
      await pointAnnotationManager?.deleteAll();

      // Reload markers from Supabase
      await loadSupabaseMarkers();

      onMapStyleLoaded(mapboxMapController);
      // Optionally reload the map style
      await mapboxMapController?.loadStyleURI(MapboxStyles.OUTDOORS);
      // Optionally re-center the map
      // Wait for style to be fully loaded before adding layers
      await Future.delayed(const Duration(milliseconds: 700));
      addBorderLayer(mapboxMapController);
      await loadGeoJsonPointMarkers();
      await focusOnUserLocation(mapboxMapController);

      debugPrint("✅ Map refreshed successfully");

      // Show a snackbar to confirm refresh
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Map refreshed'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      debugPrint("❌ Error refreshing map: $e");
      if (mounted) {
        String errorMessage = 'Refresh failed';
        if (e.toString().contains('SocketException') ||
            e.toString().contains('TimeoutException')) {
          errorMessage = 'Network error. Check your internet connection.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _submitReport(LatLng latLng) async {
    if (!_isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.wifi_off, color: Colors.white),
              SizedBox(width: 8),
              Text('No internet connection. Cannot submit report.'),
            ],
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    MapboxGeocoding geocoding = MapboxGeocoding();
    String? address = await geocoding.getAddressFromCoordinates(latLng);

    // Show reporting modal
    showReportFloodModal(context, latLng, address ?? "Unknown Location");

    // Refresh markers after submission
    if (mounted) {
      await loadSupabaseMarkers();
    }
  }

  // Example of using the function for camera options.
  void setCameraToLatLng(LatLng latlng) {
    mapboxMapController?.setCamera(
      CameraOptions(
        center: createPointForCamera(latlng),
        zoom: 18,
      ),
    );
  }

  bool _hasCameraMoved(CameraState newCamera) {
    if (lastCameraState == null) return true; // First-time move

    return newCamera.center != lastCameraState!.center ||
        newCamera.zoom != lastCameraState!.zoom ||
        newCamera.bearing != lastCameraState!.bearing ||
        newCamera.pitch != lastCameraState!.pitch;
  }

  void startCameraTracking() {
    Timer.periodic(Duration(milliseconds: 500), (timer) async {
      if (mapboxMapController == null) return;

      try {
        CameraState? currentCamera =
            await mapboxMapController?.getCameraState();
        if (currentCamera != null &&
            (lastCameraState == null || _hasCameraMoved(currentCamera))) {
          lastCameraState = currentCamera;
          debugPrint("🔄 Camera moved! Fetching new bounds...");
          await logCameraBounds(mapboxMapController);
        }
      } catch (e) {
        debugPrint("❌ Error tracking camera state: $e");
      }
    });
  }

  @override
  @override
  void initState() {
    super.initState();
    selectedDate = DateTime.now();
    _availableIntervals = _getAvailableIntervals(selectedDate);
    _selectedInterval = _getCurrentInterval();

    startOfDay =
        DateTime(selectedDate.year, selectedDate.month, selectedDate.day);

    _initConnectivityListener();
    setupPositionTracking(userPositionStream, mapboxMapController);
    _initializeRealtimeListener();
    //if (mounted) loadSupabaseMarkers();
    // Initialize realtime listener
    _initializeRealtimeListener();
    /*_realtimeSubscription = Supabase.instance.client
        .from('reportfloodsituations')
        .stream(primaryKey: ['id']).listen((payload) {
      debugPrint('Database change detected - refreshing markers');
      

      if (mounted) {
        loadSupabaseMarkers(); // Refresh markers when database changes
      }
    });*/
  }

  Future<void> _initializeRealtimeListener({int retryCount = 0}) async {
    if (!_isConnected) {
      debugPrint(
          '⚠️ No internet connection. Skipping realtime listener initialization.');
      return;
    }

    try {
      // Clean up any existing subscription
      if (_realtimeSubscription != null) {
        await _realtimeSubscription?.cancel();
        _realtimeSubscription = null;
      }

      _realtimeSubscription = Supabase.instance.client
          .from('reportfloodsituations')
          .stream(primaryKey: ['id']).listen(
        (payload) {
          debugPrint('Database change detected - refreshing markers');
          if (mounted) {
            loadSupabaseMarkers();
          }
        },
        onError: (error) {
          debugPrint('Realtime subscription error: $error');
          if (retryCount < 3 && mounted) {
            // Exponential backoff for retries
            final delay = Duration(seconds: 2 * (retryCount + 1));
            debugPrint('Retrying in ${delay.inSeconds} seconds...');
            Future.delayed(delay, () {
              _initializeRealtimeListener(retryCount: retryCount + 1);
            });
          } else {
            debugPrint('Max retries reached or widget disposed');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Connection to updates lost. Pull to refresh.'),
                  duration: Duration(seconds: 1),
                ),
              );
            }
          }
        },
        cancelOnError: false, // Important: Don't cancel on error
      );

      debugPrint('✅ Realtime listener initialized successfully');
    } catch (e, stackTrace) {
      debugPrint('Error initializing realtime listener: $e');
      debugPrint('Stack trace: $stackTrace');

      if (retryCount < 3 && mounted && _isConnected) {
        // ADD _isConnected CHECK
        final delay = Duration(seconds: 2 * (retryCount + 1));
        debugPrint('Retrying in ${delay.inSeconds} seconds...');
        Future.delayed(delay, () {
          _initializeRealtimeListener(retryCount: retryCount + 1);
        });
      } else if (mounted) {
        String message = 'Connection to updates lost. Pull to refresh.';
        if (!_isConnected) {
          message = 'No internet connection for live updates.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    userPositionStream?.cancel();
    pointAnnotationManager?.deleteAll();
    _realtimeSubscription?.cancel();
    _realtimeSubscription = null;
    //Supabase.instance.client.removeAllChannels(); // Clean up listeners
    //  mapboxMapController?.dispose();
    _connectivitySubscription?.cancel();
    // Cancel subscription safely
    _realtimeSubscription?.cancel().catchError((e) {
      debugPrint('Error cancelling subscription: $e');
    });
    _realtimeSubscription = null;

    try {
      Supabase.instance.client.removeAllChannels();
    } catch (e) {
      debugPrint('Error cleaning up Supabase channels: $e');
    }
    // Clean up the map controller

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF213A57),
        title: const Text(
          'Jade Valley Map',
          style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 22,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        actions: [
          if (!_isConnected)
            Container(
              margin: EdgeInsets.only(right: 16),
              child: Icon(
                Icons.wifi_off,
                color: Colors.red,
                size: 24,
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          if (!_isConnected)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.all(8),
                color: Colors.red,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.wifi_off, color: Colors.white, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'No internet connection',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          // Map
          Positioned.fill(
            child: MapWidget(
              onMapCreated: (MapboxMap controller) async {
                mapboxMapController = controller;

                await onMapCreated(controller);
              },
              styleUri: MapboxStyles.OUTDOORS, // Set initial style
              textureView: true,
              onTapListener: (point) async {
                LatLng latLng = LatLng(
                  point.point.coordinates.lat.toDouble(),
                  point.point.coordinates.lng.toDouble(),
                );
                /* if (pointAnnotationManager != null) {
                  await addMarker(
                      mapboxMapController!, latLng, pointAnnotationManager!);
                }*/
                debugPrint(
                    "Tapped at: ${latLng.latitude}, ${latLng.longitude}");
                // setCameraToLatLng(latLng); // Center camera on tap
              },
              onLongTapListener: (point) => _onMapClickReport(point),
            ),
          ),
          Positioned(
            top: 20,
            left: 20,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Text(
                    DateFormat('MMM dd, yyyy').format(selectedDate),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.calendar_today, size: 20),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.light(
                                primary: Colors.blue,
                                onPrimary: Colors.white,
                                onSurface: Colors.black,
                              ),
                              textButtonTheme: TextButtonThemeData(
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.blue,
                                ),
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null && picked != selectedDate) {
                        setState(() {
                          selectedDate = picked;
                          _availableIntervals = _getAvailableIntervals(picked);
                          // Reset to last interval if current selection isn't available
                          if (!_availableIntervals
                              .contains(_selectedInterval)) {
                            _selectedInterval = _availableIntervals.isNotEmpty
                                ? _availableIntervals.last
                                : '';
                          }
                        });
                        await loadSupabaseMarkers();
                        /* ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                'Showing reports for ${DateFormat('MMM dd, yyyy').format(_selectedDate)}'),
                            duration: const Duration(seconds: 2),
                          ),
                        );*/
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _selectedInterval,
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedInterval = newValue;
                        });
                        loadSupabaseMarkers();
                      }
                    },
                    items: _availableIntervals
                        .map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    underline: Container(),
                    icon: const Icon(Icons.access_time, size: 20),
                    hint: const Text('Select interval'),
                  ),
                ],
              ),
            ),
          ),
          // Top-right dropdown for changing map style
          /* Positioned(
            top: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(.8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9), // Slight transparency
                borderRadius: BorderRadius.circular(2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: DropdownButtonHideUnderline(
                child: Tooltip(
                  message: "Change Map Style",
                  waitDuration: const Duration(
                      milliseconds: 500), // Delay before showing tooltip
                  showDuration:
                      const Duration(seconds: 2), // Tooltip visibility duration
                  child: DropdownButton<String>(
                    icon: const Icon(Icons.map, color: Colors.green),
                    value: _currentMapStyle, // Currently selected style
                    dropdownColor: Colors.white, // Dropdown background color
                    onChanged: (String? selectedStyle) {
                      if (selectedStyle != null) {
                        _toggleMapStyle(selectedStyle);
                      }
                    },
                    items: _mapStyles.map((String style) {
                      return DropdownMenuItem(
                        value: style,
                        child: Text(styleNames[style] ??
                            "Unknown"), // Use the mapped name
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),*/

          // Bottom-right buttons (location & pin)
          Positioned(
            bottom: 20,
            right: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Tooltip(
                  message: "Focus on your current location",
                  child: FloatingActionButton(
                    heroTag: 'focus_location',
                    onPressed: () => focusOnUserLocation(mapboxMapController),
                    backgroundColor: Colors.blue,
                    child: Icon(Icons.my_location),
                  ),
                ),
                const SizedBox(height: 10),
                Tooltip(
                  message: "Report your current location",
                  child: FloatingActionButton(
                    heroTag: 'pin_location',
                    onPressed: () async {
                      final position =
                          await focusOnUserLocation(mapboxMapController);
                      if (position != null && mounted) {
                        final latLng =
                            LatLng(position.latitude, position.longitude);
                        MapboxGeocoding geocoding = MapboxGeocoding();
                        String? address =
                            await geocoding.getAddressFromCoordinates(latLng);

                        showModalBottomSheet(
                          context: context,
                          builder: (BuildContext context) {
                            return Container(
                              padding: const EdgeInsets.all(20.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  const Text(
                                    'Use your current location?',
                                    style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 10),
                                  /*Text('Latitude: ${position.latitude}'),
                                  Text('Longitude: ${position.longitude}'),*/
                                  Text('Address: ${address ?? "Unknown"}'),
                                  const SizedBox(height: 20),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('Close'),
                                      ),
                                      const SizedBox(width: 10),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blue,
                                        ),
                                        onPressed: () {
                                          _submitReport(latLng);
                                          Navigator.pop(
                                              context); // Close the bottom sheet
                                        },
                                        child: const Text('Use Location'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      }
                    },
                    backgroundColor: Colors.red,
                    child: const Icon(Icons.location_pin),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> onMapCreated(MapboxMap controller) async {
    mapboxMapController = controller;

    // Initialize the annotation manager first
    debugPrint("Before creating manager");
    pointAnnotationManager =
        await controller.annotations.createPointAnnotationManager();

    debugPrint("After creating manager - value: $pointAnnotationManager");
    debugPrint("pointAnnotationManager: $pointAnnotationManager");

    // CRITICAL: Add tap listener for markers
    pointAnnotationManager?.addOnPointAnnotationClickListener(
      _MarkerClickListener((annotation) {
        debugPrint("🎯 Marker tapped with ID: ${annotation.id}");
        final reportData = markerToReportMap[annotation.id];
        if (reportData != null) {
          debugPrint("✅ Found report data: ${reportData['flood_status']}");
          _showMarkerDetails(reportData);
        } else {
          debugPrint("❌ No data for marker: ${annotation.id}");
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Marker details not available'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return true;
      }),
    );

// Now that the pointAnnotationManager is properly initialized, load markers.

    await loadSupabaseMarkers();
    await loadGeoJsonPointMarkers(); // Add this line
    try {
      // ✅ Load the GeoJSON file from assets
      String geoJsonString =
          await rootBundle.loadString('assets/jvmap.geojson');
      Map<String, dynamic> geoJsonData = json.decode(geoJsonString);

      // ✅ Extract polygon bounds
      List coordinates = geoJsonData['features'][0]['geometry']['coordinates']
          [0]; // First polygon
      double minLng = coordinates[0][0];
      double minLat = coordinates[0][1];
      double maxLng = minLng;
      double maxLat = minLat;

      for (var coord in coordinates) {
        double lng = coord[0];
        double lat = coord[1];
        if (lng < minLng) minLng = lng;
        if (lat < minLat) minLat = lat;
        if (lng > maxLng) maxLng = lng;
        if (lat > maxLat) maxLat = lat;
      }

      // ✅ Set camera bounds (restrict movement outside this bounding box)
      await mapboxMapController?.setBounds(
        CameraBoundsOptions(
          bounds: CoordinateBounds(
            infiniteBounds: false, // Enforce bounds restriction
            southwest: Point(coordinates: Position(minLng, minLat)),
            northeast: Point(coordinates: Position(maxLng, maxLat)),
          ),
          maxZoom: 20.0, // Allow zooming in
          minZoom: 8.0, // Prevent zooming out too much
        ),
      );

      // ✅ Add GeoJSON Source
      await mapboxMapController?.style.addSource(GeoJsonSource(
        id: "mask-source",
        data: geoJsonString,
      ));

      // ✅ Apply a LineLayer for borders
      addBorderLayer(mapboxMapController);

      // ✅ Enable User Location with Pulsing Effect
      await mapboxMapController?.location.updateSettings(
        LocationComponentSettings(
          enabled: true,
          pulsingEnabled: true,
        ),
      );

      debugPrint("✅ Map with bounds restriction loaded successfully");
    } catch (e) {
      debugPrint("❌ Error loading GeoJSON or updating map: $e");
    }

    // Optionally, load the GeoJSON source again if needed.
    try {
      String geoJsonString =
          await rootBundle.loadString('assets/jvmap.geojson');
      await controller.style.addSource(GeoJsonSource(
        id: "mask-source",
        data: geoJsonString,
      ));
      await addBorderLayer(controller);
    } catch (e) {
      debugPrint("Error loading GeoJSON: $e");
    }
  }

  Future<void> loadSupabaseMarkers() async {
    if (!_isConnected) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.wifi_off, color: Colors.white),
                SizedBox(width: 8),
                Text('No internet connection. Cannot load reports.'),
              ],
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    if (mapboxMapController == null || pointAnnotationManager == null) {
      debugPrint("❌ Map controller or annotation manager is null.");
      return;
    }

    try {
      // Show loading indicator
      if (mounted) {
        /*ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 16),
                Text('Loading reports...'),
              ],
            ),
            duration: Duration(seconds: 2),
          ),
        );*/
      }

      final reports = await fetchFloodReports(selectedDate, context,
          timeInterval: _selectedInterval);
      debugPrint("✅ Supabase returned ${reports.length} report records.");

      // First clear existing markers and sources
      await pointAnnotationManager?.deleteAll();
      markerToReportMap.clear(); // Clear the mapping

      // IMPROVED: More robust cleanup of existing heatmap
      await _cleanupHeatmap();
      await cleanupScatterLayer(mapboxMapController);

      // Handle empty reports
      if (reports.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'No reports found for ${DateFormat('MMM dd, yyyy').format(selectedDate)}'),
              duration: const Duration(seconds: 1),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // FIRST: Add the heatmap layer (will be at the bottom)
      await _addHeatmapData(reports);
      // SECOND: Add scatter visualization (will be above heatmap but below markers)
      await addScatterLayer(mapboxMapController, reports);
      // THIRD: Add main markers (will be on top)
      await _addMainMarkers(reports);
    } catch (e, stackTrace) {
      debugPrint("❌ Error loading markers: $e");
      debugPrint("Stack trace: $stackTrace");

      /*if (mounted) {
        String errorMessage = 'Failed to load markers';
        if (e.toString().contains('SocketException') ||
            e.toString().contains('TimeoutException')) {
          errorMessage = 'Network error. Check your internet connection.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            duration: Duration(seconds: 3),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => loadSupabaseMarkers(),
            ),
          ),
        );
      }*/

      /* if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load markers: ${e.toString()}'),
            duration: const Duration(seconds: 1),
            backgroundColor: Colors.red,
          ),
        );
        debugPrint("❌ Error loading markers: $e\nStack trace: $stackTrace");
      }*/
    }
    await loadGeoJsonPointMarkers();
  }

  Future<void> loadGeoJsonPointMarkers() async {
    if (mapboxMapController == null || pointAnnotationManager == null) {
      debugPrint(
          "❌ Map controller or annotation manager is null for GeoJSON points.");
      return;
    }

    try {
      // Load the GeoJSON file
      String geoJsonString =
          await rootBundle.loadString('assets/jvmap.geojson');
      Map<String, dynamic> geoJsonData = json.decode(geoJsonString);

      // Extract point features
      List<dynamic> features = geoJsonData['features'];
      List<Map<String, dynamic>> pointFeatures = features
          .where((feature) => feature['geometry']['type'] == 'Point')
          .cast<Map<String, dynamic>>()
          .toList();

      debugPrint("✅ Found ${pointFeatures.length} point features in GeoJSON");

      // Create markers for each point
      for (int i = 0; i < pointFeatures.length; i++) {
        final feature = pointFeatures[i];
        final coordinates = feature['geometry']['coordinates'];
        final lng = coordinates[0] as double;
        final lat = coordinates[1] as double;

        try {
          // Create a default marker with 0.7 opacity
          await pointAnnotationManager!.create(
            PointAnnotationOptions(
              geometry: Point(coordinates: Position(lng, lat)),
              iconImage: "", // No icon
              textField: "●", // Unicode black circle as red dot
              textSize: 25.0,
              textColor: const Color.fromARGB(204, 255, 0, 0)
                  .value, // Red with 0.8 opacity
              textOpacity: 0.8,
              textHaloColor: Colors.white.value,
              textHaloWidth: 2.0,
            ),
          );

          debugPrint("✅ Added GeoJSON point marker at ($lat, $lng)");
        } catch (e) {
          debugPrint(
              "❌ Failed to create marker for point $i at ($lat, $lng): $e");
        }
      }

      debugPrint(
          "✅ Successfully loaded ${pointFeatures.length} GeoJSON point markers");
    } catch (e) {
      debugPrint("❌ Error loading GeoJSON point markers: $e");
    }
  }

  Future<void> _addHeatmapData(List<Map<String, dynamic>> reports) async {
    final heatmapFeatures = reports
        .map((report) {
          final lat = report['latitude'] as double?;
          final lng = report['longitude'] as double?;
          final rawStatus = report['flood_status']?.toString();

          if (lat == null || lng == null || rawStatus == null) {
            debugPrint(
                "⚠️ Skipping record with missing data: lat=$lat, lng=$lng, status=$rawStatus");
            return null;
          }

          // Normalize the status string - trim whitespace and convert to lowercase
          final status = rawStatus.trim().toLowerCase();

          debugPrint(
              "Processing report at ($lat, $lng) with raw status: '$rawStatus' -> normalized: '$status'");

          // Assign a weight based on flood status severity
          double weight;
          switch (status) {
            case 'flood surge':
              weight = 1.0;
              debugPrint(
                  "✅ Flood Surge detected at ($lat, $lng) with weight $weight");
              break;
            case 'impassable':
              weight = 0.8;
              debugPrint(
                  "✅ Impassable detected at ($lat, $lng) with weight $weight");
              break;
            case 'rising water':
              weight = 0.5;
              debugPrint(
                  "✅ Rising Water detected at ($lat, $lng) with weight $weight");
              break;
            case 'passable':
              weight = 0.2;
              debugPrint(
                  "✅ Passable detected at ($lat, $lng) with weight $weight");
              break;
            case 'notflooded':
            case 'not flooded':
              weight = 0.1;
              debugPrint(
                  "✅ Not Flooded detected at ($lat, $lng) with weight $weight");
              break;
            default:
              weight = 0.0;
              debugPrint(
                  "⚠️ Unknown status '$status' at ($lat, $lng), using weight $weight");
          }

          final feature = {
            "type": "Feature",
            "properties": {
              "weight": weight,
              "flood_status": status, // Keep original status for debugging
            },
            "geometry": {
              "type": "Point",
              "coordinates": [lng, lat]
            }
          };

          debugPrint("Created feature: ${json.encode(feature)}");
          return feature;
        })
        .where((item) => item != null)
        .cast<Map<String, dynamic>>()
        .toList();

    debugPrint(
        "✅ Created ${heatmapFeatures.length} valid features for heatmap");

    final heatmapGeoJson = json.encode({
      "type": "FeatureCollection",
      "features": heatmapFeatures,
    });

    debugPrint("📍 Final GeoJSON structure: $heatmapGeoJson");

    // Add the GeoJSON source
    await mapboxMapController?.style.addSource(GeoJsonSource(
      id: "heatmap-source",
      data: heatmapGeoJson,
    ));
    debugPrint("✅ Added heatmap source");

    // Add the heatmap layer
    await mapboxMapController?.style.addLayer(HeatmapLayer(
      id: "heatmap-layer",
      sourceId: "heatmap-source",
    ));
    debugPrint("✅ Added heatmap layer");

    // Configure heatmap properties
    await mapboxMapController?.style.setStyleLayerProperty(
      "heatmap-layer",
      "heatmap-radius",
      [
        "interpolate",
        ["linear"],
        ["zoom"],
        10, 20, // At zoom 10, radius is 20
        15, 40 // At zoom 15, radius is 40
      ],
    );

    await mapboxMapController?.style.setStyleLayerProperty(
      "heatmap-layer",
      "heatmap-weight",
      [
        "case",
        ["has", "weight"],
        ["get", "weight"],
        0.1 // Default weight if property is missing
      ],
    );

    await mapboxMapController?.style.setStyleLayerProperty(
      "heatmap-layer",
      "heatmap-opacity",
      [
        "interpolate",
        ["linear"],
        ["zoom"],
        7, 1.0, // Fully opaque at low zoom
        14, 0.7 // Semi-transparent at high zoom
      ],
    );

    await mapboxMapController?.style.setStyleLayerProperty(
      "heatmap-layer",
      "heatmap-color",
      [
        "interpolate",
        ["linear"],
        ["heatmap-density"],
        0, "rgba(0, 0, 255, 0)", // Transparent blue at 0 density
        0.1, "rgba(0, 255, 0, 0.6)", // Green (Not flooded)
        0.3, "rgba(144, 238, 144, 0.8)", // Light green (Passable)
        0.5, "rgba(255, 255, 0, 0.9)", // Yellow (Rising water)
        0.7, "rgba(255, 165, 0, 1.0)", // Orange (Impassable)
        1.0, "rgba(255, 0, 0, 1.0)" // Red (Flood surge)
      ],
    );

    await mapboxMapController?.style.setStyleLayerProperty(
      "heatmap-layer",
      "heatmap-intensity",
      [
        "interpolate",
        ["linear"],
        ["zoom"],
        0, 1.0, // Lower intensity at low zoom
        9, 3.0 // Higher intensity at high zoom
      ],
    );

    debugPrint("✅ Configured all heatmap properties");

    // Add individual markers
    int markersAdded = 0;
    for (final report in reports) {
      final lat = report['latitude'] as double?;
      final lng = report['longitude'] as double?;
      final status = report['flood_status']?.toString() ?? 'unknown';

      if (lat != null && lng != null) {
        try {
          final annotation = await pointAnnotationManager!.create(
            PointAnnotationOptions(
              geometry: Point(coordinates: Position(lng, lat)),
              iconImage: "flood-marker",
              iconSize: 1.5,
              iconOffset: [0, -20],
              textField: getStatusEmoji(status),
              textSize: 24.0,
              textColor: getStatusColor(status).value,
              textHaloColor: Colors.white.value,
              textHaloWidth: 10.0,
              iconColor: getStatusColor(status).value,
            ),
          );

          markerToReportMap[annotation.id] = report;

          markersAdded++;

          debugPrint("✅ Added marker at ($lat, $lng) with status: $status");
        } catch (e) {
          debugPrint("❌ Marker creation failed at ($lat, $lng): $e");
        }
      } else {
        debugPrint(
            "⚠️ Skipped record with null coordinates: lat=$lat, lng=$lng");
      }
    }

    debugPrint(
        "✅ Total markers added: $markersAdded for ${DateFormat('MMM dd, yyyy').format(selectedDate)}");
    debugPrint("✅ Marker mapping size: ${markerToReportMap.length}");

    if (mounted && markersAdded > 0) {
      /*  ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Loaded $markersAdded reports for ${DateFormat('MMM dd, yyyy').format(_selectedDate)}'),
            duration: const Duration(seconds: 1),
            backgroundColor: Colors.green,
          ),
        );*/
    }
  }

  Future<void> _addMainMarkers(List<Map<String, dynamic>> reports) async {
    int markersAdded = 0;
    for (final report in reports) {
      final lat = report['latitude'] as double?;
      final lng = report['longitude'] as double?;
      final status = report['flood_status']?.toString() ?? 'unknown';

      if (lat != null && lng != null) {
        try {
          // Make main markers more prominent
          final annotation = await pointAnnotationManager!.create(
            PointAnnotationOptions(
              geometry: Point(coordinates: Position(lng, lat)),
              iconImage: "flood-marker",
              iconSize: 1.8, // Slightly larger
              iconOffset: [0, -20],
              textField: getStatusEmoji(status),
              textSize: 28.0, // Larger text
              textColor: getStatusColor(status).value,
              textHaloColor: Colors.white.value,
              textHaloWidth: 12.0, // More prominent halo
              iconColor: getStatusColor(status).value,
              iconHaloColor: Colors.white.value, // Add halo to icon
              iconHaloWidth: 2.0,
            ),
          );

          markerToReportMap[annotation.id] = report;
          markersAdded++;
        } catch (e) {
          debugPrint("❌ Marker creation failed at ($lat, $lng): $e");
        }
      }
    }
  }

  // Helper method for robust heatmap cleanup
  Future<void> _cleanupHeatmap() async {
    try {
      // Check if layer exists before removing
      final layerExists =
          await mapboxMapController?.style.styleLayerExists("heatmap-layer") ??
              false;
      if (layerExists) {
        await mapboxMapController?.style.removeStyleLayer("heatmap-layer");
        debugPrint("🧹 Removed existing heatmap layer");
      }
    } catch (e) {
      debugPrint("ℹ️ Layer removal handled: $e");
    }

    try {
      // Check if source exists before removing
      final sourceExists = await mapboxMapController?.style
              .styleSourceExists("heatmap-source") ??
          false;
      if (sourceExists) {
        await mapboxMapController?.style.removeStyleSource("heatmap-source");
        debugPrint("🧹 Removed existing heatmap source");
      }
    } catch (e) {
      debugPrint("ℹ️ Source removal handled: $e");
    }

    // Add a small delay to ensure cleanup is complete
    await Future.delayed(const Duration(milliseconds: 100));
  }

// Helper function to build detail rows
  Widget _buildDetailRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: valueColor,
                fontWeight:
                    label == 'Status' ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

// Helper function to format date
  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('MMM dd, yyyy at h:mm a').format(date);
    } catch (e) {
      return dateString;
    }
  }

  Future<void> _showMarkerDetails(Map<String, dynamic> reportData) async {
    final status = reportData['flood_status']?.toString() ?? 'Unknown';
    final address =
        reportData['location_address']?.toString() ?? 'Unknown Location';
    final reportedBy =
        reportData['flood_reportedby']?.toString() ?? 'Anonymous';
    final createdOn = reportData['created_on']?.toString() ?? 'Unknown Date';
    final description = reportData['floodreport_description']?.toString() ??
        'No description provided';
    final lat = reportData['latitude']?.toString() ?? 'N/A';
    final lng = reportData['longitude']?.toString() ?? 'N/A';
    final reportedImg = reportData['reported_flood_image']?.toString() ?? '';
    final upvote_count = reportData['upvote_count']?.toString() ?? 'N/A';
    final downvote_count = reportData['downvote_count']?.toString() ?? 'N/A';
    final reportId = reportData['floodreport_id']?.toString() ?? '';

    // Get initial vote counts and user's vote status
    final voteCounts = await mapbox_functions.getVoteCounts(reportId);
    final userVoteStatus = await mapbox_functions.checkUserVoteStatus(reportId);
    // State variables for vote buttons
    bool isUpvoted = userVoteStatus['voteType'] == 'upvote';
    bool isDownvoted = userVoteStatus['voteType'] == 'downvote';
    int currentUpvotes = voteCounts['upvotes'] ?? 0;
    int currentDownvotes = voteCounts['downvotes'] ?? 0;
    bool hasVoted = userVoteStatus['hasVoted'];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Container(
              padding: const EdgeInsets.all(20.0),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with status indicator
                    Row(
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: getStatusColor(status),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              getStatusEmoji(status),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Flood Report Details',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 10),

                    // Image Section with watermark and tap to fullscreen
                    // In the _showMarkerDetails method, modify the image section to look like this:

// Image Section with watermark and tap to fullscreen
                    if (reportedImg.isNotEmpty && reportedImg != 'N/A')
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Flood Image:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () {
                              _showFullScreenImage(reportedImg);
                            },
                            child: Container(
                              width: double.infinity,
                              height:
                                  MediaQuery.of(context).size.width * (5 / 7),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.3),
                                    spreadRadius: 2,
                                    blurRadius: 5,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(
                                      reportedImg,
                                      width: double.infinity,
                                      height: double.infinity,
                                      fit: BoxFit.cover,
                                      loadingBuilder:
                                          (context, child, loadingProgress) {
                                        if (loadingProgress == null)
                                          return child;
                                        return Container(
                                          height: MediaQuery.of(context)
                                                  .size
                                                  .width *
                                              (5 / 7),
                                          child: Center(
                                            child: CircularProgressIndicator(
                                              value: loadingProgress
                                                          .expectedTotalBytes !=
                                                      null
                                                  ? loadingProgress
                                                          .cumulativeBytesLoaded /
                                                      loadingProgress
                                                          .expectedTotalBytes!
                                                  : null,
                                            ),
                                          ),
                                        );
                                      },
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                        return Container(
                                          height: MediaQuery.of(context)
                                                  .size
                                                  .width *
                                              (5 / 7),
                                          decoration: BoxDecoration(
                                            color: Colors.grey[200],
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: const Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.broken_image,
                                                size: 50,
                                                color: Colors.grey,
                                              ),
                                              SizedBox(height: 8),
                                              Text(
                                                'Failed to load image',
                                                style: TextStyle(
                                                    color: Colors.grey),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 10,
                                    right: 10,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.3),
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          Icon(
                                            Icons.tap_and_play,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            'Tap to view fullscreen',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
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
                          const SizedBox(height: 15),
                        ],
                      ),

// Always show the voting buttons section, regardless of image presence
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Upvote/Downvote buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // Upvote button
                            ElevatedButton.icon(
                              onPressed: hasVoted
                                  ? null
                                  : () async {
                                      final success =
                                          await mapbox_functions.handleVote(
                                              reportId, 'upvote', context);
                                      if (success) {
                                        setState(() {
                                          isUpvoted = true;
                                          hasVoted = true;
                                          currentUpvotes++;
                                        });
                                      }
                                    },
                              icon: Icon(
                                isUpvoted
                                    ? Icons.thumb_up
                                    : Icons.thumb_up_outlined,
                                color: isUpvoted
                                    ? Colors.white
                                    : (hasVoted ? Colors.grey : Colors.green),
                              ),
                              label: Text(
                                'Upvote ($currentUpvotes)',
                                style: TextStyle(
                                  color: isUpvoted
                                      ? Colors.white
                                      : (hasVoted ? Colors.grey : Colors.green),
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    isUpvoted ? Colors.green : Colors.white,
                                side: BorderSide(
                                  color: hasVoted && !isUpvoted
                                      ? Colors.grey
                                      : Colors.green,
                                  width: 1,
                                ),
                                elevation: isUpvoted ? 2 : 0,
                              ),
                            ),

                            // Downvote button
                            ElevatedButton.icon(
                              onPressed: hasVoted
                                  ? null
                                  : () async {
                                      final success = await handleVote(
                                          reportId, 'downvote', context);
                                      if (success) {
                                        setState(() {
                                          isDownvoted = true;
                                          hasVoted = true;
                                          currentDownvotes++;
                                        });
                                      }
                                    },
                              icon: Icon(
                                isDownvoted
                                    ? Icons.thumb_down
                                    : Icons.thumb_down_outlined,
                                color: isDownvoted
                                    ? Colors.white
                                    : (hasVoted ? Colors.grey : Colors.red),
                              ),
                              label: Text(
                                'Downvote ($currentDownvotes)',
                                style: TextStyle(
                                  color: isDownvoted
                                      ? Colors.white
                                      : (hasVoted ? Colors.grey : Colors.red),
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    isDownvoted ? Colors.red : Colors.white,
                                side: BorderSide(
                                  color: hasVoted && !isDownvoted
                                      ? Colors.grey
                                      : Colors.red,
                                  width: 1,
                                ),
                                elevation: isDownvoted ? 2 : 0,
                              ),
                            ),
                          ],
                        ),

                        if (hasVoted)
                          Container(
                            margin: const EdgeInsets.only(top: 10),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue[200]!),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info,
                                    color: Colors.blue[600], size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'You have ${isUpvoted ? 'upvoted' : 'downvoted'} this report',
                                    style: TextStyle(
                                      color: Colors.blue[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        const SizedBox(height: 15),
                      ],
                    ),

                    // Status
                    _buildDetailRow('Status', status, getStatusColor(status)),

                    // Address
                    _buildDetailRow('Location', address, Colors.black87),

                    // Coordinates
                    _buildDetailRow(
                        'Coordinates:', '$lat, $lng', Colors.black54),

                    // Date
                    //_buildDetailRow('Date', _formatDate(createdOn), Colors.black87),
                    // Add this to your details display:
                    _buildDetailRow(
                      'Reported on: ',
                      '${_formatCreatedOnTime(createdOn)} (${_formatTimeAgo(createdOn)})',
                      Colors.black87,
                    ),
                    // Updated vote counts display (remove the old ones since we have buttons now)
                    // _buildDetailRow('Upvotes', currentUpvotes.toString(), Colors.green),
                    // _buildDetailRow('Downvotes', currentDownvotes.toString(), Colors.red),

                    // Description
                    if (description.isNotEmpty &&
                        description != 'No description provided')
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 15),
                          const Text(
                            'Description:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              description,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),

                    const SizedBox(height: 20),

                    // Action button (only Center Map now)
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // Center map on this location
                          final lat = reportData['latitude'] as double?;
                          final lng = reportData['longitude'] as double?;
                          if (lat != null && lng != null) {
                            setCameraToLatLng(LatLng(lat, lng));
                            Navigator.pop(context);
                          }
                        },
                        icon: const Icon(Icons.center_focus_strong),
                        label: const Text('Center Map'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<Map<String, int>> _getVoteCounts(String reportId) async {
    try {
      final supabase = Supabase.instance.client;

      // Count upvotes
      final upvoteResponse = await supabase
          .from('user_votes')
          .select('id')
          .eq('report_id', reportId)
          .eq('vote_type', 'upvote');

      // Count downvotes
      final downvoteResponse = await supabase
          .from('user_votes')
          .select('id')
          .eq('report_id', reportId)
          .eq('vote_type', 'downvote');

      return {
        'upvotes': upvoteResponse.length,
        'downvotes': downvoteResponse.length,
      };
    } catch (e) {
      debugPrint('Error getting vote counts: $e');
      return {'upvotes': 0, 'downvotes': 0};
    }
  }

// Handle voting logic with database update

// Helper method to show full-screen image
  void _showFullScreenImage(String imageUrl) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.black,
          child: Stack(
            children: [
              Container(
                width: double.infinity,
                height: double.infinity,
                child: InteractiveViewer(
                  panEnabled: true,
                  boundaryMargin: const EdgeInsets.all(20),
                  minScale: 0.5,
                  maxScale: 4,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) {
                        return child;
                      }
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Colors.white,
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.broken_image,
                              size: 100,
                              color: Colors.white,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Failed to load image',
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              Positioned(
                top: 40,
                right: 20,
                child: IconButton(
                  icon: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 30,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Add this helper method for time formatting
  String _formatTimeAgo(String dateString) {
    try {
      final reportDate = DateTime.parse(dateString);

      final now = DateTime.now();
      final difference = now.difference(reportDate);

      if (difference.inDays > 0) {
        return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      debugPrint('Error formatting time ago: $e');
      return 'Unknown time';
    }
  }

// Add this helper method for Manila time formatting
  String _formatCreatedOnTime(String dateString) {
    try {
      final utcDate = DateTime.parse(dateString);
      return DateFormat('MMM dd, yyyy at h:mm a').format(utcDate.toLocal());
    } catch (e) {
      debugPrint('Error formatting time: $e');
      return dateString;
    }
  }

  Future<String?> getAddressFromCoordinates(LatLng coordinates) async {
    const String _baseUrl = "https://api.mapbox.com/geocoding/v5/mapbox.places";
    final String? _accessToken = dotenv
        .env['MAPBOX_ACCESS_TOKEN']; // Replace with your actual Mapbox token

    final url = Uri.parse(
        "$_baseUrl/${coordinates.longitude},${coordinates.latitude}.json?access_token=$_accessToken");

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['features'].isNotEmpty) {
          return data['features'][0]
              ['place_name']; // Get the most relevant place name
        }
      } else {
        debugPrint("❌ Error fetching address: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("❌ Exception in getAddressFromCoordinates: $e");
    }
    return null;
  }
}

class _MarkerClickListener extends OnPointAnnotationClickListener {
  final Function(PointAnnotation) onTap;

  _MarkerClickListener(this.onTap);

  @override
  bool onPointAnnotationClick(PointAnnotation annotation) {
    return onTap(annotation);
  }
}
