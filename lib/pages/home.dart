import 'package:flutter/material.dart';
import 'parcours_list.dart';
import 'prof_page.dart';
import 'races_page.dart';
class HomePage extends StatefulWidget {
  final String token;

  const HomePage({super.key, required this.token});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Widget _buildActionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(icon, color: Theme.of(context).colorScheme.onPrimaryContainer),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Tableau de bord"),
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
        child: ListView(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Bienvenue",
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Accédez rapidement aux outils de gestion et de suivi des parcours.",
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            _buildActionCard(
              context: context,
              icon: Icons.map_outlined,
              title: "Parcours",
              subtitle: "Consulter les cartes et points de passage",
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
            const SizedBox(height: 10),
            _buildActionCard(
              context: context,
              icon: Icons.qr_code_scanner,
              title: "Scanner une balise",
              subtitle: "Mettre a jour la position d'un beacon",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfPage(
                      token: widget.token,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            _buildActionCard(
              context: context,
              icon: Icons.flag_outlined,
              title: "Courses",
              subtitle: "Gérer les courses de votre établissement",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RacesPage(token: widget.token),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}