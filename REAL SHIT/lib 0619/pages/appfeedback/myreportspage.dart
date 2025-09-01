import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class MyReportsPage extends StatefulWidget {
  @override
  _MyReportsPageState createState() => _MyReportsPageState();
}

class _MyReportsPageState extends State<MyReportsPage>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> reports = [];
  List<Map<String, dynamic>> filteredReports = [];
  bool isLoading = true;
  String selectedFilter = 'all'; // all, bug_reports, feedback, open, closed
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _loadReports();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadReports() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final response = await supabase
          .from('bugreportsandfeedback')
          .select('*')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      setState(() {
        reports = List<Map<String, dynamic>>.from(response);
        _applyFilter();
        isLoading = false;
      });

      _animationController.forward();
    } catch (e) {
      print('Error loading reports: $e');
      setState(() {
        isLoading = false;
      });
      _showErrorSnackBar('Failed to load reports');
    }
  }

  void _applyFilter() {
    switch (selectedFilter) {
      case 'bug_reports':
        filteredReports =
            reports.where((r) => r['is_bug_report'] == true).toList();
        break;
      case 'feedback':
        filteredReports =
            reports.where((r) => r['is_bug_report'] == false).toList();
        break;
      case 'open':
        filteredReports = reports
            .where((r) => r['status'] != 'closed' && r['status'] != 'resolved')
            .toList();
        break;
      case 'closed':
        filteredReports = reports
            .where((r) => r['status'] == 'closed' || r['status'] == 'resolved')
            .toList();
        break;
      default:
        filteredReports = List.from(reports);
    }
    setState(() {});
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error, color: Colors.white),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'open':
        return Colors.orange;
      case 'in_progress':
        return Colors.blue;
      case 'resolved':
      case 'closed':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'open':
        return Icons.radio_button_unchecked;
      case 'in_progress':
        return Icons.sync;
      case 'resolved':
      case 'closed':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'low':
        return Colors.green;
      case 'medium':
        return Colors.orange;
      case 'high':
        return Colors.red;
      case 'critical':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(String dateString) {
    final date = DateTime.parse(dateString);
    return DateFormat('MMM dd, yyyy • HH:mm').format(date);
  }

  void _showReportDetails(Map<String, dynamic> report) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildReportDetailsSheet(report),
    );
  }

  Widget _buildReportDetailsSheet(Map<String, dynamic> report) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: report['is_bug_report']
                                  ? Colors.red.withOpacity(0.1)
                                  : Colors.blue.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              report['is_bug_report']
                                  ? Icons.bug_report
                                  : Icons.feedback,
                              color: report['is_bug_report']
                                  ? Colors.red
                                  : Colors.blue,
                              size: 24,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  report['title'],
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  report['is_bug_report']
                                      ? 'Bug Report'
                                      : 'Feedback',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 20),

                      // Status and Priority
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _getStatusColor(report['status'])
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _getStatusColor(report['status'])
                                    .withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getStatusIcon(report['status']),
                                  size: 16,
                                  color: _getStatusColor(report['status']),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  report['status'].toString().toUpperCase(),
                                  style: TextStyle(
                                    color: _getStatusColor(report['status']),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 12),
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _getPriorityColor(report['priority'])
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _getPriorityColor(report['priority'])
                                    .withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              '${report['priority'].toString().toUpperCase()} PRIORITY',
                              style: TextStyle(
                                color: _getPriorityColor(report['priority']),
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 20),

                      // Description
                      Text(
                        'Description',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Text(
                          report['description'],
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                      ),

                      // Screenshot if available
                      if (report['screenshot_url'] != null) ...[
                        SizedBox(height: 20),
                        Text(
                          'Screenshot',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            report['screenshot_url'],
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                height: 200,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.image_not_supported,
                                          color: Colors.grey[400]),
                                      SizedBox(height: 8),
                                      Text('Image not available',
                                          style: TextStyle(
                                              color: Colors.grey[600])),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],

                      // Admin Notes
                      if (report['admin_notes'] != null &&
                          report['admin_notes'].toString().isNotEmpty) ...[
                        SizedBox(height: 20),
                        Text(
                          'Admin Response',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue,
                          ),
                        ),
                        SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border:
                                Border.all(color: Colors.blue.withOpacity(0.2)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.admin_panel_settings,
                                  color: Colors.blue,
                                  size: 20,
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  report['admin_notes'],
                                  style: TextStyle(
                                    fontSize: 14,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      SizedBox(height: 20),

                      // Dates
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(Icons.access_time,
                                    size: 16, color: Colors.grey[600]),
                                SizedBox(width: 8),
                                Text(
                                  'Created: ${_formatDate(report['created_at'])}',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            if (report['updated_at'] !=
                                report['created_at']) ...[
                              SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.update,
                                      size: 16, color: Colors.grey[600]),
                                  SizedBox(width: 8),
                                  Text(
                                    'Updated: ${_formatDate(report['updated_at'])}',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (report['resolved_at'] != null) ...[
                              SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.check_circle,
                                      size: 16, color: Colors.green),
                                  SizedBox(width: 8),
                                  Text(
                                    'Resolved: ${_formatDate(report['resolved_at'])}',
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterChips() {
    final filters = [
      {'key': 'all', 'label': 'All', 'icon': Icons.all_inclusive},
      {'key': 'bug_reports', 'label': 'Bug Reports', 'icon': Icons.bug_report},
      {'key': 'feedback', 'label': 'Feedback', 'icon': Icons.feedback},
      {'key': 'open', 'label': 'Open', 'icon': Icons.radio_button_unchecked},
      {'key': 'closed', 'label': 'Closed', 'icon': Icons.check_circle},
    ];

    return Container(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 20),
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = selectedFilter == filter['key'];

          return Padding(
            padding: EdgeInsets.only(right: 12),
            child: FilterChip(
              selected: isSelected,
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    filter['icon'] as IconData,
                    size: 16,
                    color: isSelected ? Colors.white : Colors.grey[600],
                  ),
                  SizedBox(width: 6),
                  Text(
                    filter['label'] as String,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey[600],
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
              onSelected: (selected) {
                setState(() {
                  selectedFilter = filter['key'] as String;
                  _applyFilter();
                });
              },
              selectedColor: Colors.blue,
              backgroundColor: Colors.grey[100],
              elevation: isSelected ? 2 : 0,
            ),
          );
        },
      ),
    );
  }

  Widget _buildReportCard(Map<String, dynamic> report) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          onTap: () => _showReportDetails(report),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: report['is_bug_report']
                            ? Colors.red.withOpacity(0.1)
                            : Colors.blue.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        report['is_bug_report']
                            ? Icons.bug_report
                            : Icons.feedback,
                        color:
                            report['is_bug_report'] ? Colors.red : Colors.blue,
                        size: 20,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            report['title'],
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 2),
                          Text(
                            report['is_bug_report'] ? 'Bug Report' : 'Feedback',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color:
                            _getStatusColor(report['status']).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getStatusIcon(report['status']),
                            size: 12,
                            color: _getStatusColor(report['status']),
                          ),
                          SizedBox(width: 4),
                          Text(
                            report['status'].toString().toUpperCase(),
                            style: TextStyle(
                              color: _getStatusColor(report['status']),
                              fontWeight: FontWeight.w600,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 12),

                // Description
                Text(
                  report['description'],
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 14,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                SizedBox(height: 12),

                // Bottom row
                Row(
                  children: [
                    // Priority
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getPriorityColor(report['priority'])
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${report['priority'].toString().toUpperCase()} PRIORITY',
                        style: TextStyle(
                          color: _getPriorityColor(report['priority']),
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                        ),
                      ),
                    ),

                    Spacer(),

                    // Admin response indicator
                    if (report['admin_notes'] != null &&
                        report['admin_notes'].toString().isNotEmpty)
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.admin_panel_settings,
                                size: 12, color: Colors.green),
                            SizedBox(width: 4),
                            Text(
                              'ADMIN REPLIED',
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.w600,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),

                    SizedBox(width: 8),

                    // Date
                    Text(
                      _formatDate(report['created_at']),
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'My Reports',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadReports,
          ),
        ],
      ),
      body: Column(
        children: [
          // Statistics Header
          if (!isLoading) ...[
            Container(
              padding: EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Text(
                            '${reports.length}',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                          Text(
                            'Total Reports',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Text(
                            '${reports.where((r) => r['status'] != 'closed' && r['status'] != 'resolved').length}',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                          Text(
                            'Open Reports',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Filter chips
            _buildFilterChips(),
            SizedBox(height: 10),
          ],

          // Content
          Expanded(
            child: isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          'Loading your reports...',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  )
                : filteredReports.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inbox,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No reports found',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[600],
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              selectedFilter == 'all'
                                  ? 'You haven\'t submitted any reports yet'
                                  : 'No reports match the selected filter',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                    : FadeTransition(
                        opacity: _fadeAnimation,
                        child: RefreshIndicator(
                          onRefresh: _loadReports,
                          child: ListView.builder(
                            itemCount: filteredReports.length,
                            itemBuilder: (context, index) {
                              return _buildReportCard(filteredReports[index]);
                            },
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
