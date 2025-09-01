import 'dart:collection';
import 'dart:async';
import 'dart:math';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:permission_handler/permission_handler.dart';

import 'package:gismultiinstancetestingenvironment/pages/profilepage.dart';
import 'package:gismultiinstancetestingenvironment/pages/splashsrc.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'firebase_options.dart';
import 'package:gismultiinstancetestingenvironment/pages/emerg.dart';
import 'package:gismultiinstancetestingenvironment/pages/inbox/inbox_page.dart';
import 'package:gismultiinstancetestingenvironment/pages/index.dart';
import 'package:gismultiinstancetestingenvironment/pages/newsfeed/newsfeed.dart';
import 'package:gismultiinstancetestingenvironment/pages/riverbasin.dart';

/// Supabase Credentials
String SupabaseUrl = dotenv.env['SUPABASE_URL']!;
String SupabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY']!;
String oneSignalAppID = dotenv.env['ONESIGNAL_APP_ID']!;

/// Firebase Local Notifications Plugin
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

/// GPS Tracking Variables
StreamSubscription<geo.Position>? positionStream;
Timer? floodCheckTimer;
List<FloodReport> activeFloodReports = [];

/// Flood Report Model
class FloodReport {
  final String id;
  final double latitude;
  final double longitude;
  final String title;
  final String description;
  final String status;
  final String address;
  final DateTime createdOn;

  FloodReport({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.title,
    required this.description,
    required this.status,
    required this.address,
    required this.createdOn,
  });

  factory FloodReport.fromJson(Map<String, dynamic> json) {
    try {
      print('🔍 Parsing flood report: ${json['floodreport_id']}');
      print('📍 Raw coordinates: ${json['address_coordinates']}');

      // Parse coordinates from PostGIS point format
      String coordinates = json['address_coordinates'].toString();
      double lat = 0.0;
      double lng = 0.0;

      if (coordinates.contains('POINT(')) {
        // Handle POINT(lng lat) format
        coordinates = coordinates.replaceAll('POINT(', '').replaceAll(')', '');
        List<String> coords = coordinates.split(' ');
        if (coords.length >= 2) {
          lng = double.parse(coords[0]); // Longitude is first
          lat = double.parse(coords[1]); // Latitude is second
        }
      } else if (coordinates.contains(',')) {
        // Handle comma-separated format like "lat,lng" or "lng,lat"
        List<String> coords = coordinates.split(',');
        if (coords.length >= 2) {
          // Try to determine which is lat/lng based on typical ranges
          double first = double.parse(coords[0].trim());
          double second = double.parse(coords[1].trim());

          // Philippines is roughly 4-21°N, 116-127°E
          // If first number is in lat range (4-21), assume lat,lng format
          if (first >= 4 && first <= 21) {
            lat = first;
            lng = second;
          } else {
            lng = first;
            lat = second;
          }
        }
      } else {
        // Try to parse as space-separated
        List<String> coords = coordinates.split(' ');
        if (coords.length >= 2) {
          lng = double.parse(coords[0]);
          lat = double.parse(coords[1]);
        }
      }

      print('✅ Parsed coordinates: lat=$lat, lng=$lng');

      return FloodReport(
        id: json['floodreport_id'],
        latitude: lat,
        longitude: lng,
        title: json['floodreport_title'] ?? 'Flood Report',
        description: json['floodreport_description'] ?? '',
        status: json['flood_status'] ?? '',
        address: json['location_address'] ?? '',
        createdOn: DateTime.parse(json['created_on']),
      );
    } catch (e, stackTrace) {
      print('❌ Error parsing flood report: $e');
      print('📊 Raw data: $json');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // ✅ Load Environment Variables
  await dotenv.load(fileName: 'assets/.env');

  // ✅ Initialize Supabase
  await Supabase.initialize(
    url: SupabaseUrl,
    anonKey: SupabaseAnonKey,
    authOptions: FlutterAuthClientOptions(authFlowType: AuthFlowType.pkce),
  );

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  print("✅ Supabase initialized, checking session...");
  final supabase = Supabase.instance.client;

  final session = supabase.auth.currentSession;
  if (session == null) {
    print("⚠️ No active session found. User might need to log in.");
  } else {
    print("✅ Active session found! User is authenticated.");
  }

  try {
    print("🚀 Initializing OneSignal...");
    OneSignal.initialize(oneSignalAppID);
    print("✅ OneSignal initialized successfully! ID: $oneSignalAppID. ");
    OneSignal.Notifications.requestPermission(true);
    print("🔔 OneSignal push notification permission requested.");
  } catch (e, stackTrace) {
    print("❌ OneSignal initialization failed: $e");
    print(stackTrace);
  }

  setupOneSignalListeners();
  storeOneSignalPlayerID();
  await setupMapBox();

  // ✅ Setup Local Notifications (Required for flood warnings)
  await setupLocalNotifications();

  // ✅ Setup Location Permissions and GPS Tracking
  await setupLocationServices();

  runApp(const MyApp());
}

/// ✅ Setup Location Services and Start GPS Tracking
Future<void> setupLocationServices() async {
  try {
    // Request location permissions
    geo.LocationPermission permission = await geo.Geolocator.checkPermission();
    if (permission == geo.LocationPermission.denied) {
      permission = await geo.Geolocator.requestPermission();
      if (permission == geo.LocationPermission.denied) {
        print('❌ Location permissions are denied');
        return;
      }
    }

    if (permission == geo.LocationPermission.deniedForever) {
      print('❌ Location permissions are permanently denied');
      return;
    }

    print('✅ Location permission granted');

    // Start GPS tracking
    startGPSTracking();

    // Start periodic flood report fetching
    startFloodReportFetching();
  } catch (e) {
    print('❌ Error setting up location services: $e');
  }
}

/// ✅ Start GPS Tracking
void startGPSTracking() {
  const geo.LocationSettings locationSettings = geo.LocationSettings(
    accuracy: geo.LocationAccuracy.high,
    distanceFilter: 10, // Update every 10 meters
  );

  positionStream = geo.Geolocator.getPositionStream(
    locationSettings: locationSettings,
  ).listen((geo.Position position) {
    print('📍 GPS Update: ${position.latitude}, ${position.longitude}');
    checkFloodProximity(position);
  });

  print('🌍 GPS tracking started');
}

/// ✅ Fetch Active Flood Reports from Supabase
Future<void> fetchActiveFloodReports() async {
  try {
    final supabase = Supabase.instance.client;

    // Calculate 6 hours ago in UTC
    final DateTime sixHoursAgo =
        DateTime.now().toUtc().subtract(Duration(hours: 6));
    print(
        '🕐 Fetching flood reports created after: ${sixHoursAgo.toIso8601String()}');

    final response = await supabase
        .from('reportfloodsituations')
        .select(
            'floodreport_id, floodreport_title, floodreport_description, location_address, address_coordinates, flood_status, created_on')
        .eq('flood_reportstatus', 'granted')
        .inFilter('flood_status', ['rising water', 'impassable', 'flood surge'])
        .gte('created_on', sixHoursAgo.toIso8601String())
        .not('address_coordinates', 'is', null);

    print('📊 Raw Supabase response type: ${response.runtimeType}');
    print('📊 Raw Supabase response: $response');

    if (response != null && response is List) {
      List<FloodReport> validReports = [];

      for (var item in response) {
        try {
          FloodReport report = FloodReport.fromJson(item);
          // Only add reports with valid coordinates
          if (report.latitude != 0.0 && report.longitude != 0.0) {
            validReports.add(report);
          } else {
            print(
                '⚠️ Skipping report with invalid coordinates: ${report.title}');
          }
        } catch (e) {
          print('⚠️ Skipping invalid flood report: $e');
          continue;
        }
      }

      activeFloodReports = validReports;

      print(
          '✅ Fetched ${activeFloodReports.length} valid active flood reports');

      // Debug: Print each flood report
      for (var report in activeFloodReports) {
        print(
            '🌊 Flood Report: ${report.title} at (${report.latitude}, ${report.longitude}) - Status: ${report.status}');
      }
    } else {
      print('⚠️ No flood reports found or response is not a list');
    }
  } catch (e, stackTrace) {
    print('❌ Error fetching flood reports: $e');
    print('Stack trace: $stackTrace');
  }
}

/// ✅ Start Periodic Flood Report Fetching
void startFloodReportFetching() {
  // Fetch immediately
  fetchActiveFloodReports();

  // Then fetch every 2 minutes
  floodCheckTimer = Timer.periodic(Duration(minutes: 2), (timer) {
    fetchActiveFloodReports();
  });

  print('📊 Flood report fetching started');
}

/// ✅ Check if User is Near Any Flood Location
void checkFloodProximity(geo.Position currentPosition) {
  print(
      '📍 Current Position: ${currentPosition.latitude}, ${currentPosition.longitude}');
  print('🔍 Checking ${activeFloodReports.length} flood reports...');

  for (FloodReport floodReport in activeFloodReports) {
    double distance = geo.Geolocator.distanceBetween(
      currentPosition.latitude,
      currentPosition.longitude,
      floodReport.latitude,
      floodReport.longitude,
    );

    print('📊 Distance to ${floodReport.title}: ${distance.round()}m');

    // If within 70 meters, show warning
    if (distance <= 70) {
      print('🚨 FLOOD WARNING TRIGGERED! Distance: ${distance.round()}m');
      showFloodWarningNotification(floodReport, distance);
    }
  }
}

/// ✅ Show Flood Warning Notification
void showFloodWarningNotification(
    FloodReport floodReport, double distance) async {
  print('🚨 Attempting to show flood warning notification...');

  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'flood_warning_channel',
    'Flood Warnings',
    channelDescription: 'Notifications for nearby flood reports',
    importance: Importance.max,
    priority: Priority.high,
    playSound: true,
    enableVibration: true,
    icon: '@mipmap/ic_launcher',
    color: Colors.red,
    styleInformation: BigTextStyleInformation(''),
    ticker: 'Flood Warning',
  );

  const NotificationDetails platformDetails =
      NotificationDetails(android: androidDetails);

  String title = '⚠️ FLOOD WARNING';
  String body =
      'Flood reported ${distance.round()}m away: ${floodReport.title}\n'
      'Status: ${floodReport.status.toUpperCase()}\n'
      'Location: ${floodReport.address}';

  print('📱 Notification Title: $title');
  print('📱 Notification Body: $body');

  try {
    await flutterLocalNotificationsPlugin.show(
      floodReport.id.hashCode, // Unique ID based on flood report
      title,
      body,
      platformDetails,
    );

    print('✅ Notification sent successfully');
  } catch (e, stackTrace) {
    print('❌ Failed to show notification: $e');
    print('Stack trace: $stackTrace');
  }

  print(
      '🚨 Flood warning sent: ${floodReport.title} - ${distance.round()}m away');
}

/// ✅ Stop GPS Tracking (call when app is disposed)
void stopGPSTracking() {
  positionStream?.cancel();
  floodCheckTimer?.cancel();
  print('🛑 GPS tracking stopped');
}

Future<void> storeOneSignalPlayerID() async {
  final String? playerID = OneSignal.User.pushSubscription.id;

  if (playerID != null) {
    print('🔑 OneSignal Player ID: $playerID');

    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      await Supabase.instance.client
          .from('profiles')
          .update({'onesignal_player_id': playerID}).eq('id', user.id);
      print('✅ OneSignal Player ID stored in Supabase');
    } else {
      print('⚠️ No authenticated user found');
    }
  } else {
    print('❌ Failed to retrieve OneSignal Player ID');
  }
}

void _navigateToPage(String page) {
  if (page == "inbox") {
    Navigator.push(
      MyApp.navigatorKey.currentContext!,
      MaterialPageRoute(builder: (context) => InboxPage()),
    );
  } else if (page == "newsfeed") {
    Navigator.push(
      MyApp.navigatorKey.currentContext!,
      MaterialPageRoute(builder: (context) => InboxPage()),
    );
  }
}

void setupOneSignalListeners() {
  OneSignal.Notifications.addForegroundWillDisplayListener((event) {
    print("📩 Foreground Notification: ${event.notification.title}");
  });

  OneSignal.Notifications.addClickListener((event) {
    print("🔔 Notification Clicked: ${event.notification.additionalData}");

    Map<String, dynamic>? data = event.notification.additionalData;
    if (data != null && data.containsKey('navigate')) {
      String page = data['navigate'];
      _navigateToPage(page);
    }
  });

  OneSignal.Notifications.addPermissionObserver((state) {
    print("🔔 Notification permission state: $state");
  });

  OneSignal.User.pushSubscription.addObserver((state) {
    print(
        "📩 OneSignal Subscription State Changed: ${state.jsonRepresentation()}");
  });
}

class MyApp extends StatelessWidget {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
    );
  }
}

Future<void> callEdgeFunction() async {
  final supabase = Supabase.instance.client;

  try {
    final response = await supabase.functions.invoke(
      'new-alert',
      body: {
        'record': {
          'message_title': 'message_title',
          'message': 'message',
          'warning_gauge_lvl': 'warning_gauge_lvl',
        },
      },
    );

    print('✅ Edge Function Response: ${response.data}');
  } catch (error) {
    print('❌ Error calling Edge Function: $error');
  }
}

/// ✅ Setup Local Notifications (Enhanced for flood warnings)
Future<void> setupLocalNotifications() async {
  print('🔔 Setting up local notifications...');

  const AndroidInitializationSettings androidInitSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initSettings = InitializationSettings(
    android: androidInitSettings,
  );

  bool? initialized = await flutterLocalNotificationsPlugin.initialize(
    initSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      print('Notification tapped: ${response.payload}');
    },
  );

  print('🔔 Local notifications initialized: $initialized');

  // Create notification channel for flood warnings
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'flood_warning_channel',
    'Flood Warnings',
    description: 'Notifications for nearby flood reports',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
      flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  if (androidImplementation != null) {
    await androidImplementation.createNotificationChannel(channel);
    print('✅ Notification channel created successfully');

    // Test notification to verify setup
    await testNotification();
  } else {
    print('❌ Failed to get Android notification implementation');
  }

  print('✅ Local notifications initialized with flood warning channel');
}

/// Test notification to verify setup
Future<void> testNotification() async {
  print('🧪 Sending test notification...');

  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'flood_warning_channel',
    'Flood Warnings',
    channelDescription: 'Notifications for nearby flood reports',
    importance: Importance.max,
    priority: Priority.high,
    playSound: true,
    enableVibration: true,
    icon: '@mipmap/ic_launcher',
    color: Colors.blue,
    ticker: 'Test Notification',
  );

  const NotificationDetails platformDetails =
      NotificationDetails(android: androidDetails);

  try {
    await flutterLocalNotificationsPlugin.show(
      999, // Test notification ID
      '🧪 Test Notification',
      'Local notifications are working correctly!',
      platformDetails,
    );
    print('✅ Test notification sent successfully');
  } catch (e) {
    print('❌ Test notification failed: $e');
  }
}

void _showLocalNotification(OSNotification notification) async {
  print("🔔 Showing notification: ${notification.title}");

  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'channel_id',
    'Emergency Alerts',
    importance: Importance.max,
    priority: Priority.high,
    playSound: true,
    icon: '@mipmap/ic_launcher',
    color: Colors.red,
  );

  const NotificationDetails platformDetails =
      NotificationDetails(android: androidDetails);

  if (notification.title != null && notification.body != null) {
    await flutterLocalNotificationsPlugin.show(
      0,
      notification.title,
      notification.body,
      platformDetails,
    );
  }
}

/// ✅ Setup Mapbox Access Token
Future<void> setupMapBox() async {
  try {
    await dotenv.load(fileName: 'assets/.env');

    if (dotenv.env['MAPBOX_ACCESS_TOKEN'] != null &&
        dotenv.env['MAPBOX_ACCESS_TOKEN']!.isNotEmpty) {
      print('✅ .env Loaded Successfully');
      MapboxOptions.setAccessToken(dotenv.env['MAPBOX_ACCESS_TOKEN']!);
    } else {
      print('❌ Mapbox Access Token not found!');
    }
  } catch (e) {
    print('❌ Error loading .env file: $e');
  }
}
