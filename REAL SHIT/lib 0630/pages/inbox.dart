import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: InboxPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class InboxPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF213A57),
        title: Text(
          'Inbox',
          style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 22,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            InboxCard(
              statusCode: 'RED',
              title: 'Water level change - Code RED',
              description: 'Critical water level in Jade Valley river.',
              borderColor: Colors.red,
              iconPath: '',
            ),
            SizedBox(height: 8),
            InboxCard(
              statusCode: 'ORANGE',
              title: 'Water level change - Code ORANGE',
              description: 'Above normal water level in Jade Valley river.',
              borderColor: Colors.orange,
              iconPath: '',
            ),
            SizedBox(height: 8),
            InboxCard(
              statusCode: 'GREEN',
              title: 'Water level change - Code GREEN',
              description: 'Safe water level in Jade Valley river.',
              borderColor: Colors.green,
              iconPath: '',
            ),
          ],
        ),
      ),
    );
  }
}

class InboxCard extends StatelessWidget {
  final String statusCode;
  final String title;
  final String description;
  final Color borderColor;
  final String iconPath;

  const InboxCard({
    required this.statusCode,
    required this.title,
    required this.description,
    required this.borderColor,
    required this.iconPath,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.5),
            spreadRadius: 1,
            blurRadius: 3,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: Color(0xFFE7E0EC),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1D1B20),
                      letterSpacing: 0.1,
                      height: 1.4, // Equivalent to lineHeight: "20px"
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF1D1B20),
                      letterSpacing: 0.25,
                      height: 1.4, // Equivalent to lineHeight: "20px"
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            width: 44,
            decoration: BoxDecoration(
              color: borderColor,
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
