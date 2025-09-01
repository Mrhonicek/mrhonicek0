import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class MapboxGeocoding {
  static const String _baseUrl =
      "https://api.mapbox.com/geocoding/v5/mapbox.places";
  final String? _accessToken = dotenv
      .env['MAPBOX_ACCESS_TOKEN']; // Replace with your actual Mapbox token

  // Function to fetch the address from Mapbox
  Future<String?> getAddressFromCoordinates(LatLng coordinates) async {
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
        print("❌ Error fetching address: ${response.statusCode}");
      }
    } catch (e) {
      print("❌ Exception in getAddressFromCoordinates: $e");
    }
    return null;
  }
}
