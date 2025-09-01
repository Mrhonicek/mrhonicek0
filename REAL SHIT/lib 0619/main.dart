import 'dart:collection';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:gismultiinstancetestingenvironment/pages/emergency_alert_screen.dart';

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

/// Global variable to store pending alert data
Map<String, String>? pendingAlertData;

/// Firebase Local Notifications Plugin
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();
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
    // await supabase.auth.refreshSession();

    final session = supabase.auth.currentSession;
    if (session == null) {
      print("⚠️ No active session found. User might need to log in.");
    } else {
      print("✅ Active session found! User is authenticated.");
    }

    try {
      print("🚀 Initializing OneSignal...");

      // ✅ Set OneSignal Debug Log Level
      //OneSignal.Debug.setLogLevel(OSLogLevel.verbose);

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

    // ✅ Call Edge Function
    // await callEdgeFunction();

    // ✅ Initialize Mapbox Maps (Requires Internet for token validation)
    await setupMapBox();

    // ✅ Setup Local Notifications (Offline - Safe, but keeping here for organization)
    //await setupLocalNotifications();

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
    // Make it case-insensitive
    case "inbox":
      Navigator.pushReplacement(
        MyApp.navigatorKey.currentContext!,
        MaterialPageRoute(builder: (context) => InboxPage()),
      );
      break;
    case "newsfeed":
      Navigator.pushReplacement(
        MyApp.navigatorKey.currentContext!,
        MaterialPageRoute(builder: (context) => NewsFeed()),
      );
      break;
    default:
      print("⚠️ Unknown page: $page, defaulting to inbox");
      // Default to inbox instead of newsfeed for notifications
      Navigator.pushReplacement(
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
    barrierDismissible: false, // Prevents dismissing by tapping outside
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
              Navigator.of(context).pop(); // Close the alert
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
  OneSignal.Notifications.addClickListener((event) async {
    // Wait for app to be ready if needed
    print("🔔 Notification Clicked: ${event.notification.additionalData}");
    await Future.delayed(const Duration(milliseconds: 500));

    final title = event.notification.title ?? "Emergency Alert";
    final message =
        event.notification.body ?? "Emergency notification received";
    final data = event.notification.additionalData ?? {};
    final warningGauge = data['warning_gauge_lvl'] ?? 'unknown';

    // Store alert data globally for when app becomes active
    pendingAlertData = {
      'title': title,
      'message': message,
      'warning_gauge_lvl': warningGauge,
    };
    print("📱 Stored pending alert data: $title - $message");

    // Try to show alert immediately (if app is already active)
    if (MyApp.navigatorKey.currentContext != null) {
      _showEmergencyAlert(title, message, warningGauge);
      _showFullScreenAlert(title, message, warningGauge);
      pendingAlertData = null; // Clear since we showed it
    }

    // Handle navigation

    // Check if there's navigation data in the notification
    if (data != null && data.containsKey('navigate')) {
      final navigateTo = data['navigate'] as String?;
      print("🧭 Navigation data found: $navigateTo");
      if (navigateTo != null) {
        // Navigate after a short delay to let alert show first
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

  OneSignal.Notifications.addForegroundWillDisplayListener((event) {
    print("📩 Foreground Notification: ${event.notification.title}");

    // Show alert dialog immediately when app is in foreground
    final title = event.notification.title ?? "Emergency Alert";
    final message =
        event.notification.body ?? "Emergency notification received";
    final data = event.notification.additionalData ?? {};
    final warningGauge = data['warning_gauge_lvl'] ?? 'unknown';
    //_showEmergencyAlert(title, message);
    _showFullScreenAlert(title, message, warningGauge);
    // Prevent the default notification from showing since we're showing an alert
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

void checkAndShowPendingAlert() {
  if (pendingAlertData != null && MyApp.navigatorKey.currentContext != null) {
    print("📱 Showing pending alert: ${pendingAlertData!['title']}");

    // Show the alert dialog
    _showEmergencyAlert(pendingAlertData!['title']!,
        pendingAlertData!['message']!, pendingAlertData!['warning_gauge_lvl']!);

    // Clear the pending alert data
    pendingAlertData = null;
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
        warningGauge: warningGauge, // Placeholder
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
      // App came to foreground, check for pending alerts
      print("📱 App resumed, checking for pending alerts...");
      Future.delayed(const Duration(milliseconds: 500), () {
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

/// ✅ Setup Local Notifications
Future<void> setupLocalNotifications() async {
  const AndroidInitializationSettings androidInitSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initSettings = InitializationSettings(
    android: androidInitSettings,
  );

  await flutterLocalNotificationsPlugin.initialize(initSettings);
}

void _showLocalNotification(OSNotification notification) async {
  print("🔔 Showing notification: ${notification.title}");

  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'channel_id',
    'Emergency Alerts',
    importance: Importance.max,
    priority: Priority.high,
    playSound: true,
    icon: '@mipmap/ic_launcher', // Custom icon
    color: Colors.red, // Change notification color
  );

  const NotificationDetails platformDetails =
      NotificationDetails(android: androidDetails);

  if (notification.title != null &&
      notification.body != null &&
      platformDetails != null) {
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
    await dotenv.load(fileName: 'assets/.env'); // Ensure correct path

    if (dotenv.env['MAPBOX_ACCESS_TOKEN'] != null &&
        dotenv.env['MAPBOX_ACCESS_TOKEN']!.isNotEmpty) {
      print('✅ .env Loaded Successfully');
      // print('🔍 MAPBOX_ACCESS_TOKEN: ${dotenv.env['MAPBOX_ACCESS_TOKEN']}');
      MapboxOptions.setAccessToken(dotenv.env['MAPBOX_ACCESS_TOKEN']!);
    } else {
      print('❌ Mapbox Access Token not found!');
    }
  } catch (e) {
    print('❌ Error loading .env file: $e');
  }
}
