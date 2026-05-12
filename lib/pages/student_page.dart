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
  final String baseUrl = 'https://irina-pestersome-tolerably.ngrok-free.dev';
  bool _hasStarted = false;
  final Set<String> _scannedBeacons = {};

  @override
  void dispose() {
    _trackingTimer?.cancel();
    super.dispose();
  }

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
            'id_beacon': null,
            'latitude': position.latitude.toString(),
            'longitude': position.longitude.toString(),
            'is_valid': true,
          }),
        );
      } catch (_) {}
    });
  }

  Future<void> _endRace() async {
    final url = Uri.parse('$baseUrl/api/runners/${widget.runnerId}');
    await http.patch(
      url,
      headers: {'Content-Type': 'application/merge-patch+json'},
      body: json.encode({'date_end': DateTime.now().toIso8601String()}),
    );
  }

  Future<void> _startRace() async {
    final url = Uri.parse('$baseUrl/api/runners/${widget.runnerId}');
    await http.patch(
      url,
      headers: {'Content-Type': 'application/merge-patch+json'},
      body: json.encode({'date_start': DateTime.now().toIso8601String()}),
    );
  }

  String extractBeaconId(String url) {
    final uri = Uri.parse(url);
    return uri.pathSegments.last;
  }

  Future<void> _handleScan(String beaconUrlRaw) async {
    try {
      final beaconId = extractBeaconId(beaconUrlRaw);
      final beaconRes = await http.get(Uri.parse('$baseUrl/api/beacons/$beaconId'));

      if (beaconRes.statusCode != 200) {
        _showMessage("Balise inconnue", isError: true);
        return;
      }

      final beaconData = json.decode(beaconRes.body);
      final status = beaconData['status'];

      if (!_hasStarted) {
        if (status != 'depart') {
          _showMessage("Tu dois commencer par le depart !");
          return;
        }

        await _startRace();
        _hasStarted = true;
        _scannedBeacons.add(beaconId);
        await _logScan(beaconId);
        _startTracking();
        _showMessage("Course commencee !");
        return;
      }

      if (_scannedBeacons.contains(beaconId)) {
        _showMessage("Balise deja scannee !");
        return;
      }

      if (status == 'arrivee') {
        await _endRace();
        await _logScan(beaconId);
        _trackingTimer?.cancel();
        _showMessage("Course terminee !");
        return;
      }

      _scannedBeacons.add(beaconId);
      await _logScan(beaconId);
    } catch (_) {
      _showMessage("Erreur reseau", isError: true);
    }
  }

  Future<void> _logScan(String beaconId) async {
    final url = Uri.parse('$baseUrl/api/scan_logs');

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showMessage("Permission GPS refusee", isError: true);
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
          'id_runner': '/api/runners/${widget.runnerId}',
          'id_beacon': '/api/beacons/$beaconId',
          'latitude': position.latitude.toString(),
          'longitude': position.longitude.toString(),
          'is_valid': true,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        _showMessage("Balise $beaconId validee !");
      } else {
        _showMessage("Erreur API (${response.statusCode})", isError: true);
      }
    } catch (_) {
      _showMessage("Erreur GPS ou reseau", isError: true);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Course - ${widget.runnerName}')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(
                      Icons.flag_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Course ${widget.raceId} • ${_hasStarted ? "en cours" : "en attente du depart"}",
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  children: [
                    _isScanning
                        ? MobileScanner(
                            onDetect: (capture) {
                              for (final barcode in capture.barcodes) {
                                final beaconRaw = barcode.rawValue;
                                if (beaconRaw != null && _isScanning) {
                                  setState(() => _isScanning = false);
                                  _handleScan(beaconRaw).then((_) {
                                    Future.delayed(const Duration(seconds: 2), () {
                                      if (mounted) {
                                        setState(() => _isScanning = true);
                                      }
                                    });
                                  });
                                  break;
                                }
                              }
                            },
                          )
                        : const ColoredBox(
                            color: Color(0xFFEFF2F8),
                            child: Center(child: Text('Scan en pause...')),
                          ),
                    Positioned(
                      left: 14,
                      right: 14,
                      bottom: 14,
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            _hasStarted
                                ? "Scannez les balises dans l'ordre de la course."
                                : "Commencez par scanner la balise de depart.",
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}