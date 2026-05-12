import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'parcours_map.dart';

class ParcoursListPage extends StatefulWidget {
  final String token;

  const ParcoursListPage({super.key, required this.token});

  @override
  State<ParcoursListPage> createState() => _ParcoursListPageState();
}

class _ParcoursListPageState extends State<ParcoursListPage> {
  List<Map<String, dynamic>> maps = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    fetchMaps();
  }

  Future<void> fetchMaps() async {
    try {
      final response = await http.get(
        Uri.parse("https://irina-pestersome-tolerably.ngrok-free.dev/api/maps"),
        headers: {"Authorization": "Bearer ${widget.token}"},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List fetchedMaps =
            (data['member'] ?? data['hydra:member'] ?? []) as List;

        setState(() {
          maps = fetchedMaps.cast<Map<String, dynamic>>();
          loading = false;
        });
      } else {
        setState(() {
          maps = [];
          loading = false;
        });
        debugPrint("Erreur API: ${response.statusCode}");
      }
    } catch (e) {
      setState(() {
        maps = [];
        loading = false;
      });
      debugPrint("Exception: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Parcours disponibles")),
      body: maps.isEmpty
          ? const Center(
              child: Text("Aucun parcours disponible pour le moment."),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: maps.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final m = maps[index];
                final parcoursId = m["id"] ??
                    int.tryParse(m["@id"].toString().split("/").last) ??
                    0;

                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      child: Text("${index + 1}"),
                    ),
                    title: Text(
                      m["name_map"] ?? "Nom inconnu",
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        m["description"] ?? "Aucune description",
                      ),
                    ),
                    trailing: const Icon(Icons.map_outlined),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ParcoursMapPage(
                            parcoursId: parcoursId,
                            token: widget.token,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}