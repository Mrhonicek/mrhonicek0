import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'package:gismultiinstancetestingenvironment/main.dart';
import 'package:gismultiinstancetestingenvironment/pages/emerg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:gismultiinstancetestingenvironment/pages/index.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _isLoading = true;
  String _statusMessage = 'Initializing...';

  @override
  void initState() {
    super.initState();
    _startSplashScreen();
  }

  /// ✅ Start Splash Screen Delay, then Initialize App
  void _startSplashScreen() {
    Future.delayed(const Duration(seconds: 3), () async {
      await _initializeApp();
    });
  }

  /// ✅ Initialize App: Check Internet + Initialize Online Services
  Future<void> _initializeApp() async {
    try {
      setState(() {
        _statusMessage = 'Checking internet connection...';
      });

      // ✅ Step 1: Check for Internet Connection
      if (!await _checkInternetConnection()) {
        setState(() {
          _isLoading = false;
        });
        _showNoInternetDialog();
        return;
      }

      setState(() {
        _statusMessage = 'Connecting to server...';
      });

      // ✅ Step 2: Initialize all online services (Firebase, OneSignal, etc.)
      await _initializeOnlineServices();

      setState(() {
        _statusMessage = 'Refreshing session...';
      });

      // ✅ Step 3: Refresh Supabase Session
      await _refreshSupabaseSession();

      setState(() {
        _statusMessage = 'Loading application...';
      });

      // ✅ Step 4: If everything is fine, navigate to main app
      if (mounted) {
// Check for pending alerts after initialization
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Future.delayed(const Duration(milliseconds: 800), () {
            checkAndShowPendingAlert();
          });
        });

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const Index()),
        );
      }
    } catch (e) {
      print("❌ Unexpected Error in Initialization: $e");
      setState(() {
        _isLoading = false;
      });
      _showNoInternetDialog(); // Ensure the dialog shows even if an error occurs
    }
  }

  /// ✅ Initialize Online Services (Firebase, OneSignal, Mapbox, etc.)
  Future<void> _initializeOnlineServices() async {
    try {
      // Call the global function from main.dart
      await initializeOnlineServices();
    } catch (e) {
      print("❌ Failed to initialize online services: $e");
      throw Exception("Online services initialization failed: $e");
    }
  }

  /// ✅ Enhanced Internet Connection Check (Multiple Methods)
  Future<bool> _checkInternetConnection() async {
    try {
      // Method 1: Check connectivity status
      final connectivityResult = await Connectivity().checkConnectivity();

      if (connectivityResult == ConnectivityResult.none) {
        print("❌ No network connection detected");
        return false;
      }

      // Method 2: Actually test internet connectivity by trying to reach a reliable server
      try {
        final result = await InternetAddress.lookup('google.com')
            .timeout(const Duration(seconds: 10));

        if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
          print("✅ Internet connection verified");
          return true;
        }
      } on SocketException catch (e) {
        print("❌ Socket Exception - No internet: $e");
        return false;
      } on TimeoutException catch (e) {
        print("❌ Timeout Exception - No internet: $e");
        return false;
      }

      // Method 3: Try alternative server if Google fails
      try {
        final result = await InternetAddress.lookup('cloudflare.com')
            .timeout(const Duration(seconds: 10));

        if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
          print("✅ Internet connection verified (via Cloudflare)");
          return true;
        }
      } on SocketException catch (e) {
        print("❌ Socket Exception - No internet (Cloudflare): $e");
        return false;
      } on TimeoutException catch (e) {
        print("❌ Timeout Exception - No internet (Cloudflare): $e");
        return false;
      }
    } catch (e) {
      print("❌ Error checking internet connection: $e");
      return false;
    }

    return false;
  }

  /// ✅ Refresh Supabase Session Safely
  Future<void> _refreshSupabaseSession() async {
    final supabase = Supabase.instance.client;
    final session = supabase.auth.currentSession;

    if (session == null) {
      print("❌ No active Supabase session. User needs to log in.");
      return;
    }

    try {
      await supabase.auth.refreshSession();
      print("✅ Supabase session refreshed successfully.");
    } catch (e) {
      print("❌ Error refreshing Supabase session: $e");
      throw Exception("Supabase session refresh failed: $e");
    }
  }

  /// ✅ Show No Internet Dialog with Better UX
  void _showNoInternetDialog() {
    print("🚨 Showing No Internet Dialog");

    if (!mounted) return; // Prevents crash if widget unmounted

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return WillPopScope(
          onWillPop: () async => false, // Prevent back button from dismissing
          child: AlertDialog(
            title: Row(
              children: [
                Icon(Icons.wifi_off, color: Colors.red),
                SizedBox(width: 10),
                Text("No Internet Connection"),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                    "This app requires an internet connection to function properly."),
                SizedBox(height: 10),
                Text("Please check your connection and try again."),
                SizedBox(height: 20),
                // Emergency Button
                Container(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop(); // Close dialog
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => EmergencyHotlinesPage(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.emergency, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          "EMERGENCY HOTLINES",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  setState(() {
                    _isLoading = true;
                    _statusMessage = 'Retrying...';
                  });
                  Future.delayed(const Duration(seconds: 1), _initializeApp);
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh),
                    SizedBox(width: 5),
                    Text("Retry"),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  SystemNavigator.pop(); // Quit app
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.exit_to_app),
                    SizedBox(width: 5),
                    Text("Quit"),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/lunope.png', width: 300),
            const SizedBox(height: 20),
            if (_isLoading) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(
                _statusMessage,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 20),
            ] else ...[
              Icon(
                Icons.wifi_off,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 20),
              Text(
                'No Internet Connection',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
            ],
            Text(
              'Bantay Lunop',
              style: TextStyle(
                fontSize: 40,
                fontStyle: FontStyle.normal,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 50),
            /*Text(
              'Version 0.0.45',
              style: TextStyle(
                fontSize: 30,
                color: Colors.grey[600],
              ),
            ),*/
          ],
        ),
      ),
    );
  }
}
