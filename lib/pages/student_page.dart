import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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
  final String baseUrl = 'https://irina-pestersome-tolerably.ngrok-free.dev';

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
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/ld+json'},
        body: json.encode({
          'scan_at': DateTime.now().toIso8601String(),

          // ✅ FORMAT ATTENDU PAR TON API
          'id_runner': '/api/runners/${widget.runnerId}',
          'id_beacon': '/api/beacons/$beaconId',
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        _showMessage("Balise $beaconId validée !");
      } else {
        _showMessage(
          "Erreur API (${response.statusCode})",
          isError: true,
        );
      }
    } catch (e) {
      _showMessage("Erreur réseau", isError: true);
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
                          final beaconId = extractBeaconId(beaconRaw);

                          setState(() => _isScanning = false);

                          _logScan(beaconId).then((_) {
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