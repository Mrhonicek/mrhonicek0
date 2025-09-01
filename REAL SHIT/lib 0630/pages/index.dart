import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gismultiinstancetestingenvironment/pages/loginpage.dart';
import 'package:gismultiinstancetestingenvironment/pages/signuppage.dart';
import 'package:gismultiinstancetestingenvironment/pages/newsfeed/newsfeed.dart'; // ✅ Import the main page after login

class Index extends StatefulWidget {
  const Index({super.key});

  @override
  _IndexState createState() => _IndexState();
}

class _IndexState extends State<Index> {
  bool _isLoading = true;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _checkSession(); // ✅ Check session on startup
  }

  Future<void> _checkSession() async {
    final session = Supabase.instance.client.auth.currentSession;

    if (session != null) {
      setState(() {
        _isAuthenticated = true;
      });
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
            child:
                CircularProgressIndicator()), // ✅ Show loading indicator while checking session
      );
    }

    return MaterialApp(
      home: _isAuthenticated
          ? NewsFeed() // ✅ If session exists, go to NewsFeed instead of login
          : DefaultTabController(
              length: 2,
              child: Scaffold(
                appBar: AppBar(
                  bottom: const TabBar(
                    tabs: [
                      Tab(text: 'Log In'),
                      Tab(text: 'Sign Up'),
                    ],
                  ),
                  title: const Center(
                    child: Text('BantayLunop Mobile APP for Jade Valley'),
                  ),
                ),
                body: const TabBarView(
                  children: [
                    LoginPage(),
                    SignUpPage(),
                  ],
                ),
              ),
            ),
    );
  }
}
