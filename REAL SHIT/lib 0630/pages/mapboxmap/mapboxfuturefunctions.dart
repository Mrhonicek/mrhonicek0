import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geoloc;
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:gismultiinstancetestingenvironment/pages/mapboxmap/mapboxmappage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> onMapStyleLoaded(MapboxMap? mapboxMapController) async {
  try {
    String geoJsonString =
        await rootBundle.loadString('assets/jadevalley.geojson');

    await mapboxMapController?.style.addSource(GeoJsonSource(
      id: "mask-source",
      data: geoJsonString,
    ));

    await addBorderLayer(mapboxMapController);
    debugPrint("✅ Polygon restored after style change.");
  } catch (e) {
    debugPrint("❌ Error restoring polygon: $e");
  }
}

Future<void> addHeatmapLayer(MapboxMap? mapboxMapController) async {
  await mapboxMapController?.style.addLayer(HeatmapLayer(
    id: "flood-heatmap-layer",
    sourceId: "flood-reports-source",
    heatmapColor: Colors.red.value,
    heatmapIntensity: 0.6, // Reduced from 0.8
    heatmapOpacity: 0.65, // Slightly reduced
    heatmapRadius: 12, // Reduced from 20
    heatmapWeight: 0.5, // Reduced from 1.0
  ));
}

Future<void> logCameraBounds(MapboxMap? mapboxMapController) async {
  if (mapboxMapController == null) return;

  try {
    CameraState? currentCamera = await mapboxMapController.getCameraState();
    if (currentCamera != null) {
      CameraOptions cameraOptions = CameraOptions(
        center: currentCamera.center,
        zoom: currentCamera.zoom,
        bearing: currentCamera.bearing,
        pitch: currentCamera.pitch,
      );

      CoordinateBounds bounds =
          await mapboxMapController.coordinateBoundsForCamera(cameraOptions);
      print("Camera Bounds: "
          "SW: (${bounds.southwest?.coordinates.lat}, ${bounds.southwest?.coordinates.lng}) "
          "NE: (${bounds.northeast?.coordinates.lat}, ${bounds.northeast?.coordinates.lng})");
    }
  } catch (e) {
    print("❌ Error getting camera bounds: $e");
  }
}

Future<void> createHeatmapSource(
    MapboxMap? mapboxMapController, List<Map<String, dynamic>> reports) async {
  final features = reports
      .map((report) {
        final lat = report['latitude'] as double?;
        final lng = report['longitude'] as double?;
        if (lat == null || lng == null) return null;

        return {
          "type": "Feature",
          "geometry": {
            "type": "Point",
            "coordinates": [lng, lat]
          },
          "properties": {
            // Vary intensity based on report data
            "intensity": (report['severity_level'] ?? 1.0).toDouble()
          }
        };
      })
      .where((feature) => feature != null)
      .toList();

  final geoJson = {"type": "FeatureCollection", "features": features};

  await mapboxMapController?.style.addSource(GeoJsonSource(
    id: "flood-reports-source",
    data: json.encode(geoJson),
  ));
}

Future<void> addBorderLayer(MapboxMap? mapboxMapController) async {
  await mapboxMapController?.style.addLayer(LineLayer(
    id: "border-layer",
    sourceId: "mask-source",
    lineColor: Colors.red.value,
    lineWidth: 1.8,
  ));
}

/*Future<void> addMarker(MapboxMap mapboxMap, LatLng coordinates,
    PointAnnotationManager pointAnnotationManager) async {
  await pointAnnotationManager.create(
    PointAnnotationOptions(
      geometry: Point(
        coordinates: Position(coordinates.longitude, coordinates.latitude),
      ),
      textField: '📍!', // Using emoji as marker
      textSize: 24.0,
      textColor: Colors.red.value,
    ),
  );
}*/

// Helper function to load image from assets
Future<ByteData> loadImageFromAssets(String path) async {
  return await rootBundle.load(path);
}

Future<bool> handleVote(
    String reportId, String voteType, BuildContext context) async {
  try {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please log in to vote'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return false;
    }

    // Check if user has already voted
    final voteStatus = await checkUserVoteStatus(reportId);

    if (voteStatus['hasVoted']) {
      // User has already voted
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('You have already ${voteStatus['voteType']}d this report'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return false;
    }

    // Insert the vote
    await supabase.from('user_votes').insert({
      'user_id': user.id,
      'report_id': reportId,
      'vote_type': voteType,
    });

    // Update the main report table with new counts
    final voteCounts = await getVoteCounts(reportId);

    await supabase.from('reportfloodsituations').update({
      'upvote_count': voteCounts['upvotes'],
      'downvote_count': voteCounts['downvotes'],
    }).eq('floodreport_id', reportId);

    return true;
  } catch (e) {
    debugPrint('Error handling vote: $e');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to record vote: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
    return false;
  }
}

Future<Map<String, int>> getVoteCounts(String reportId) async {
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

Future<Map<String, dynamic>> checkUserVoteStatus(String reportId) async {
  try {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) {
      return {'hasVoted': false, 'voteType': null};
    }

    final response = await supabase
        .from('user_votes')
        .select('vote_type')
        .eq('user_id', user.id)
        .eq('report_id', reportId)
        .maybeSingle();

    if (response != null) {
      return {'hasVoted': true, 'voteType': response['vote_type']};
    }

    return {'hasVoted': false, 'voteType': null};
  } catch (e) {
    debugPrint('Error checking vote status: $e');
    return {'hasVoted': false, 'voteType': null};
  }
}

Future<void> onMapCreated(
    MapboxMap controller, DateTime selectedDate, context) async {
  var mapboxMapController = controller;
  var pointAnnotationManager =
      await controller.annotations.createPointAnnotationManager();

  pointAnnotationManager =
      await controller.annotations.createPointAnnotationManager();

  print("pointAnnotationManager: $pointAnnotationManager");

  try {
    final reports = await fetchFloodReports(selectedDate, context);
    // ✅ Load the GeoJSON file from assets
    String geoJsonString =
        await rootBundle.loadString('assets/jadevalley.geojson');
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
        maxZoom: 18.0, // Allow zooming in
        minZoom: 12.0, // Prevent zooming out too much
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

    print("✅ Map with bounds restriction loaded successfully");
  } catch (e) {
    print("❌ Error loading GeoJSON or updating map: $e");
  }

  try {
    String geoJsonString =
        await rootBundle.loadString('assets/jadevalley.geojson');
    await controller.style.addSource(GeoJsonSource(
      id: "mask-source",
      data: geoJsonString,
    ));
    await addBorderLayer(controller);
  } catch (e) {
    print("Error loading GeoJSON: $e");
  }
  // ✅ Add flood report markers with status 'granted'
  try {
    final reports = await fetchFloodReports(selectedDate, context);

    for (var report in reports) {
      final coord = report['address_coordinates'];

      if (coord != null && coord['coordinates'] != null) {
        final lng = coord['coordinates'][0];
        final lat = coord['coordinates'][1];

        /*await addMarker(
          mapboxMapController,
          LatLng(lat, lng),
          pointAnnotationManager,
        );*/
      }
    }

    print("✅ Flood report markers added.");
  } catch (e) {
    print("❌ Error adding flood report markers: $e");
  }
}

Future<void> addScatterLayer(
    MapboxMap? mapboxMapController, List<Map<String, dynamic>> reports) async {
  // First clean up any existing scatter layer
  await cleanupScatterLayer(mapboxMapController);

  // Create features for each report with multiple points around the main location
  final features = reports
      .map((report) {
        final lat = report['latitude'] as double?;
        final lng = report['longitude'] as double?;
        final status =
            report['flood_status']?.toString().toLowerCase() ?? 'unknown';

        if (lat == null || lng == null) return null;

        // Determine scatter density based on severity
        int pointCount;
        switch (status) {
          case 'flood surge':
            pointCount = 60; // Highest density for flood surge
            break;
          case 'impassable':
            pointCount = 30; // Higher density for impassable
            break;
          case 'rising water':
            pointCount = 30; // Middle density for rising water
            break;
          case 'passable':
            pointCount = 15; // Lowest density for passable
            break;
          case 'not flooded':
            pointCount = 0; // No such points to scatter
            break;
          default:
            pointCount = 1;
        }

        // Generate points in a small radius around the main location
        final scatterPoints = List.generate(pointCount, (index) {
          // Add slight random offset (within 0.0005 degrees ~50m)
          final rng = Random();
          final offsetLat = lat + (rng.nextDouble() * 0.0003 - 0.0002);
          final offsetLng = lng + (rng.nextDouble() * 0.0003 - 0.0002);

          return {
            "type": "Feature",
            "properties": {
              "status": status,
              "isMain": index == 0 // Mark the main point
            },
            "geometry": {
              "type": "Point",
              "coordinates": [offsetLng, offsetLat]
            }
          };
        });

        return scatterPoints;
      })
      .where((feature) => feature != null)
      .expand((points) => points!)
      .toList();

  final scatterGeoJson = json.encode({
    "type": "FeatureCollection",
    "features": features,
  });

  debugPrint("📍 Final scatter GeoJSON structure: $scatterGeoJson");

  // Add the GeoJSON source
  await mapboxMapController?.style.addSource(GeoJsonSource(
    id: "scatter-source",
    data: scatterGeoJson,
  ));
  debugPrint("✅ Added scatter source");

  // Add the basic circle layer
  await mapboxMapController?.style.addLayer(CircleLayer(
    id: "scatter-layer",
    sourceId: "scatter-source",
  ));
  debugPrint("✅ Added scatter layer");

  // Configure circle properties
  await mapboxMapController?.style.setStyleLayerProperty(
    "scatter-layer",
    "circle-radius",
    [
      "case",
      [
        "==",
        ["get", "isMain"],
        true
      ],
      5, // Larger for main point
      3 // Smaller for scatter points
    ],
  );

  await mapboxMapController?.style.setStyleLayerProperty(
    "scatter-layer",
    "circle-color",
    [
      "match",
      ["get", "status"],
      "flood surge", "#FF0000", // red
      "impassable", "#FFA500", // orange
      "rising water", "#FFFF00", // yellow
      "passable", "#90EE90", // light green
      "not flooded", "#008000", // green
      "notflooded", "#008000", // green
      "#0000FF" // blue (default)
    ],
  );

  await mapboxMapController?.style.setStyleLayerProperty(
    "scatter-layer",
    "circle-opacity",
    0.8,
  );

  await mapboxMapController?.style.setStyleLayerProperty(
    "scatter-layer",
    "circle-stroke-width",
    1,
  );

  await mapboxMapController?.style.setStyleLayerProperty(
    "scatter-layer",
    "circle-stroke-color",
    "#${Colors.white.value.toRadixString(16).padLeft(8, '0')}",
  );

  debugPrint("✅ Configured all scatter layer properties");
}

Future<void> cleanupScatterLayer(MapboxMap? mapboxMapController) async {
  try {
    // Remove layer if exists
    final layerExists =
        await mapboxMapController?.style.styleLayerExists("scatter-layer") ??
            false;
    if (layerExists) {
      await mapboxMapController?.style.removeStyleLayer("scatter-layer");
    }

    // Remove source if exists
    final sourceExists =
        await mapboxMapController?.style.styleSourceExists("scatter-source") ??
            false;
    if (sourceExists) {
      await mapboxMapController?.style.removeStyleSource("scatter-source");
    }
  } catch (e) {
    debugPrint("Error cleaning up scatter layer: $e");
  }
}

Future<void> setupPositionTracking(StreamSubscription? userPositionStream,
    MapboxMap? mapboxMapController) async {
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

  geoloc.LocationSettings locationSettings = const geoloc.LocationSettings(
    accuracy: geoloc.LocationAccuracy.high,
    distanceFilter: 100,
  );

  userPositionStream?.cancel();
  geoloc.Position? lastPosition;
  userPositionStream =
      geoloc.Geolocator.getPositionStream(locationSettings: locationSettings)
          .listen((geoloc.Position? position) {
    if (position != null && mapboxMapController != null) {
      if (lastPosition == null ||
          geoloc.Geolocator.distanceBetween(
                  lastPosition!.latitude,
                  lastPosition!.longitude,
                  position.latitude,
                  position.longitude) >
              10) {
        lastPosition = position;
        mapboxMapController.setCamera(
          CameraOptions(
            zoom: 12,
            center: Point(
              coordinates: Position(position.longitude, position.latitude),
            ),
          ),
        );
      }
    }
  });
}

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

Future<geoloc.Position?> focusOnUserLocation(
    MapboxMap? mapboxMapController) async {
  try {
    geoloc.Position position = await geoloc.Geolocator.getCurrentPosition(
      desiredAccuracy: geoloc.LocationAccuracy.high,
    );
    if (mapboxMapController != null) {
      mapboxMapController.setCamera(
        CameraOptions(
          center: Point(
            coordinates: Position(position.longitude, position.latitude),
          ),
          zoom: 15,
        ),
      );
      debugPrint(
          "Focused on user: Lat=${position.latitude}, Lng=${position.longitude}");
    }
    return position; // Return the position
  } catch (e) {
    debugPrint("Error getting user location: $e");
    return null;
  }
}

Future<List<Map<String, dynamic>>> fetchFloodReports(
    DateTime selectedDate, context,
    {String? timeInterval}) async {
  try {
    final supabase = Supabase.instance.client;

    final startOfDay =
        DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

// Convert back to UTC for database query
    DateTime startOfDayUtc =
        DateTime(selectedDate.year, selectedDate.month, selectedDate.day)
            .toUtc();
    DateTime endOfDayUtc = startOfDayUtc.add(const Duration(days: 1));

    if (timeInterval != null && timeInterval.isNotEmpty) {
      final interval = parseInterval(timeInterval, selectedDate);
      startOfDayUtc = interval['start']!.toUtc();
      endOfDayUtc = interval['end']!.toUtc();
    }

    debugPrint(
        '🗓️ Fetching reports for date: ${DateFormat('yyyy-MM-dd').format(selectedDate)}');
    debugPrint(
        '🕐 Time range (UTC): ${startOfDayUtc.toIso8601String()} to ${endOfDayUtc.toIso8601String()}');

    // Call stored procedure with date filtering
    final response = await supabase
        .rpc('get_flood_reports_with_coordsstatsdateff')
        .gte('created_on', startOfDayUtc.toIso8601String())
        .lt('created_on', endOfDayUtc.toIso8601String())
        .order('created_on', ascending: false);

    debugPrint(
        "✅ Fetched ${response.length} reports for ${DateFormat('MMM dd, yyyy').format(selectedDate)}");
    debugPrint("Fetched ${response.length} reports with coordinates");

    // Handle empty results
    if (response.isEmpty) {
      debugPrint("ℹ️ No reports found for the selected date");
      return [];
    }

    return List<Map<String, dynamic>>.from(response);
  } catch (e, stackTrace) {
    debugPrint("❌ Error fetching flood reports: $e");

    debugPrint("Stack trace: $stackTrace");

    // Show user-friendly error message
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load reports: ${e.toString()}'),
          duration: const Duration(seconds: 1),
          backgroundColor: Colors.red,
        ),
      );
    }
    return [];
  }
}
