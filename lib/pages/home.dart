import 'package:flutter/material.dart';
import 'parcours_list.dart';
import 'prof_page.dart';
class HomePage extends StatefulWidget {
  final String token;

  const HomePage({super.key, required this.token});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Accueil"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.pop(context);
            },
          )
        ],
      ),

      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            const Text(
              "Bienvenue 👋",
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            const Text(
              "Tu es connecté à l'application.",
              style: TextStyle(fontSize: 16),
            ),

            const SizedBox(height: 30),

            Card(
              elevation: 4,
              child: ListTile(
                leading: const Icon(Icons.map),
                title: const Text("Voir la carte"),
                subtitle: const Text("Accéder aux parcours"),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ParcoursListPage(
                        token: widget.token,
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 10),

            Card(
              elevation: 4,
              child: ListTile(
                leading: const Icon(Icons.flag),
                title: const Text("Voir les races"),
                subtitle: const Text("Consulter les courses"),
                onTap: () {
                  // navigation future
                },
              ),
            ),

            const SizedBox(height: 10),

            Card(
              elevation: 4,
              child: ListTile(
                leading: const Icon(Icons.qr_code),
                title: const Text("Scanner un QR Code"),
                subtitle: const Text("Valider un beacon"),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProfPage(
                        token: widget.token, // 🔹 Passe ton JWT ici
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}