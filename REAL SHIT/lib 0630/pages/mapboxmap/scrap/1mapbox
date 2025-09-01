import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class MapboxST extends StatefulWidget {
  const MapboxST({super.key});

  @override
  State<MapboxST> createState() => _MapboxSTState();
}

class _MapboxSTState extends State<MapboxST> {
  MapboxMap? mapboxMapController;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MapWidget(
        onMapCreated: _onMapCreated,
      ),
    );
  }

  void _onMapCreated(
    MapboxMap controller,
  ) {
    setState(() {
      mapboxMapController = controller;
    });
  }
}
