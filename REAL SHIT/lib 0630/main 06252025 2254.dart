import 'dart:collection';
import 'dart:convert';
import 'dart:isolate';
import 'dart:ui';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:gismultiinstancetestingenvironment/pages/emergency_alert_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

void _logSoundDebug(String message) {
  final timestamp = DateTime.now().toIso8601String();
  print("🔊 [$timestamp] SOUND DEBUG: $message");
}

/// Supabase Credentials
String SupabaseUrl = dotenv.env['SUPABASE_URL']!;
String SupabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY']!;
String oneSignalAppID = dotenv.env['ONESIGNAL_APP_ID']!;

/// Global variable to store pending alert data
Map<String, String>? pendingAlertData;

/// Firebase Local Notifications Plugin
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

/// OneSignal doesn't have a traditional background handler like Firebase
/// Instead, we handle notifications through the foreground listener and click listener
/// The system will show notifications when app is in background automatically

/// Store emergency alert data in SharedPreferences for persistence
Future<void> _storeEmergencyAlert(String title, String message,
    String warningGauge, Map<String, dynamic> data) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final alertData = {
      'title': title,
      'message': message,
      'warning_gauge_lvl': warningGauge,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'navigate': data['navigate'] ?? 'inbox',
      'shown': false,
    };

    await prefs.setString('pending_emergency_alert', jsonEncode(alertData));
    print("💾 Emergency alert stored in SharedPreferences");
  } catch (e) {
    print("❌ Failed to store emergency alert: $e");
  }
}

/// Static version for background isolate
Future<void> _storeEmergencyAlertStatic(String title, String message,
    String warningGauge, Map<String, dynamic> data) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final alertData = {
      'title': title,
      'message': message,
      'warning_gauge_lvl': warningGauge,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'navigate': data['navigate'] ?? 'inbox',
      'shown': false,
    };

    await prefs.setString('pending_emergency_alert', jsonEncode(alertData));
    print("💾 BACKGROUND: Emergency alert stored in SharedPreferences");
  } catch (e) {
    print("❌ BACKGROUND: Failed to store emergency alert: $e");
  }
}

/// Show critical local notification that will appear even when app is closed
Future<void> _showCriticalLocalNotification(
    String title, String message, String warningGauge) async {
  try {
    _logSoundDebug("Preparing to show critical notification with sound");

    // Create high-priority notification
    AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'emergency_channel',
      'Emergency Alerts',
      channelDescription: 'Critical emergency notifications',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound(
          'alarm_siren'), // Add this line
      enableVibration: true,
      enableLights: true,
      color: Colors.red,
      icon: '@mipmap/ic_notification',
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: true, // This makes it show as full-screen
      autoCancel: true, // Don't auto-dismiss
      ongoing: true, // Make it persistent
      ticker: 'EMERGENCY ALERT',
      styleInformation: BigTextStyleInformation(
        message,
        htmlFormatBigText: true,
        contentTitle: title,
        htmlFormatContentTitle: true,
        summaryText: 'Emergency Alert',
        htmlFormatSummaryText: true,
      ),
    );

    NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
    );

    await flutterLocalNotificationsPlugin.show(
      999, // Use high ID for emergency alerts
      title,
      message,
      platformDetails,
      payload: jsonEncode({
        'type': 'emergency',
        'title': title,
        'message': message,
        'warning_gauge_lvl': warningGauge,
      }),
    );

    print("🚨 Critical local notification shown");
  } catch (e) {
    print("❌ Failed to show critical notification: $e");
  }
}

/// Static version for background isolate
Future<void> _showCriticalLocalNotificationStatic(
    String title, String message, String warningGauge) async {
  _logSoundDebug("BACKGROUND: Preparing notification with sound");

  try {
    // Create a new instance for background isolate
    final FlutterLocalNotificationsPlugin localPlugin =
        FlutterLocalNotificationsPlugin();

    // Initialize for background use
    const AndroidInitializationSettings androidInitSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings =
        InitializationSettings(android: androidInitSettings);
    await localPlugin.initialize(initSettings);

    // Create high-priority notification
    AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'emergency_channel',
      'Emergency Alerts',
      channelDescription: 'Critical emergency notifications',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound(
          'alarm_siren'), // Add this line
      enableVibration: true,
      enableLights: true,
      color: Colors.white,
      icon: 'ic_notification',
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: true,
      autoCancel: true,
      ongoing: true,
      ticker: 'EMERGENCY ALERT',
      styleInformation: BigTextStyleInformation(
        message,
        htmlFormatBigText: true,
        contentTitle: title,
        htmlFormatContentTitle: true,
        summaryText: 'Emergency Alert - Tap to view',
        htmlFormatSummaryText: true,
      ),
    );

    NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
    );

    await localPlugin.show(
      999, // Use high ID for emergency alerts
      title,
      message,
      platformDetails,
      payload: jsonEncode({
        'type': 'emergency',
        'title': title,
        'message': message,
        'warning_gauge_lvl': warningGauge,
      }),
    );

    print("🚨 BACKGROUND: Critical local notification shown");
  } catch (e) {
    print("❌ BACKGROUND: Failed to show critical notification: $e");
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // ✅ Load Environment Variables (Offline - Safe)
  await dotenv.load(fileName: 'assets/.env');

  // ✅ Initialize Supabase (Basic client setup - Safe without internet)
  await Supabase.initialize(
    url: SupabaseUrl,
    anonKey: SupabaseAnonKey,
    authOptions: FlutterAuthClientOptions(authFlowType: AuthFlowType.pkce),
  );
  print("✅ Supabase client initialized (offline mode)");

  // ✅ Setup Local Notifications early
  await setupLocalNotifications();

  // ✅ Start App (Splash screen will handle internet-dependent initialization)
  runApp(const MyApp());
}

/// ✅ Internet-Dependent Initialization (Called from Splash Screen after connectivity check)
Future<void> initializeOnlineServices() async {
  try {
    // Initialize Firebase (Requires Internet)
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print("✅ Firebase initialized successfully");

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

      // ✅ Initialize OneSignal (Requires Internet)
      OneSignal.initialize(oneSignalAppID);
      print("✅ OneSignal initialized successfully! ID: $oneSignalAppID. ");

      // ✅ Request OneSignal Push Notification Permission
      OneSignal.Notifications.requestPermission(true);
      print("🔔 OneSignal push notification permission requested.");
    } catch (e, stackTrace) {
      print("❌ OneSignal initialization failed: $e");
      print(stackTrace);
    }

    // ✅ Store OneSignal Player ID in Supabase (Requires Internet)
    setupOneSignalListeners();
    storeOneSignalPlayerID();

    // ✅ Initialize Mapbox Maps (Requires Internet for token validation)
    await setupMapBox();

    print("✅ All online services initialized successfully");
  } catch (e, stackTrace) {
    print("❌ Error initializing online services: $e");
    print(stackTrace);
    throw Exception("Failed to initialize online services: $e");
  }
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
  // Ensure we have a valid context and navigator state
  if (MyApp.navigatorKey.currentContext == null) {
    print("❌ Navigator context is null");
    return;
  }

  print("🧭 Navigating to page: $page");

  // Close any open dialogs or modals
  Navigator.of(MyApp.navigatorKey.currentContext!, rootNavigator: true)
      .popUntil((route) => route.isFirst);

  // Navigate to the appropriate page
  switch (page.toLowerCase()) {
    case "inbox":
      Navigator.push(
        MyApp.navigatorKey.currentContext!,
        MaterialPageRoute(builder: (context) => InboxPage()),
      );
      break;
    case "newsfeed":
      Navigator.push(
        MyApp.navigatorKey.currentContext!,
        MaterialPageRoute(builder: (context) => NewsFeed()),
      );
      break;
    default:
      print("⚠️ Unknown page: $page, defaulting to inbox");
      Navigator.push(
        MyApp.navigatorKey.currentContext!,
        MaterialPageRoute(builder: (context) => InboxPage()),
      );
  }
}

void _showEmergencyAlert(String title, String message, String warningGauge) {
  if (MyApp.navigatorKey.currentContext == null) {
    print("❌ Navigator context is null, cannot show alert");
    return;
  }

  showDialog(
    context: MyApp.navigatorKey.currentContext!,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.red,
            fontSize: 18,
          ),
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text(
              'OK',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      );
    },
  );
}

void setupOneSignalListeners() {
  // Handle notification clicks (when user taps notification from system tray)
  OneSignal.Notifications.addClickListener((event) async {
    print(
        "🔔 Notification Clicked (from background/closed): ${event.notification.additionalData}");
    _logSoundDebug("Notification clicked - should trigger sound");
    await Future.delayed(const Duration(milliseconds: 500));

    final title = event.notification.title ?? "Emergency Alert";
    final message =
        event.notification.body ?? "Emergency notification received";
    final data = event.notification.additionalData ?? {};
    final warningGauge = data['warning_gauge_lvl'] ?? 'unknown';

    // Store alert data for persistence
    await _storeEmergencyAlert(title, message, warningGauge, data);

    // Store alert data globally for when app becomes active
    pendingAlertData = {
      'title': title,
      'message': message,
      'warning_gauge_lvl': warningGauge,
    };
    print("📱 Stored pending alert data: $title - $message");

    // Try to show alert immediately (if app is already active)
    if (MyApp.navigatorKey.currentContext != null) {
      //_showEmergencyAlert(title, message, warningGauge);
      _showFullScreenAlert(title, message, warningGauge);
      pendingAlertData = null;
    }

    // Handle navigation
    if (data.containsKey('navigate')) {
      final navigateTo = data['navigate'] as String?;
      print("🧭 Navigation data found: $navigateTo");
      if (navigateTo != null) {
        await Future.delayed(const Duration(milliseconds: 100));
        _navigateToPage(navigateTo);
      } else {
        await Future.delayed(const Duration(milliseconds: 100));
        _navigateToPage('inbox');
      }
    } else {
      print("🧭 No navigation data found, defaulting to inbox");
      await Future.delayed(const Duration(milliseconds: 100));
      _navigateToPage('inbox');
    }
  });

  // Handle notifications when app is in foreground
  OneSignal.Notifications.addForegroundWillDisplayListener((event) {
    _logSoundDebug("Foreground notification received - preparing sound");
    print("📩 Foreground Notification: ${event.notification.title}");

    final title = event.notification.title ?? "Emergency Alert";
    final message =
        event.notification.body ?? "Emergency notification received";
    final data = event.notification.additionalData ?? {};
    final warningGauge = data['warning_gauge_lvl'] ?? 'unknown';

    // Show in-app alerts immediately
    //_showEmergencyAlert(title, message, warningGauge);
    _storeEmergencyAlert(title, message, warningGauge, data);
    _showFullScreenAlert(title, message, warningGauge);

    // Store it for persistence

    // Show a local notification as backup (will appear in notification tray)
    _showCriticalLocalNotification(title, message, warningGauge);

    // Prevent OneSignal from showing its default notification
    event.preventDefault();
  });

  OneSignal.Notifications.addPermissionObserver((state) {
    print("🔔 Notification permission state: $state");
  });

  OneSignal.User.pushSubscription.addObserver((state) {
    print(
        "📩 OneSignal Subscription State Changed: ${state.jsonRepresentation()}");
  });
}

/// Enhanced function to check for stored emergency alerts
Future<void> checkAndShowPendingAlert() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final alertDataString = prefs.getString('pending_emergency_alert');

    if (alertDataString != null) {
      final alertData = jsonDecode(alertDataString) as Map<String, dynamic>;
      final hasShown = alertData['shown'] as bool? ?? false;

      if (!hasShown && MyApp.navigatorKey.currentContext != null) {
        print("📱 Showing stored emergency alert: ${alertData['title']}");

        // Mark as shown
        alertData['shown'] = true;
        await prefs.setString('pending_emergency_alert', jsonEncode(alertData));

        // Show the alerts
        _showEmergencyAlert(
          alertData['title'] as String,
          alertData['message'] as String,
          alertData['warning_gauge_lvl'] as String,
        );

        _showFullScreenAlert(
          alertData['title'] as String,
          alertData['message'] as String,
          alertData['warning_gauge_lvl'] as String,
        );

        // Navigate if needed
        final navigateTo = alertData['navigate'] as String? ?? 'inbox';
        await Future.delayed(const Duration(milliseconds: 2000));
        _navigateToPage(navigateTo);

        // Clear after showing
        await Future.delayed(const Duration(seconds: 10));
        await prefs.remove('pending_emergency_alert');
      }
    }

    // Also check the in-memory pending data
    if (pendingAlertData != null && MyApp.navigatorKey.currentContext != null) {
      print(
          "📱 Showing in-memory pending alert: ${pendingAlertData!['title']}");

      _showEmergencyAlert(
        pendingAlertData!['title']!,
        pendingAlertData!['message']!,
        pendingAlertData!['warning_gauge_lvl']!,
      );

      pendingAlertData = null;
    }
  } catch (e) {
    print("❌ Error checking pending alerts: $e");
  }
}

void _showFullScreenAlert(String title, String message, String warningGauge) {
  if (MyApp.navigatorKey.currentContext == null) {
    print("❌ Navigator context is null");
    return;
  }

  Navigator.of(MyApp.navigatorKey.currentContext!).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (context) => EmergencyAlertScreen(
        title: title,
        message: message,
        warningGauge: warningGauge,
      ),
    ),
  );
}

class MyApp extends StatefulWidget {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Check for pending alerts when app starts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 2), () {
        checkAndShowPendingAlert();
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    print("📱 App lifecycle state changed: $state");

    if (state == AppLifecycleState.resumed) {
      print("📱 App resumed, checking for pending alerts...");
      Future.delayed(const Duration(milliseconds: 1000), () {
        checkAndShowPendingAlert();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: MyApp.navigatorKey,
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

/// ✅ Enhanced Local Notifications Setup
Future<void> setupLocalNotifications() async {
  _logSoundDebug("Initializing notification channel with sound");

  const AndroidInitializationSettings androidInitSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initSettings = InitializationSettings(
    android: androidInitSettings,
  );

  // Initialize with tap handler
  await flutterLocalNotificationsPlugin.initialize(
    initSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) async {
      print("🔔 Local notification tapped: ${response.payload}");

      if (response.payload != null) {
        try {
          final data = jsonDecode(response.payload!) as Map<String, dynamic>;
          if (data['type'] == 'emergency') {
            // Show emergency alert when local notification is tapped
            if (MyApp.navigatorKey.currentContext != null) {
              _showFullScreenAlert(
                data['title'] as String,
                data['message'] as String,
                data['warning_gauge_lvl'] as String,
              );
            }
          }
        } catch (e) {
          print("❌ Error handling notification tap: $e");
        }
      }
    },
  );

  // Create notification channel for emergency alerts
  const AndroidNotificationChannel emergencyChannel =
      AndroidNotificationChannel(
    'emergency_channel',
    'Emergency Alerts',
    description: 'Critical emergency notifications',
    importance: Importance.max,
    playSound: true,
    sound: RawResourceAndroidNotificationSound('alarm_siren'), // Add this
    enableVibration: true,
    enableLights: true,
  );

  final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
      flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  if (androidPlugin != null) {
    await androidPlugin.createNotificationChannel(emergencyChannel);
    _logSoundDebug("✅ Emergency channel created with sound");
    print("✅ Emergency notification channel created");
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
