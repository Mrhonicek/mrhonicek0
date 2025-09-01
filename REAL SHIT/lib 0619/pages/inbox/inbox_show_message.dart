import 'package:flutter/material.dart';
import 'inbox_model.dart';

class InboxDetailsPage extends StatelessWidget {
  final NotifyBroadcast notification;

  const InboxDetailsPage({Key? key, required this.notification})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(notification.title),
        backgroundColor: _getBorderColor(notification.warning_gauge_lvl),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              notification.title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              notification.description,
              style: const TextStyle(fontSize: 16),
            ),
            /* const SizedBox(height: 16),
            Text(
              "MapLink: ${notification.gismapLink}",
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            Text(
              "Redirect Link: ${notification.redirectLink}",
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),*/
            const SizedBox(height: 16),
            Text(
              "Date: ${notification.broadcastedOn}",
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  // Method to determine border color based on status code
  Color _getBorderColor(String statusCode) {
    switch (statusCode.toUpperCase()) {
      case 'RED':
        return Colors.red;
      case 'ORANGE':
        return Colors.orange;
      case 'YELLOW':
        return Colors.yellow;
      case 'GREEN':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
