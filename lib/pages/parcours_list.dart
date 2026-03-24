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
  List maps = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    fetchMaps();
  }

  Future fetchMaps() async {
    try {
      final response = await http.get(
        Uri.parse("https://irina-pestersome-tolerably.ngrok-free.dev/api/maps"),
        headers: {
          "Authorization": "Bearer ${widget.token}"
        },
      );
      final data = json.decode(response.body);
      debugPrint("Réponse API: $data");
      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Vérifie si 'maps' existe et est bien une liste
        final List fetchedMaps = (data['member'] ?? []) as List;

        setState(() {
          maps = fetchedMaps;
          loading = false;
        });
      } else {
        // Gestion d'erreur simple
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
      appBar: AppBar(title: const Text("Parcours")),
      body: ListView.builder(
        itemCount: maps.length,
        itemBuilder: (context, index) {
          final m = maps[index];

          // Assure-toi que les champs existent

          return ListTile(
            title: Text(m["name_map"] ?? "Nom inconnu"),
            subtitle: Text("Description : ${m["description"] ?? 'Aucune'}"),
            trailing: const Icon(Icons.map),
            onTap: () {
              final parcoursId = m["id"] ?? int.tryParse(m["@id"].toString().split("/").last) ?? 0;

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
          );
        },
      ),
    );
  }
}