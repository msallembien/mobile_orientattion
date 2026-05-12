import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

class ProfPage extends StatefulWidget {
  final String token;
  const ProfPage({super.key, required this.token});

  @override
  _ProfPageState createState() => _ProfPageState();
}

class _ProfPageState extends State<ProfPage> {
  final MobileScannerController cameraController = MobileScannerController();
  bool isProcessing = false;

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  Future<Position?> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Active la localisation')),
      );
      return null;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Autorisation de localisation refusée')),
        );
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Autorisation refusée définitivement')),
      );
      return null;
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  Future<void> sendBeaconData(String qrData) async {
    if (isProcessing) return;
    setState(() => isProcessing = true);

    Position? position = await _getCurrentLocation();
    if (position == null) {
      setState(() => isProcessing = false);
      return;
    }

    try {
      Uri url = Uri.parse(qrData);

      final client = http.Client();

      final response = await client.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: jsonEncode({
          'latitude': position.latitude,
          'longitude': position.longitude,
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Balise mise à jour avec succès !')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur serveur: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur réseau: $e')),
      );
    } finally {
      setState(() => isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Espace prof'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flip_camera_ios),
            onPressed: () => cameraController.switchCamera(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Card(
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Text(
                  "Scannez un QR code de balise pour enregistrer sa position GPS.",
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  children: [
                    MobileScanner(
                      controller: cameraController,
                      onDetect: (capture) {
                        for (final barcode in capture.barcodes) {
                          final code = barcode.rawValue;
                          if (code != null) {
                            sendBeaconData(code);
                            break;
                          }
                        }
                      },
                    ),
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 16,
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Icon(
                                Icons.qr_code_scanner,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  "Cadrez le QR code dans la zone de scan.",
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (isProcessing)
                      const Positioned.fill(
                        child: ColoredBox(
                          color: Colors.black45,
                          child: Center(child: CircularProgressIndicator()),
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