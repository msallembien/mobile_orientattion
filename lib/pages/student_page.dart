import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'dart:async';

class StudentPage extends StatefulWidget {
  final int runnerId;
  final String runnerName;
  final int raceId;

  const StudentPage({
    super.key,
    required this.runnerId,
    required this.runnerName,
    required this.raceId,
  });

  @override
  State<StudentPage> createState() => _StudentPageState();
}

class _StudentPageState extends State<StudentPage> {
  bool _isScanning = true;
  Timer? _trackingTimer;
  final String baseUrl = 'https://std45.beaupeyrat.com';
  bool _hasStarted = false;
  Set<String> _scannedBeacons = {};
  void _startTracking() {
    _trackingTimer?.cancel();

    _trackingTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      try {
        LocationPermission permission = await Geolocator.checkPermission();

        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }

        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          return;
        }

        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        final url = Uri.parse('$baseUrl/api/scan_logs');

        await http.post(
          url,
          headers: {'Content-Type': 'application/ld+json'},
          body: json.encode({
            'scan_at': DateTime.now().toIso8601String(),

            'id_runner': '/api/runners/${widget.runnerId}',

            // 👉 PAS DE BALISE
            'id_beacon': null,

            'latitude': position.latitude.toString(),
            'longitude': position.longitude.toString(),

            'is_valid': true,
          }),
        );
      } catch (e) {
        // rien → sinon spam toutes les 10s
      }
    });
  }
  Future<void> _endRace() async {
    final url = Uri.parse('$baseUrl/api/runners/${widget.runnerId}');

    await http.patch(
      url,
      headers: {
        'Content-Type': 'application/merge-patch+json',
      },
      body: json.encode({
        'date_end': DateTime.now().toIso8601String(),
      }),
    );
  }
  Future<void> _startRace() async {
    final url = Uri.parse('$baseUrl/api/runners/${widget.runnerId}');

    await http.patch(
      url,
      headers: {
        'Content-Type': 'application/merge-patch+json',
      },
      body: json.encode({
        'date_start': DateTime.now().toIso8601String(),
      }),
    );
  }
  Future<void> _handleScan(String beaconUrlRaw) async {
    try {
      final beaconId = extractBeaconId(beaconUrlRaw);

    final beaconRes = await http.get(
      Uri.parse('$baseUrl/api/beacons/$beaconId'),
    );

      if (beaconRes.statusCode != 200) {
        _showMessage("Balise inconnue", isError: true);
        return;
      }

      final beaconData = json.decode(beaconRes.body);
      final status = beaconData['status'];

      if (!_hasStarted) {
        if (status != 'depart') {
          _showMessage("Tu dois commencer par le départ !");
          return;
        }

        await _startRace();
        _hasStarted = true;

        _scannedBeacons.add(beaconId);
        await _logScan(beaconId);
        _startTracking();

        _showMessage("Course commencée !");
        return;
      }

      // 🚫 empêcher double scan
      if (_scannedBeacons.contains(beaconId)) {
        _showMessage("Balise déjà scannée !");
        return;
      }

      // 🏁 GESTION ARRIVÉE
      if (status == 'arrivee') {
        if (_scannedBeacons.length < 2) {
          _showMessage("Tu dois scanner toutes les balises avant l'arrivée !");
          return;
        }

        await _endRace();
        await _logScan(beaconId);

        _trackingTimer?.cancel(); // ✅ STOP tracking

        _showMessage("Course terminée !");
        return;
      }

      // ✅ balise normale
      _scannedBeacons.add(beaconId);

      await _logScan(beaconId);

    } catch (e) {
      _showMessage("Erreur réseau", isError: true);
    }
    @override
    void dispose() {
      _trackingTimer?.cancel();
      super.dispose();
    }
  }
  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ✅ EXTRACTION ID depuis l'URL du QR code
  String extractBeaconId(String url) {
    final uri = Uri.parse(url);
    return uri.pathSegments.last;
  }

  Future<void> _logScan(String beaconId) async {
    final url = Uri.parse('$baseUrl/api/scan_logs');

    try {
      // 📍 récupérer la position
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showMessage("Permission GPS refusée", isError: true);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/ld+json'},
        body: json.encode({
          'scan_at': DateTime.now().toIso8601String(),

          // 🔗 relations API
          'id_runner': '/api/runners/${widget.runnerId}',
          'id_beacon': '/api/beacons/$beaconId',

          // 📍 NOUVEAU
          'latitude': position.latitude.toString(),
          'longitude': position.longitude.toString(),

          // ✅ validation
          'is_valid': true,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        _showMessage("Balise $beaconId validée !");
      } else {
        _showMessage("Erreur API (${response.statusCode})", isError: true);
      }
    } catch (e) {
      _showMessage("Erreur GPS ou réseau", isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Bienvenue ${widget.runnerName}')),
      body: Column(
        children: [
          Expanded(
            flex: 4,
            child: _isScanning
                ? MobileScanner(
                    onDetect: (capture) {
                      final barcodes = capture.barcodes;

                      for (final barcode in barcodes) {
                        final beaconRaw = barcode.rawValue;

                        if (beaconRaw != null && _isScanning) {
                          // ✅ EXTRACTION ID
                          setState(() => _isScanning = false);

                          _handleScan(beaconRaw).then((_) {
                            Future.delayed(const Duration(seconds: 2), () {
                              if (mounted) {
                                setState(() => _isScanning = true);
                              }
                            });
                          });
                        }
                      }
                    },
                  )
                : const Center(child: Text('Scan terminé')),
          ),
          Expanded(
            flex: 1,
            child: Center(
              child: Text(
                'Scanner un QR code pour la course ${widget.raceId}',
              ),
            ),
          ),
        ],
      ),
    );
  }
}