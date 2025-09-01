import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geoloc;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapboxpkg;

class Mapboxhand extends StatefulWidget {
  const Mapboxhand({super.key});

  @override
  State<Mapboxhand> createState() => MapboxhandState();
}

class MapboxhandState extends State<Mapboxhand> {
  mapboxpkg.MapboxMap? mapboxMapController;
  StreamSubscription? userPositionStream;

  @override
  void initState() {
    super.initState();
    _setupPositionTracking();
  }

  @override
  void dispose() {
    userPositionStream?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: mapboxpkg.MapWidget(
        onMapCreated: _onMapCreated,
        styleUri: mapboxpkg.MapboxStyles.OUTDOORS,
      ),
    );
  }

  void _onMapCreated(
    mapboxpkg.MapboxMap controller,
  ) {
    setState(() {
      mapboxMapController = controller;
    });

    mapboxMapController?.location
        .updateSettings(mapboxpkg.LocationComponentSettings(
      enabled: true,
      pulsingEnabled: true,
    ));
  }

  Future<void> _setupPositionTracking() async {
    bool serviceEnabled;
    geoloc.LocationPermission permission;

    serviceEnabled = await geoloc.Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }
    permission = await geoloc.Geolocator.checkPermission();
    if (permission == geoloc.LocationPermission.denied) {
      permission = await geoloc.Geolocator.requestPermission();
      if (permission == geoloc.LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == geoloc.LocationPermission.deniedForever) {
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    geoloc.LocationSettings locationSettings = geoloc.LocationSettings(
      accuracy: geoloc.LocationAccuracy.high,
      distanceFilter: 100,
    );

    userPositionStream?.cancel();
    userPositionStream =
        geoloc.Geolocator.getPositionStream(locationSettings: locationSettings)
            .listen(
      (
        geoloc.Position? position,
      ) {
        if (position != null && mapboxMapController != null) {
          mapboxMapController?.setCamera(
            mapboxpkg.CameraOptions(
              zoom: 15,
              center: mapboxpkg.Point(
                coordinates:
                    mapboxpkg.Position(position.longitude, position.latitude),
              ),
            ),
          );
          print(
              "Latitude: ${position.latitude}, Longitude: ${position.longitude}");
        }
      },
    );
  }

  Future<void> focusOnUserLocation() async {
    try {
      geoloc.Position position = await geoloc.Geolocator.getCurrentPosition(
        desiredAccuracy: geoloc.LocationAccuracy.high,
      );

      if (mapboxMapController != null) {
        mapboxMapController?.setCamera(
          mapboxpkg.CameraOptions(
            center: mapboxpkg.Point(
              coordinates:
                  mapboxpkg.Position(position.longitude, position.latitude),
            ),
            zoom: 15, // Adjust zoom level if needed
          ),
        );

        print(
            "Focused on user: Lat=${position.latitude}, Lng=${position.longitude}");
      }
    } catch (e) {
      print("Error getting user location: $e");
    }
  }
}
