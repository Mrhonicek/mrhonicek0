import 'package:flutter/material.dart';
import 'inbox_model.dart';
import 'inbox_show_message.dart';

class InboxCard extends StatelessWidget {
  final NotifyBroadcast notification;

  const InboxCard({Key? key, required this.notification}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color:
              _getBorderColor(notification.warning_gauge_lvl).withOpacity(0.5),
          width: 1.5,
        ),
      ),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _navigateToDetailsPage(context, notification),
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _getIconForWarningLevel(
                              notification.warning_gauge_lvl),
                          color:
                              _getBorderColor(notification.warning_gauge_lvl),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            notification.title,
                            style: const TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF1D1B20),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDateTime(
                              notification.broadcastedOn.toString()),
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios,
                          size: 14,
                          color: Colors.grey,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Container(
              width: 12,
              height: 84, // Fixed height for the card
              decoration: BoxDecoration(
                color: _getBorderColor(notification.warning_gauge_lvl),
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToDetailsPage(
      BuildContext context, NotifyBroadcast notification) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InboxDetailsPage(notification: notification),
      ),
    );
  }

  Color _getBorderColor(String statusCode) {
    switch (statusCode.toUpperCase()) {
      case 'RED':
        return Colors.red;
      case 'ORANGE':
        return Colors.orange;
      case 'YELLOW':
        return Colors.amber;
      case 'GREEN':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getIconForWarningLevel(String level) {
    switch (level.toUpperCase()) {
      case 'RED':
        return Icons.warning_rounded;
      case 'ORANGE':
        return Icons.notification_important;
      case 'YELLOW':
        return Icons.info_outline;
      case 'GREEN':
        return Icons.check_circle_outline;
      default:
        return Icons.message;
    }
  }

  String _formatDateTime(String dateTimeString) {
    try {
      final dateTime = DateTime.parse(dateTimeString);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays > 0) {
        return '${difference.inDays}d ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return dateTimeString;
    }
  }
}
