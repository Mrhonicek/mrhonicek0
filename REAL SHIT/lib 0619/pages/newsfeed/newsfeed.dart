import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:gismultiinstancetestingenvironment/main.dart';
import 'package:gismultiinstancetestingenvironment/pages/appfeedback/appfeedbackandbugreports.dart';
import 'package:gismultiinstancetestingenvironment/pages/createpost.dart';
import 'package:gismultiinstancetestingenvironment/pages/inbox/inbox_page.dart';
import 'package:gismultiinstancetestingenvironment/pages/index.dart';
import 'package:gismultiinstancetestingenvironment/pages/mapboxmap/mapboxmappage.dart';
import 'package:gismultiinstancetestingenvironment/pages/profilepage.dart';
import 'package:gismultiinstancetestingenvironment/pages/riverbasin.dart';
import 'package:gismultiinstancetestingenvironment/pages/newsfeed/post_list.dart';
import 'package:gismultiinstancetestingenvironment/pages/emerg.dart';
import 'package:gismultiinstancetestingenvironment/pages/inbox/inbox_service_supa.dart';
import 'package:gismultiinstancetestingenvironment/pages/inbox/inbox_model.dart';
import 'package:gismultiinstancetestingenvironment/pages/splashsrc.dart';
import 'package:gismultiinstancetestingenvironment/pages/weather/weathercheck.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart'; // ADD THIS IMPORT
import 'dart:convert';

class NewsFeed extends StatefulWidget {
  @override
  _NewsFeedState createState() => _NewsFeedState();
}

class _NewsFeedState extends State<NewsFeed> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final InboxService _inboxService = InboxService();
  final List<NotifyBroadcast> _notifications = [];
  bool _isMounted = false; // ✅ Track widget state
  String? username = "Loading...";
  String? email = "Loading...";
  late Future<void> _refreshFuture;

  // Weather data variables
  String currentTemperature = "--";
  String weatherIcon = "☀️";
  bool isLoadingWeather = true;

  // ADD THESE CONNECTIVITY VARIABLES
  bool _isConnected = true;
  bool _showConnectivityBanner = false;

  // Replace with your actual AccuWeather API key
  final String apiKey = dotenv.env['ACCUWEATHER_API_KEY']!;

  // Tigatto, Davao City location key
  final String locationKey = '758326';

  @override
  void initState() {
    super.initState();

// Check for pending alerts after initialization
    /*WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 800), () {
        checkAndShowPendingAlert();
      });
    });*/

    _isMounted = true; // ✅ Mark as mounted
    _checkConnectivity(); // ADD THIS - Initial connectivity check
    _refreshFuture = _fetchUserDetailsAndWeather();
  }

  // ADD THIS METHOD - Check internet connectivity
  Future<void> _checkConnectivity() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    setState(() {
      _isConnected = connectivityResult != ConnectivityResult.none;
      _showConnectivityBanner = !_isConnected;
    });

    // Listen for connectivity changes
    Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      if (_isMounted) {
        setState(() {
          bool wasConnected = _isConnected;
          // Consider connected if any result is not 'none'
          _isConnected =
              results.any((result) => result != ConnectivityResult.none);

          // Show banner when connection is lost
          if (wasConnected && !_isConnected) {
            _showConnectivityBanner = true;
          }
          // Hide banner when connection is restored and auto-refresh
          else if (!wasConnected && _isConnected) {
            _showConnectivityBanner = false;
            _refreshPosts(); // Auto-refresh when connection is restored
          }
        });
      }
    });
  }

  // Combined fetch method for user details and weather
  Future<void> _fetchUserDetailsAndWeather() async {
    // ADD THIS - Check connectivity before fetching
    if (!_isConnected) {
      print("⚠️ No internet connection. Skipping data fetch.");
      return;
    }

    await Future.wait([
      _fetchUserDetails(),
      _fetchWeatherData(),
    ]);
  }

  // ✅ Fetch Current User Details from Supabase
  Future<void> _fetchUserDetails() async {
    // ADD THIS - Early return if no internet
    if (!_isConnected) {
      if (_isMounted) {
        setState(() {
          username = "Offline";
          email = "No Connection";
        });
      }
      return;
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      // ✅ Check if the user is logged in anonymously
      if (user.email == null || user.email!.isEmpty) {
        if (_isMounted) {
          setState(() {
            username = "Guest";
            email = "No Email";
          });
        }
        return; // Exit early for anonymous users
      }

      // ✅ Fetch username & email for authenticated users
      final response = await Supabase.instance.client
          .from('profiles')
          .select('username, email')
          .eq('id', user.id)
          .single();

      if (response != null && _isMounted) {
        setState(() {
          username = response['username'] ?? "Unknown";
          email = response['email'] ?? "No Email";
        });
      }
    } catch (e) {
      print("❌ Error fetching user details: $e");
      if (_isMounted) {
        setState(() {
          username = "Error";
          email = "Failed to load";
        });
      }
    }
  }

  // Fetch current weather data
  Future<void> _fetchWeatherData() async {
    if (!_isMounted) return;

    // ADD THIS - Check connectivity before fetching weather
    if (!_isConnected) {
      setState(() {
        currentTemperature = "Offline";
        weatherIcon = "📡";
        isLoadingWeather = false;
      });
      return;
    }

    setState(() {
      isLoadingWeather = true;
    });

    try {
      // Fetch current conditions for Tigatto, Davao City
      final response = await http.get(Uri.parse(
          'http://dataservice.accuweather.com/currentconditions/v1/$locationKey?apikey=$apiKey&details=true'));

      if (response.statusCode == 200 && _isMounted) {
        final data = json.decode(response.body);
        if (data.isNotEmpty) {
          setState(() {
            // Extract temperature and format to one decimal place
            currentTemperature =
                '${data[0]['Temperature']['Metric']['Value'].toStringAsFixed(1)}°C';

            // Set weather icon based on AccuWeather icon code
            weatherIcon = _getWeatherIcon(data[0]['WeatherIcon']);
            isLoadingWeather = false;
          });
        }
      } else {
        setState(() {
          currentTemperature = "--°C";
          isLoadingWeather = false;
        });
        print("❌ Error fetching weather: ${response.statusCode}");
      }
    } catch (e) {
      if (_isMounted) {
        setState(() {
          currentTemperature = "--°C";
          isLoadingWeather = false;
        });
      }
      print("❌ Exception fetching weather: $e");
    }
  }

  // Convert AccuWeather icon code to emoji
  String _getWeatherIcon(int weatherCode) {
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

  @override
  void dispose() {
    _isMounted = false; // ✅ Mark as unmounted
    super.dispose();
  }

  @override
  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(
              username ?? "Unknown",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            accountEmail: Text(
              email ?? "No Email",
              style: TextStyle(fontSize: 16),
            ),

            // Weather display next to the profile image
            otherAccountsPictures: [
              CircleAvatar(
                backgroundColor: Colors.white.withOpacity(0.3),
                child: isLoadingWeather
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.black,
                          strokeWidth: 2,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            weatherIcon,
                            style: TextStyle(fontSize: 15),
                          ),
                        ],
                      ),
              ),
              // Add separate CircleAvatar for temperature
              CircleAvatar(
                backgroundColor: Colors.white.withOpacity(0.3),
                child: isLoadingWeather
                    ? SizedBox(width: 1)
                    : Text(
                        currentTemperature.replaceAll('°C', '°'),
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
              ),
            ],
          ),

          /*ListTile(
            leading: Icon(Icons.wb_cloudy),
            title: Text('Weather'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => WeatherCheckPage(),
                ),
              );
            },
          ),*/
          ListTile(
            leading: Icon(Icons.local_drink),
            title: Text('River Basin Status'),
            onTap: () {
              // ADD THIS - Check connectivity before navigation
              if (!_isConnected) {
                _showNoInternetDialog();
                return;
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RiverBasinPage(),
                ),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.phone_in_talk),
            title: Text('Emergency Hotlines'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EmergencyHotlinesPage(),
                ),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.settings),
            title: Text('Profile Settings'),
            onTap: () {
              // ADD THIS - Check connectivity before navigation
              if (!_isConnected) {
                _showNoInternetDialog();
                return;
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MyProfilePage(),
                ),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.map_rounded),
            title: Text('Jade Valley Area Map'),
            onTap: () {
              // ADD THIS - Check connectivity before navigation
              if (!_isConnected) {
                _showNoInternetDialog();
                return;
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MapPage(),
                ),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.inbox),
            title: Text('Inbox'),
            onTap: () {
              // ADD THIS - Check connectivity before navigation
              if (!_isConnected) {
                _showNoInternetDialog();
                return;
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => InboxPage(),
                ),
              );
            },
          ),
          Divider(
            color: Colors.grey,
            height: 1,
          ),
          ListTile(
            leading: Icon(Icons.bug_report),
            title: Text('Bug Reports & Feedback'),
            onTap: () {
              // ADD THIS - Check connectivity before navigation
              if (!_isConnected) {
                _showNoInternetDialog();
                return;
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FeedbackBugReportsPage(),
                ),
              );
            },
            trailing: Icon(Icons.feedback),
          ),
          ListTile(
            leading: Icon(Icons.exit_to_app),
            title: Text('Logout'),
            onTap: () {
              if (!_isConnected) {
                _showNoInternetToLogout();
                return;
              } else {
                _signOut();
              }
            },
          ),
        ],
      ),
    );
  }

  // ADD THIS METHOD - Show no internet dialog
  void _showNoInternetDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.wifi_off, color: Colors.red),
              SizedBox(width: 8),
              Text('No Internet Connection'),
            ],
          ),
          content: Text(
              'This feature requires an internet connection. Please check your network settings and try again.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showNoInternetToLogout() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.wifi_off, color: Colors.red),
              SizedBox(width: 8),
              Text('No Internet Connection'),
            ],
          ),
          content:
              Text('Connect to the internet first to log out this session.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPostCreateSection() {
    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: () {
            // ADD THIS - Check connectivity before creating post
            if (!_isConnected) {
              _showNoInternetDialog();
              return;
            }
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CreatePostScreen(),
              ),
            );
          },
          icon: Icon(Icons.photo, color: Colors.black),
          label: Text(
            'Create a Post',
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Colors.black,
            ),
          ),
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.black,
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            side: BorderSide(color: Colors.black),
          ),
        ),
      ],
    );
  }

  Future<void> _signOut() async {
    final currentContext = context;
    await Supabase.instance.client.auth.signOut();

    if (currentContext.mounted) {
      Navigator.pushAndRemoveUntil(
        currentContext,
        MaterialPageRoute(
          builder: (context) => const SplashScreen(),
        ),
        (route) => false, // This removes all previous routes
      );
    }
  }

  Future<void> _refreshPosts() async {
    setState(() {
      _refreshFuture = _fetchUserDetailsAndWeather();
    });
  }

  // ADD THIS METHOD - Build connectivity banner
  Widget _buildConnectivityBanner() {
    if (!_showConnectivityBanner) return SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.red.shade600,
      child: Row(
        children: [
          Icon(Icons.wifi_off, color: Colors.white, size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'No internet connection. Some features may not work.',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _showConnectivityBanner = false;
              });
            },
            child: Text('Dismiss', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text('News Feed'),
        // Add weather display in app bar for quick view
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: isLoadingWeather
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Row(
                      children: [
                        Text(
                          weatherIcon,
                          style: TextStyle(fontSize: 20),
                        ),
                        SizedBox(width: 4),
                        Text(
                          currentTemperature,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          // Add tap functionality to open weather page
          IconButton(
            icon: Icon(Icons.arrow_forward_ios, size: 16),
            onPressed: () {
              // ADD THIS - Check connectivity before navigation
              if (!_isConnected) {
                _showNoInternetDialog();
                return;
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => WeatherCheckPage(),
                ),
              );
            },
          ),
        ],
      ),
      drawer: _buildDrawer(context),
      body: Column(
        children: [
          _buildConnectivityBanner(), // ADD THIS - Show connectivity banner
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshPosts, // Call the refresh function
              child: FutureBuilder(
                future: _refreshFuture, // Ensure data is loaded
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }
                  return ListView(
                    children: [
                      _buildPostCreateSection(),
                      PostList(),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EmergencyHotlinesPage(),
            ),
          );
        },
        tooltip: 'Call Emergency Hotline',
        backgroundColor: Colors.red,
        child: Icon(Icons.phone),
      ),
    );
  }
}
