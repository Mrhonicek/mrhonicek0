import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

class WeatherCheckPage extends StatefulWidget {
  const WeatherCheckPage({Key? key}) : super(key: key);

  @override
  _WeatherCheckPageState createState() => _WeatherCheckPageState();
}

class _WeatherCheckPageState extends State<WeatherCheckPage> {
  bool isLoading = true;
  Map<String, dynamic> currentWeather = {};
  List<dynamic> forecastWeather = [];
  String errorMessage = '';

  // Replace with your actual AccuWeather API key
  final String apiKey = dotenv.env['ACCUWEATHER_API_KEY']!;

  // Tigatto, Davao City location key
  final String locationKey = '758326';

  @override
  void initState() {
    super.initState();
    fetchWeatherData();
  }

  Future<void> fetchWeatherData() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      // Fetch current conditions
      final currentResponse = await http.get(Uri.parse(
          'http://dataservice.accuweather.com/currentconditions/v1/$locationKey?apikey=$apiKey&details=true'));

      // Fetch 5-day forecast
      final forecastResponse = await http.get(Uri.parse(
          'http://dataservice.accuweather.com/forecasts/v1/daily/5day/$locationKey?apikey=$apiKey&details=true&metric=true'));

      if (currentResponse.statusCode == 200 &&
          forecastResponse.statusCode == 200) {
        final currentData = json.decode(currentResponse.body);
        final forecastData = json.decode(forecastResponse.body);

        setState(() {
          currentWeather = currentData[0];
          forecastWeather = forecastData['DailyForecasts'];
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Failed to load weather data. Please try again later.';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error: $e';
        isLoading = false;
      });
    }
  }

  String getWeatherIcon(int weatherCode) {
    // Map AccuWeather icon codes to emoji icons
    // This is a simple mapping, you could use actual icon assets instead
    if (weatherCode >= 1 && weatherCode <= 3) return '☀️'; // Sunny
    if (weatherCode >= 4 && weatherCode <= 6) return '🌤️'; // Partly Sunny
    if (weatherCode >= 7 && weatherCode <= 11) return '☁️'; // Cloudy
    if (weatherCode >= 12 && weatherCode <= 18) return '🌧️'; // Showers
    if (weatherCode >= 19 && weatherCode <= 29) return '🌨️'; // Snow/Mixed
    if (weatherCode >= 30 && weatherCode <= 34) return '🌡️'; // Hot/Cold
    if (weatherCode >= 35 && weatherCode <= 38) return '💨'; // Windy
    if (weatherCode >= 39 && weatherCode <= 44) return '🌦️'; // Thunderstorms
    return '❓'; // Unknown
  }

  String formatDate(String dateString) {
    final date = DateTime.parse(dateString);
    return DateFormat('EEE, MMM d').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.blue.shade800, Colors.blue.shade200],
              ),
            ),
            child: SafeArea(
              child: isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : errorMessage.isNotEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                errorMessage,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 16),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton(
                                onPressed: fetchWeatherData,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: fetchWeatherData,
                          child: ListView(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            children: [
                              const SizedBox(height: 20),
                              // Location Header
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.location_on,
                                      color: Colors.white),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Tigatto, Davao City',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 30),

                              // Current Weather Display
                              Card(
                                elevation: 6,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                color: Colors.white.withOpacity(0.2),
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '${currentWeather['Temperature']?['Metric']?['Value']?.toStringAsFixed(1) ?? '--'}°C',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 64,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 5),
                                              Text(
                                                currentWeather['WeatherText'] ??
                                                    'Unknown',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 20,
                                                ),
                                              ),
                                              const SizedBox(height: 5),
                                              Text(
                                                'Feels like: ${currentWeather['RealFeelTemperature']?['Metric']?['Value']?.toStringAsFixed(1) ?? '--'}°C',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Text(
                                            getWeatherIcon(
                                                currentWeather['WeatherIcon'] ??
                                                    0),
                                            style:
                                                const TextStyle(fontSize: 80),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 20),
                                      const Divider(
                                          color: Colors.white, thickness: 0.5),
                                      const SizedBox(height: 20),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceAround,
                                        children: [
                                          _buildWeatherDetailItem(
                                            Icons.water_drop,
                                            'Humidity',
                                            '${currentWeather['RelativeHumidity'] ?? '--'}%',
                                          ),
                                          _buildWeatherDetailItem(
                                            Icons.air,
                                            'Wind',
                                            '${currentWeather['Wind']?['Speed']?['Metric']?['Value']?.toStringAsFixed(1) ?? '--'} km/h',
                                          ),
                                          _buildWeatherDetailItem(
                                            Icons.visibility,
                                            'Visibility',
                                            '${currentWeather['Visibility']?['Metric']?['Value']?.toStringAsFixed(1) ?? '--'} km',
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 15),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceAround,
                                        children: [
                                          _buildWeatherDetailItem(
                                            Icons.compress,
                                            'Pressure',
                                            '${currentWeather['Pressure']?['Metric']?['Value']?.toStringAsFixed(0) ?? '--'} mb',
                                          ),
                                          _buildWeatherDetailItem(
                                            Icons.water,
                                            'Precipitation',
                                            '${currentWeather['Precip1hr']?['Metric']?['Value'] ?? '0'} mm',
                                          ),
                                          _buildWeatherDetailItem(
                                            Icons.wb_sunny,
                                            'UV Index',
                                            '${currentWeather['UVIndex'] ?? '--'} ${currentWeather['UVIndexText'] ?? ''}',
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              const SizedBox(height: 25),

                              // Forecast Title
                              const Padding(
                                padding: EdgeInsets.only(left: 8),
                                child: Text(
                                  '5-Day Forecast',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 15),

                              // 5-Day Forecast
                              SizedBox(
                                height: 250,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: forecastWeather.length,
                                  itemBuilder: (context, index) {
                                    final forecast = forecastWeather[index];
                                    return Card(
                                      elevation: 5,
                                      margin: const EdgeInsets.only(right: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      color: Colors.white.withOpacity(0.2),
                                      child: Container(
                                        width: 120,
                                        padding: const EdgeInsets.all(20),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              formatDate(forecast['Date']),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 15),
                                            Text(
                                              getWeatherIcon(forecast['Day']
                                                      ?['Icon'] ??
                                                  0),
                                              style:
                                                  const TextStyle(fontSize: 32),
                                            ),
                                            const SizedBox(height: 10),
                                            Text(
                                              forecast['Day']?['IconPhrase'] ??
                                                  'Unknown',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                              ),
                                              textAlign: TextAlign.center,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 10),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  '${forecast['Temperature']?['Maximum']?['Value']?.toStringAsFixed(0) ?? '--'}°',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const Text(
                                                  ' / ',
                                                  style: TextStyle(
                                                      color: Colors.white70),
                                                ),
                                                Text(
                                                  '${forecast['Temperature']?['Minimum']?['Value']?.toStringAsFixed(0) ?? '--'}°',
                                                  style: const TextStyle(
                                                      color: Colors.white70),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),

                              const SizedBox(height: 25),

                              // Bottom info card
                              Card(
                                elevation: 4,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                color: Colors.white.withOpacity(0.2),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Weather Info',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Last updated: ${DateFormat('MMM d, yyyy - h:mm a').format(DateTime.parse(currentWeather['LocalObservationDateTime'] ?? DateTime.now().toIso8601String()))}',
                                        style: const TextStyle(
                                            color: Colors.white),
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'Data provided by AccuWeather',
                                        style: TextStyle(color: Colors.white70),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
            ),
          ),
          Positioned(
            top: 16,
            left: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(8),
                child: const Icon(Icons.close, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherDetailItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
      ],
    );
  }
}
