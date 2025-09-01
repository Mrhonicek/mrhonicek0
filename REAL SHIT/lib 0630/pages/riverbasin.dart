import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class RiverBasinPage extends StatefulWidget {
  @override
  _RiverBasinPageState createState() => _RiverBasinPageState();
}

class _RiverBasinPageState extends State<RiverBasinPage> {
  List<String> floodAlerts = [];
  String? basinImageUrl;
  String? animatedImageUrl;
  String? lastUpdated;
  bool isLoading = true;
  bool _isMounted = false;
  bool _hasInternet = true;

  final _supabase = Supabase.instance.client;
  final _connectivity = Connectivity();

  @override
  void initState() {
    super.initState();
    _isMounted = true;
    _checkInternetConnection();
    fetchRiverBasinData();
  }

  Future<void> _checkInternetConnection() async {
    final connectivityResult = await _connectivity.checkConnectivity();
    if (!_isMounted) return;

    setState(() {
      _hasInternet = connectivityResult != ConnectivityResult.none;
    });

    if (!_hasInternet) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No internet connection'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> fetchRiverBasinData() async {
    if (!_isMounted || !_hasInternet) return;

    setState(() {
      isLoading = true;
    });

    try {
      final response = await _supabase
          .from('river_basin_data')
          .select()
          .not('flood_alerts', 'is', null) // Exclude null flood_alerts
          .neq('flood_alerts', '[]') // Exclude empty array flood_alerts
          .order('created_at', ascending: false)
          .limit(1)
          .single()
          .timeout(Duration(seconds: 10));

      if (!_isMounted) return;

      setState(() {
        floodAlerts = List<String>.from(response['flood_alerts'] ?? []);
        basinImageUrl = response['basin_image_url'] ??
            "https://pubfiles.pagasa.dost.gov.ph/pagasaweb/images/basins/davao-basin.jpg";
        animatedImageUrl = response['animated_image_url'] ??
            "https://src.meteopilipinas.gov.ph/repo/mtsat-colored/24hour/latest-him-colored.gif";
        lastUpdated = response['last_updated'] != null
            ? DateTime.parse(response['last_updated'].toString())
                .toLocal()
                .toString()
            : 'Unknown';
      });
    } catch (error) {
      if (!_isMounted) return;

      setState(() {
        floodAlerts = ["Error fetching data. Please try again later."];
        basinImageUrl =
            "https://pubfiles.pagasa.dost.gov.ph/pagasaweb/images/basins/davao-basin.jpg";
        animatedImageUrl =
            "https://src.meteopilipinas.gov.ph/repo/mtsat-colored/24hour/latest-him-colored.gif";
        lastUpdated = 'Unknown';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load data'),
          duration: Duration(seconds: 3),
        ),
      );
    } finally {
      if (!_isMounted) return;
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _isMounted = false;
    super.dispose();
  }

  void _showImageDialog(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: EdgeInsets.zero,
        backgroundColor: Colors.black,
        child: SizedBox(
          width: MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.height,
          child: InteractiveViewer(
            panEnabled: true,
            minScale: 0.5,
            maxScale: 4.0,
            child: Center(
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error, color: Colors.red),
                        SizedBox(height: 8),
                        Text('Failed to load image',
                            style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNetworkImage(String? imageUrl, String title) {
    if (imageUrl == null) {
      return Container(
        color: Colors.grey[200],
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return AspectRatio(
      aspectRatio: 1, // 1:1 aspect ratio (8x8)
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.grey[200],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error, color: Colors.red),
                          SizedBox(height: 8),
                          Text('Failed to load image'),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('River Basin Status'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Theme.of(context).primaryColor,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _checkInternetConnection();
          if (_hasInternet) {
            await fetchRiverBasinData();
          }
        },
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(16.0),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Status Card
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Current Status',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 8),
                          isLoading
                              ? Center(child: CircularProgressIndicator())
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (lastUpdated != null)
                                      /*  Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 8.0),
                                        child: Text(
                                          'Last updated: $lastUpdated',
                                          style: TextStyle(
                                            color: Colors.grey,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),*/
                                      ...floodAlerts.map((alert) => Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 8.0),
                                            child: Text(
                                              alert,
                                              style: TextStyle(fontSize: 14),
                                            ),
                                          )),
                                    if (floodAlerts.isEmpty)
                                      Text(
                                        "No flood alerts available.",
                                        style: TextStyle(fontSize: 14),
                                      ),
                                  ],
                                ),
                          Text(
                            "Source: PAGASA Weather Bureau",
                            style: TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Basin Image Card
                  GestureDetector(
                    onTap: () => basinImageUrl != null
                        ? _showImageDialog(context, basinImageUrl!)
                        : null,
                    child: Card(
                      elevation: 2,
                      child:
                          _buildNetworkImage(basinImageUrl, 'River Basin Map'),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Satellite Image Card
                  GestureDetector(
                    onTap: () => animatedImageUrl != null
                        ? _showImageDialog(context, animatedImageUrl!)
                        : null,
                    child: Card(
                      elevation: 2,
                      child: _buildNetworkImage(
                          animatedImageUrl, 'Satellite Imagery'),
                    ),
                  ),

                  const SizedBox(height: 32),
                ]),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await _checkInternetConnection();
          if (_hasInternet) {
            await fetchRiverBasinData();
          }
        },
        tooltip: 'Refresh',
        child: Icon(Icons.refresh),
      ),
    );
  }
}
