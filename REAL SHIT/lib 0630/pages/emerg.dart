import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: EmergencyHotlinesPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class EmergencyHotlinesPage extends StatelessWidget {
  Future<void> _callEmergencyNumbernineoneone() async {
    final Uri phoneUri = Uri(scheme: 'tel', path: '911');
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      print('Could not launch phone app');
    }
  }

  Future<void> _callEmergencyNumberBDRRMC() async {
    final Uri phoneUri = Uri(scheme: 'tel', path: '0968 668 4181');
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      print('Could not launch phone app');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFFF7F2FA),
        title: Text(
          'Emergency Hotlines',
          style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 22,
            color: Color(0xFF1D1B20),
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Color(0xFF1D1B20)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '🚨 Need urgent help in case of an emergency? Call 911 now.\n'
                '📞 Huwag mag-atubiling tumawag sa 911.\n'
                '📞 Tawag dayon sa 911 kung naay emerhensiya.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 25,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF49454F),
                  height: 1.5,
                ),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  padding: EdgeInsets.symmetric(vertical: 14, horizontal: 32),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
                onPressed: _callEmergencyNumbernineoneone,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.phone, color: Colors.white, size: 22),
                    SizedBox(width: 10),
                    Text(
                      'Call 911 Now',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 100),
              Text(
                '🚨 Need urgent help from your local disaster response team?\n'
                '📞 Tumawag sa BDRRMC: 0968 668 4181\n'
                '📞 Kontaka ang BDRRMC: 0968 668 4181',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 25,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF49454F),
                  height: 1.5,
                ),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  padding: EdgeInsets.symmetric(vertical: 14, horizontal: 32),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
                onPressed: _callEmergencyNumberBDRRMC,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.phone_forwarded, color: Colors.white, size: 22),
                    SizedBox(width: 10),
                    Text(
                      'Call BDRRMC Now',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
