// lib/modules/inbox/inbox_model.dart

class NotifyBroadcast {
  final int emAlertId;
  final String title;
  final String description;
  final String? gismapLink;
  final String? redirectLink;
  final String
      warning_gauge_lvl; // Color indicator ('RED', 'ORANGE', 'GREEN', 'GREY')
  final DateTime broadcastedOn;
  final int? statusFlag;

  NotifyBroadcast({
    required this.emAlertId,
    required this.title,
    required this.description,
    this.gismapLink,
    this.redirectLink,
    required this.warning_gauge_lvl,
    required this.broadcastedOn,
    this.statusFlag,
  });

  factory NotifyBroadcast.fromJson(Map<String, dynamic> json) {
    return NotifyBroadcast(
      emAlertId: json['em_alert_id'] ?? 0,
      title: json['message_title'] ?? 'No Title',
      description: json['message'] ?? 'No Description',
      gismapLink: json['gismap_link'],
      redirectLink: json['redirect_link'],
      warning_gauge_lvl: (json['warning_gauge_lvl'] ?? 'GREY')
          .toUpperCase(), // Default & case safety
      broadcastedOn:
          DateTime.tryParse(json['broadcasted_on'] ?? '') ?? DateTime.now(),
      statusFlag: json['status_flag'],
    );
  }
}
