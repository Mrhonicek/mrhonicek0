import 'package:flutter/material.dart';
import 'package:gismultiinstancetestingenvironment/pages/inbox/inbox_page.dart';
import 'package:gismultiinstancetestingenvironment/pages/riverbasin.dart';
import 'package:gismultiinstancetestingenvironment/pages/emerg.dart';
import 'package:gismultiinstancetestingenvironment/pages/profilepage.dart';
import 'package:gismultiinstancetestingenvironment/pages/mapboxmap/mapboxmappage.dart';

class NewsfeedDrawer extends StatelessWidget {
  final String? username;
  final String? email;
  final VoidCallback onLogout;

  const NewsfeedDrawer({
    Key? key,
    required this.username,
    required this.email,
    required this.onLogout,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(username ?? "Unknown"),
            accountEmail: Text(email ?? "No Email"),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.grey[300],
            ),
          ),
          _buildDrawerItem(Icons.inbox, 'Inbox', () {
            Navigator.push(
                context, MaterialPageRoute(builder: (_) => InboxPage()));
          }),
          _buildDrawerItem(Icons.local_drink, 'River Basin Status', () {
            Navigator.push(
                context, MaterialPageRoute(builder: (_) => RiverBasinPage()));
          }),
          _buildDrawerItem(Icons.phone_in_talk, 'Emergency Hotline', () {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => EmergencyHotlinesPage()));
          }),
          _buildDrawerItem(Icons.settings, 'Profile Settings', () {
            Navigator.push(
                context, MaterialPageRoute(builder: (_) => MyProfilePage()));
          }),
          _buildDrawerItem(Icons.map_rounded, 'Jade Valley Area Map', () {
            Navigator.push(
                context, MaterialPageRoute(builder: (_) => MapPage()));
          }),
          _buildDrawerItem(Icons.exit_to_app, 'Logout', onLogout),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      onTap: onTap,
    );
  }
}
