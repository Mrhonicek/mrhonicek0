import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geoloc;
import 'package:latlong2/latlong.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class ReportHandler {
  StreamSubscription<SupabaseStreamEvent>? _realtimeSubscription;

  Future<void> initializeRealtimeListener({
    required Function onDataChanged,
    int retryCount = 0,
  }) async {
    try {
      if (_realtimeSubscription != null) {
        await _realtimeSubscription?.cancel();
        _realtimeSubscription = null;
      }

      _realtimeSubscription = Supabase.instance.client
          .from('reportfloodsituations')
          .stream(primaryKey: ['id']).listen(
        (payload) => onDataChanged(),
        onError: (error) {
          debugPrint('Realtime error: $error');
          if (retryCount < 3) {
            final delay = Duration(seconds: 2 * (retryCount + 1));
            Future.delayed(delay, () {
              initializeRealtimeListener(
                onDataChanged: onDataChanged,
                retryCount: retryCount + 1,
              );
            });
          }
        },
        cancelOnError: false,
      );
    } catch (e, stackTrace) {
      debugPrint('Error initializing listener: $e\n$stackTrace');
      if (retryCount < 3) {
        final delay = Duration(seconds: 2 * (retryCount + 1));
        Future.delayed(delay, () {
          initializeRealtimeListener(
            onDataChanged: onDataChanged,
            retryCount: retryCount + 1,
          );
        });
      }
    }
  }

  Future<void> onMapClickReport(
    MapContentGestureContext gestureContext,
    BuildContext context,
    DateTime selectedDate,
  ) async {
    final latLng = LatLng(
      gestureContext.point.coordinates.lat.toDouble(),
      gestureContext.point.coordinates.lng.toDouble(),
    );

    final address = await _getAddressFromCoordinates(latLng);
    final reportCount = await _getReportCount(address);

    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Report Location',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text('Latitude: ${latLng.latitude}'),
              Text('Longitude: ${latLng.longitude}'),
              Text('Report count: $reportCount'),
              Text('Address: ${address ?? "Unknown"}'),
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
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: () {
                      _submitReport(latLng, context, selectedDate);
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

  Future<void> reportCurrentLocation(
    BuildContext context,
    MapboxMap? mapboxMapController,
    DateTime selectedDate,
  ) async {
    final position = await geoloc.Geolocator.getCurrentPosition();
    final latLng = LatLng(position.latitude, position.longitude);
    final address = await _getAddressFromCoordinates(latLng);

    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Current Location',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text('Latitude: ${position.latitude}'),
              Text('Longitude: ${position.longitude}'),
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
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                    onPressed: () {
                      _submitReport(latLng, context, selectedDate);
                      Navigator.pop(context);
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

  Future<void> _submitReport(
    LatLng latLng,
    BuildContext context,
    DateTime selectedDate,
  ) async {
    // Implementation would show the flood report modal
    // (Same as original _submitReport method)
  }

  Future<String?> _getAddressFromCoordinates(LatLng coordinates) async {
    // Implementation would call Mapbox Geocoding API
    // (Same as original getAddressFromCoordinates method)
  }

  Future<int> _getReportCount(String? locationAddress) async {
    if (locationAddress == null) return 0;
    final supabase = Supabase.instance.client;
    final response = await supabase
        .from('reportfloodsituations')
        .select('location_address')
        .eq('location_address', locationAddress)
        .count();
    return response.count ?? 0;
  }

  void dispose() {
    _realtimeSubscription?.cancel();
  }
}
