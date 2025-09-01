import 'package:flutter/material.dart';

class FAQPage extends StatefulWidget {
  const FAQPage({Key? key}) : super(key: key);

  @override
  State<FAQPage> createState() => _FAQPageState();
}

class _FAQPageState extends State<FAQPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int? _expandedIndex;

  final List<FAQItem> _faqItems = [
    // Installation and Setup
    FAQItem(
      category: 'Installation and Setup',
      question: 'How do I install the flood monitoring app?',
      answer:
          'You can download and install the application from your device\'s app store (Google Play Store). The app is free to use and designed to work on Android platforms.',
      icon: Icons.download,
    ),
    FAQItem(
      category: 'Installation and Setup',
      question: 'What permissions does the app need?',
      answer:
          'The app requires permission to send notifications, track your location and access storage on your phone. These permissions are essential for receiving flood alerts, flood reporting and enhance quick loading time of images.',
      icon: Icons.security,
    ),
    FAQItem(
      category: 'Installation and Setup',
      question: 'Do I need internet connection to use the app?',
      answer:
          'You need internet connection for the initial setup and to receive real-time updates. However, the app is designed to work offline only for emergency hotline. Alert messages will still be received when you\'re back online.',
      icon: Icons.wifi,
    ),

    // Notifications and Alerts
    FAQItem(
      category: 'Notifications and Alerts',
      question: 'How will I receive flood alerts?',
      answer:
          'You\'ll receive in-app notifications and alert emergency messages containing rainfall and flood information directly from the PAGASA. Emergency alert messages also work when several flood reports have been submitted to warn you when the flood is imminent.',
      icon: Icons.notifications_active,
    ),
    FAQItem(
      category: 'Notifications and Alerts',
      question: 'What information is included in flood notifications?',
      answer:
          'Each notification contains flood level data, important safety information, with real-time data from the monitoring system.',
      icon: Icons.info,
    ),
    FAQItem(
      category: 'Notifications and Alerts',
      question: 'How often are flood updates sent?',
      answer:
          'The system receives data from PAG-ASA every 30 minutes, ensuring you receive the most current flood monitoring information available.',
      icon: Icons.schedule,
    ),

    // App Features and Functionality
    FAQItem(
      category: 'App Features and Functionality',
      question: 'Can I view weather forecasts in the app?',
      answer:
          'Yes, the app includes weather forecast functionality to help you stay informed about upcoming weather conditions that might affect flood levels.',
      icon: Icons.cloud,
    ),
    FAQItem(
      category: 'App Features and Functionality',
      question: 'Can I use the app to report flooding in my area?',
      answer:
          'Yes, you can create posts to share updates about flooding occurring in your area, helping to keep your community informed about local conditions.',
      icon: Icons.report,
    ),
    FAQItem(
      category: 'App Features and Functionality',
      question: 'How do I contact emergency services through the app?',
      answer:
          'The app provides direct access to emergency hotlines, including your Local Barangay\'s rescue team hotline and 911. You can call these numbers directly from within the application.',
      icon: Icons.emergency,
    ),
    FAQItem(
      category: 'App Features and Functionality',
      question: 'Can I communicate with other users in my area?',
      answer:
          'Yes, you can comment on posts from other users in your neighborhood to communicate, ask for help, or provide assistance during flood events.',
      icon: Icons.forum,
    ),
    FAQItem(
      category: 'App Features and Functionality',
      question: 'How can I provide feedback or report problems with the app?',
      answer:
          'The app includes a feedback system where you can report bugs and suggest improvements. Your feedback helps the developers maintain and enhance the application.',
      icon: Icons.feedback,
    ),

    // Technical Support
    FAQItem(
      category: 'Technical Support',
      question: 'What if the app doesn\'t work properly?',
      answer:
          'If you experience any issues, you can report bugs through the app\'s feedback system. You can also leave a feedback on the Google play store review page of this app. The development team monitors reviews and ratings to quickly apply patches and fixes.',
      icon: Icons.bug_report,
    ),
    FAQItem(
      category: 'Technical Support',
      question: 'How often is the app updated?',
      answer:
          'The app undergoes regular maintenance and upgrades to ensure reliability, security compliance, and adherence to data privacy regulations.',
      icon: Icons.system_update,
    ),
  ];

  List<FAQItem> get _filteredFAQItems {
    if (_searchQuery.isEmpty) {
      return _faqItems;
    }
    return _faqItems.where((item) {
      return item.question.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.answer.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.category.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Frequently Asked Questions',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF1565C0),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Header Section
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1565C0), Color(0xFF1976D2)],
              ),
            ),
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Jade Valley Flood Monitoring App',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 15),
                // Search Bar
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                        _expandedIndex = null;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search FAQs...',
                      prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                  _expandedIndex = null;
                                });
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // FAQ List
          Expanded(
            child: _filteredFAQItems.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredFAQItems.length,
                    itemBuilder: (context, index) {
                      final faqItem = _filteredFAQItems[index];
                      final isExpanded = _expandedIndex == index;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ExpansionTile(
                          key: ValueKey(index),
                          initiallyExpanded: isExpanded,
                          onExpansionChanged: (expanded) {
                            setState(() {
                              _expandedIndex = expanded ? index : null;
                            });
                          },
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1565C0).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              faqItem.icon,
                              color: const Color(0xFF1565C0),
                              size: 20,
                            ),
                          ),
                          title: Text(
                            faqItem.question,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: Color(0xFF2C3E50),
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              faqItem.category,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                              child: Text(
                                faqItem.answer,
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 14,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                          tilePadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          childrenPadding: EdgeInsets.zero,
                          expandedCrossAxisAlignment: CrossAxisAlignment.start,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showContactDialog(context);
        },
        backgroundColor: const Color(0xFF1565C0),
        icon: const Icon(Icons.help_outline, color: Colors.white),
        label: const Text(
          'Need Help?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No FAQs found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search terms',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  void _showContactDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.support_agent, color: Color(0xFF1565C0)),
              SizedBox(width: 8),
              Text('Still Need Help?'),
            ],
          ),
          content: const Text(
              'If you couldn\'t find the answer to your question, you can:\n\n'
              '• Use the feedback system in the app\n'
              '• Contact emergency services for urgent matters\n'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Got it'),
            ),
          ],
        );
      },
    );
  }
}

class FAQItem {
  final String category;
  final String question;
  final String answer;
  final IconData icon;

  FAQItem({
    required this.category,
    required this.question,
    required this.answer,
    required this.icon,
  });
}
