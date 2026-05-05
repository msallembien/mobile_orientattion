import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ParcoursMapPage extends StatefulWidget {
  final int parcoursId;
  final String token;

  const ParcoursMapPage({
    super.key,
    required this.parcoursId,
    required this.token,
  });

  @override
  State<ParcoursMapPage> createState() => _ParcoursMapPageState();
}

class _ParcoursMapPageState extends State<ParcoursMapPage> {
  Set<Marker> markers = {};
  Set<Polyline> polylines = {};
  LatLng? initialPosition;
  bool mapLoaded = false; // ⚡ éviter rebuild infini

  @override
  void initState() {
    super.initState();
    loadBeacons();
  }

  Future loadBeacons() async {
    try {
      final response = await http.get(
        Uri.parse(
            "https://irina-pestersome-tolerably.ngrok-free.dev/api/beacons?map=${widget.parcoursId}"),
        headers: {
          "Authorization": "Bearer ${widget.token}",
        },
      );

      if (response.statusCode != 200) {
        debugPrint("Erreur API Beacons: ${response.statusCode}");
        if (!mapLoaded) {
          setState(() {
            initialPosition = const LatLng(46.2276, 2.2137); // centre France
            mapLoaded = true;
          });
        }
        return;
      }

      final data = json.decode(response.body);
      final List beacons = (data['member'] ?? []) as List;
      List<LatLng> points = [];

      for (var beacon in beacons) {
        final lat = double.tryParse(beacon["latitude"]?.toString() ?? '');
        final lng = double.tryParse(beacon["longitude"]?.toString() ?? '');
        if (lat == null || lng == null) continue;

        points.add(LatLng(lat, lng));

        final markerId = beacon["id"] ??
            int.tryParse(beacon["@id"].toString().split("/").last) ??
            DateTime.now().millisecondsSinceEpoch;

        markers.add(
          Marker(
            markerId: MarkerId(markerId.toString()),
            position: LatLng(lat, lng),
            infoWindow: InfoWindow(title: beacon["name"] ?? "Beacon"),
          ),
        );
      }

      // Polyline pour relier les beacons
      if (points.isNotEmpty) {
        polylines.add(
          Polyline(
            polylineId: const PolylineId("parcours"),
            points: points,
            width: 4,
            color: Colors.blue,
          ),
        );
      }

      // Définir initialPosition une seule fois pour éviter rebuild infini
      if (!mapLoaded) {
        setState(() {
          initialPosition =
              points.isNotEmpty ? points.first : const LatLng(46.2276, 2.2137);
          mapLoaded = true;
        });
      }
    } catch (e) {
      debugPrint("Exception loadBeacons: $e");
      if (!mapLoaded) {
        setState(() {
          initialPosition = const LatLng(46.2276, 2.2137);
          mapLoaded = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Carte parcours")),
      body: initialPosition == null
          ? const Center(child: CircularProgressIndicator())
          : GoogleMap(
              initialCameraPosition:
                  CameraPosition(target: initialPosition!, zoom: 13),
              markers: markers,
              polylines: polylines,
            ),
    );
  }
}