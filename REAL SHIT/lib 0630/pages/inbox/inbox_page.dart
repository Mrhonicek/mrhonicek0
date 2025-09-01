import 'package:flutter/material.dart';
import 'inbox_card.dart';
import 'inbox_service_supa.dart';
import 'inbox_model.dart';

class InboxPage extends StatefulWidget {
  const InboxPage({Key? key}) : super(key: key);

  @override
  _InboxPageState createState() => _InboxPageState();
}

class _InboxPageState extends State<InboxPage> {
  final InboxService _inboxService = InboxService();
  late Future<List<NotifyBroadcast>> _notifications;
  List<NotifyBroadcast> _notificationList = [];
  bool _isLoading = true;
  bool _hasError = false;
  bool _isMounted = false;

  @override
  void initState() {
    super.initState();
    _isMounted = true;
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    if (!_isMounted) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      _notifications = _inboxService.fetchNotifications();
      final list = await _notifications;

      if (_isMounted) {
        setState(() {
          _notificationList = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (_isMounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _isMounted = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF213A57),
        title: const Text(
          'Inbox',
          style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 22,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: Colors.white,
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            color: Colors.white,
            onPressed: _loadNotifications,
            tooltip: 'Refresh Messages',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadNotifications,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Failed to load messages',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadNotifications,
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    if (_notificationList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.inbox_outlined,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            const Text(
              'No messages available',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadNotifications,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _notificationList.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {},
            child: InboxCard(
              notification: _notificationList[index],
            ),
          ),
        );
      },
    );
  }
}
