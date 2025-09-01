import 'package:flutter/material.dart';
import 'package:gismultiinstancetestingenvironment/pages/editaccinfo.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MyProfilePage extends StatefulWidget {
  @override
  _MyProfilePageState createState() => _MyProfilePageState();
}

class _MyProfilePageState extends State<MyProfilePage> {
  final SupabaseClient supabase = Supabase.instance.client;
  String? userEmail;
  String? userName;

  @override
  void initState() {
    super.initState();
    _getUserSession();
  }

  Future<void> _getUserSession() async {
    final user = supabase.auth.currentUser;

    if (user != null) {
      try {
        final response = await supabase
            .from('profiles')
            .select('username, email')
            .eq('id', user.id)
            .single();

        setState(() {
          userEmail = response['email'] ?? user.email;
          userName = response['username'] ?? 'No Name';
        });
      } catch (error) {
        print("Error fetching user data: $error");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF213A57),
        title: Text(
          'Profile',
          style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 22,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ),
      body: Center(
        // Wrap with Center to align all contents
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center, // Center vertically
            crossAxisAlignment:
                CrossAxisAlignment.center, // Center horizontally
            children: [
              SizedBox(height: 16),
              Text(
                userName ?? 'Loading...',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 36,
                  fontWeight: FontWeight.w400,
                  color: Colors.black,
                ),
              ),
              SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  'Email: ${userEmail ?? "Loading..."}',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF49454F),
                    letterSpacing: 0.25,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(height: 40),
              ElevatedButton.icon(
                icon: Icon(Icons.account_circle, color: Color(0xFF213A57)),
                label: Text(
                  'Change account information',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF49454F),
                    letterSpacing: 0.1,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Color(0xFF213A57),
                  backgroundColor: Colors.white,
                  side: BorderSide(color: Colors.grey),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(100),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EditAccountInfo(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
