import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html;

class FloodAlertsPage extends StatefulWidget {
  @override
  _FloodAlertsPageState createState() => _FloodAlertsPageState();
}

class _FloodAlertsPageState extends State<FloodAlertsPage> {
  List<String> floodAlerts = [];
  bool isLoading = true;
  String? responseText;

  @override
  void initState() {
    super.initState();
    fetchFloodData();
  }

  Future<void> fetchFloodData() async {
    setState(() {
      isLoading = true;
    });
    try {
      final url = Uri.parse("http://192.168.1.6:2120/api/flood/davao");
      final response = await http.get(url);
      setState(() {
        responseText = response.body;
      });

      if (response.statusCode == 200) {
        final document = html.parse(response.body);
        final alertElements =
            document.querySelectorAll("h2, p, .alert, .warning");

        setState(() {
          setState(() {
            floodAlerts = alertElements
                .map((e) => e.text.trim()) // Remove surrounding spaces
                .where((text) => text.isNotEmpty) // Keep only non-empty items
                .toList();
          });
        });
      } else {
        setState(() {
          floodAlerts = ["Failed to fetch data."];
        });
      }
    } catch (error) {
      setState(() {
        floodAlerts = ["Error: ${error.toString()}"];
        print(error);
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Flood Alerts in Davao"),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: fetchFloodData,
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Stay updated with real-time flood alerts.",
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 10),
            isLoading
                ? Center(child: CircularProgressIndicator())
                : Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(255, 0, 187, 255),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      floodAlerts.isNotEmpty
                          ? floodAlerts
                              .join("\n") // Combine all alerts in one block
                          : "No flood alerts available.",
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
            SizedBox(height: 10),
            Center(
              child: Text(
                "Source: PAGASA",
                style: TextStyle(color: Colors.blue),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
