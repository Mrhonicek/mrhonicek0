import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart' as geoloc;
import 'package:http/http.dart' as http;
import 'package:gismultiinstancetestingenvironment/pages/mapboxmap/reportfloodsituationonmap.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

class OSMMapPage extends StatefulWidget {
  const OSMMapPage({super.key});

  @override
  State<OSMMapPage> createState() => _OSMMapPageState();
}

class _OSMMapPageState extends State<OSMMapPage> {
  MapController? mapController;
  LatLng? lastCameraPosition;
  double? lastZoom;
  List<LatLng> borderPolygon = []; // Holds the polygon points for the map
  LatLngBounds? _mapBounds;

  final List<String> _mapStyles = [
    "OpenStreetMap",
    "OpenTopoMap",
    "Satellite",
  ];

  final Map<String, String> styleNames = {
    "OpenStreetMap": "Standard",
    "OpenTopoMap": "Topographic",
    "Satellite": "Satellite",
  };

  String _currentMapStyle = "OpenStreetMap";
  bool _debugEnabled = false;
  StreamSubscription<SupabaseStreamEvent>? _realtimeSubscription;

  // Marker list for flood reports
  List<Marker> floodMarkers = [];

  Future<Object> _getReportCount(String? locationAddress) async {
    if (locationAddress == null) return 0;

    final supabase = Supabase.instance.client;
    final response = await supabase
        .from('reportfloodsituations')
        .select('location_address')
        .eq('location_address', locationAddress)
        .count();

    return response.count ?? 0;
  }

  void _onMapClickReport(TapPosition tapPosition, LatLng latLng) async {
    String? streetaddressname = await getAddressFromCoordinates(latLng);
    Object reportCount = await _getReportCount(streetaddressname);
    print('Map clicked for report at: ${latLng.latitude}, ${latLng.longitude}');

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
                'Report Location',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text('Latitude: ${latLng.latitude}'),
              Text('Longitude: ${latLng.longitude}'),
              Text('Report count: $reportCount'),
              Text('Address: $streetaddressname'),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    onPressed: () {
                      _submitReport(latLng);
                      Navigator.pop(context);
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

  Future<void> loadSupabaseMarkers() async {
    try {
      final reports = await fetchFloodReports();

      final newMarkers = reports
          .map((report) {
            final lat = report['latitude'] as double?;
            final lng = report['longitude'] as double?;
            if (lat != null && lng != null) {
              return Marker(
                point: LatLng(lat, lng),
                width: 40,
                height: 40,
                child: const Icon(
                  Icons.location_pin,
                  color: Colors.red,
                  size: 40,
                ),
              );
            }
            return null;
          })
          .whereType<Marker>()
          .toList();

      setState(() {
        floodMarkers = newMarkers;
      });

      print("✅ Loaded ${newMarkers.length} flood reports");
    } catch (e) {
      print("❌ Error loading markers: $e");
    }
  }

  Future<void> _submitReport(LatLng latLng) async {
    String? address = await getAddressFromCoordinates(latLng);
    showReportFloodModal(context, latLng, address ?? "Unknown Location");
    if (mounted) {
      await loadSupabaseMarkers();
    }
  }

  void setCameraToLatLng(LatLng latlng) {
    mapController?.move(latlng, 15);
  }

  void _toggleMapStyle(String selectedStyle) {
    setState(() {
      _debugEnabled = !_debugEnabled;
      _currentMapStyle = selectedStyle;
    });
  }

  bool _hasCameraMoved(LatLng newPosition, double newZoom) {
    if (lastCameraPosition == null) return true;

    return newPosition != lastCameraPosition || newZoom != lastZoom;
  }

  void startCameraTracking() {
    Timer.periodic(Duration(milliseconds: 500), (timer) async {
      if (mapController == null) return;

      try {
        final camera = mapController!.camera;
        LatLng currentPosition = camera.center;
        double currentZoom = camera.zoom;

        if (lastCameraPosition == null ||
            _hasCameraMoved(currentPosition, currentZoom)) {
          lastCameraPosition = currentPosition;
          lastZoom = currentZoom;
          print(
              "🔄 Camera moved! New position: $currentPosition, zoom: $currentZoom");
        }
      } catch (e) {
        print("❌ Error tracking camera state: $e");
      }
    });
  }

  @override
  void initState() {
    super.initState();
    mapController = MapController(); // Add this line
    setupPositionTracking();
    onMapStyleLoaded();
    if (mounted) loadSupabaseMarkers();
    _realtimeSubscription = Supabase.instance.client
        .from('reportfloodsituations')
        .stream(primaryKey: ['id']).listen((payload) {
      print('Database change detected - refreshing markers');
      loadSupabaseMarkers();
    });
  }

  @override
  void dispose() {
    Supabase.instance.client.removeAllChannels();
    mapController!.dispose();
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
      ),
      body: Stack(
        children: [
          // Map
          Positioned.fill(
            child: FlutterMap(
              mapController: mapController,
              options: MapOptions(
                initialCenter: LatLng(
                    7.108909, 125.592192), // Initial center (Jade Valley)
                initialZoom: 17.1,
                initialRotation: 10.0,
                maxZoom: 18.0, // Allow zooming in
                minZoom: 12.0, // Prevent zooming out too much

                //onTap: (tapPosition, latLng) =>_onMapClickReport(tapPosition, latLng),
                onLongPress: (tapPosition, point) =>
                    _onMapClickReport(tapPosition, point),
              ),
              children: [
                TileLayer(
                  urlTemplate: _getTileLayerUrl(),
                  userAgentPackageName:
                      'com.example.gismultiinstancetestingenvironment',
                ),
                if (borderPolygon.isNotEmpty)
                  PolygonLayer(
                    polygons: [
                      Polygon(
                        points: borderPolygon,
                        color: Colors.blue.withOpacity(0.3),
                        borderColor: Colors.blue,
                        borderStrokeWidth: 2,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: floodMarkers,
                ),
              ],
            ),
          ),

          // Top-right dropdown for changing map style
          Positioned(
            top: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(.8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
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
                  waitDuration: const Duration(milliseconds: 500),
                  showDuration: const Duration(seconds: 2),
                  child: DropdownButton<String>(
                    icon: const Icon(Icons.map, color: Colors.green),
                    value: _currentMapStyle,
                    dropdownColor: Colors.white,
                    onChanged: (String? selectedStyle) {
                      if (selectedStyle != null) {
                        _toggleMapStyle(selectedStyle);
                      }
                    },
                    items: _mapStyles.map((String style) {
                      return DropdownMenuItem(
                        value: style,
                        child: Text(styleNames[style] ?? "Unknown"),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),

          // Bottom-right buttons (location & pin)
          Positioned(
            bottom: 20,
            right: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Tooltip(
                  message: "Focus on device location",
                  child: FloatingActionButton(
                    heroTag: 'focus_location',
                    onPressed: () => focusOnUserLocation(),
                    backgroundColor: Colors.blue,
                    child: const Icon(Icons.my_location),
                  ),
                ),
                const SizedBox(height: 10),
                Tooltip(
                  message: "Pin the desired location",
                  child: FloatingActionButton(
                    heroTag: 'pin_location',
                    onPressed: () => focusOnUserLocation(),
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

  String _getTileLayerUrl() {
    switch (_currentMapStyle) {
      case "OpenStreetMap":
        return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
      case "OpenTopoMap":
        return 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png';
      case "Satellite":
        return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
      default:
        return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
    }
  }

  Future<void> onMapStyleLoaded() async {
    // Ensure this function has access to the borderPolygon variable
    List<LatLng> borderPoints = [];
    //  LatLngBounds bounds = LatLngBounds.fromPoints(borderPoints);
    try {
      String geoJsonString =
          await rootBundle.loadString('assets/jadevalley.geojson');
      final geoJson = jsonDecode(geoJsonString);
      final coordinates = geoJson['features'][0]['geometry']['coordinates'][0];

      borderPoints = coordinates.map<LatLng>((coord) {
        return LatLng(coord[1].toDouble(), coord[0].toDouble());
      }).toList();

      setState(() {
        borderPolygon = borderPoints;
        //  _mapBounds = bounds; // new field in the state
      });

      print("✅ Polygon loaded successfully");
    } catch (e) {
      print("❌ Error loading GeoJSON: $e");
    }
  }
}

Future<void> setupPositionTracking() async {
  bool serviceEnabled = await geoloc.Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    return Future.error('Location services are disabled.');
  }

  geoloc.LocationPermission permission =
      await geoloc.Geolocator.checkPermission();
  if (permission == geoloc.LocationPermission.denied) {
    permission = await geoloc.Geolocator.requestPermission();
    if (permission == geoloc.LocationPermission.denied) {
      return Future.error('Location permissions are denied');
    }
  }
  if (permission == geoloc.LocationPermission.deniedForever) {
    return Future.error('Location permissions are permanently denied.');
  }
}

Future<void> focusOnUserLocation() async {
  try {
    geoloc.Position position = await geoloc.Geolocator.getCurrentPosition(
      locationSettings: const geoloc.LocationSettings(
        accuracy: geoloc.LocationAccuracy.high,
      ),
    );
    final mapController = _OSMMapPageState().mapController;
    if (mapController != null) {
      mapController.move(
        LatLng(position.latitude, position.longitude),
        15,
      );
      print(
          "Focused on user: Lat=${position.latitude}, Lng=${position.longitude}");
    }
  } catch (e) {
    print("Error getting user location: $e");
  }
}

Future<List<Map<String, dynamic>>> fetchFloodReports() async {
  final supabase = Supabase.instance.client;
  final response = await supabase.from('reportfloodsituations').select('*');
  //.order('created_on', ascending: false);

  return List<Map<String, dynamic>>.from(response);
}

Future<String?> getAddressFromCoordinates(LatLng coordinates) async {
  const String _baseUrl = "https://nominatim.openstreetmap.org/reverse";

  final url = Uri.parse(
      "$_baseUrl?format=json&lat=${coordinates.latitude}&lon=${coordinates.longitude}&zoom=18&addressdetails=1");

  try {
    final response = await http
        .get(url, headers: {'User-Agent': 'YourAppName/1.0 (your@email.com)'});

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['display_name'];
    } else {
      print("❌ Error fetching address: ${response.statusCode}");
    }
  } catch (e) {
    print("❌ Exception in getAddressFromCoordinates: $e");
  }
  return null;
}
