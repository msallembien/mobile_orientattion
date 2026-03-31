
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'home.dart';
import 'student_page.dart';
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  final _codeController = TextEditingController();
  final _pseudoController = TextEditingController();

  bool _loading = false;
  String? _errorMessage;

  bool _isProfessor = true;

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final url = Uri.parse(
      'https://irina-pestersome-tolerably.ngrok-free.dev/api/login_check',
    );

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'username': _usernameController.text,
        'password': _passwordController.text,
      }),
    );

    setState(() => _loading = false);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final token = data['token'];

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => HomePage(token: token),
        ),
      );
    } else {
      setState(() {
        _errorMessage = "Utilisateur ou mot de passe invalide";
      });
    }
  }

  Future<void> _loginStudent() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final baseUrl =
          'https://irina-pestersome-tolerably.ngrok-free.dev';

      // -----------------------
      // GET RACES
      // -----------------------
      final raceResponse = await http.get(
        Uri.parse('$baseUrl/api/races'),
      );

      print("RACES STATUS: ${raceResponse.statusCode}");
      print("RACES BODY: ${raceResponse.body}");

      if (raceResponse.statusCode != 200) {
        throw Exception("Erreur API races");
      }

      final decoded = json.decode(raceResponse.body);

      // ⚠️ API Platform retourne souvent { "hydra:member": [...] }
      final List races = decoded['member'] ?? [];

      final race = races.cast<Map<String, dynamic>?>().firstWhere(
            (r) =>
                r != null &&
                (r['code_race'] ?? r['codeRace'] ?? '') == _codeController.text.trim(),
            orElse: () => null,
          );

      if (race == null) {
        setState(() {
          _loading = false;
          _errorMessage = "Code de course invalide";
        });
        return;
      }

      print("RACE FOUND: $race");

      // -----------------------
      // CREATE RUNNER
      // -----------------------
      final runnerResponse = await http.post(
        Uri.parse('$baseUrl/api/runners'),
        headers: {'Content-Type': 'application/ld+json'},
        body: json.encode({
            'name': _pseudoController.text.trim(),
            'id_race_id': race['@id'], // <-- ici on envoie l'IRI de la course
        }),
      );

      print("RUNNER STATUS: ${runnerResponse.statusCode}");
      print("RUNNER BODY: ${runnerResponse.body}");

      setState(() => _loading = false);

      if (runnerResponse.statusCode == 201 ||
          runnerResponse.statusCode == 200) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => StudentPage(
              runnerId: json.decode(runnerResponse.body)['id'],
              runnerName: json.decode(runnerResponse.body)['name'],
              raceId: race['id'],
            ),
          ),
        );
      } else {
        setState(() {
          _errorMessage = "Erreur création du runner";
        });
      }
    } catch (e) {
      print("ERROR: $e");

      setState(() {
        _loading = false;
        _errorMessage = "Erreur réseau (API inaccessible)";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connexion')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ChoiceChip(
                  label: const Text("Prof"),
                  selected: _isProfessor,
                  onSelected: (_) {
                    setState(() => _isProfessor = true);
                  },
                ),
                const SizedBox(width: 10),
                ChoiceChip(
                  label: const Text("Élève"),
                  selected: !_isProfessor,
                  onSelected: (_) {
                    setState(() => _isProfessor = false);
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_isProfessor) ...[
              TextField(
                controller: _usernameController,
                decoration:
                    const InputDecoration(labelText: 'Username'),
              ),
              TextField(
                controller: _passwordController,
                decoration:
                    const InputDecoration(labelText: 'Password'),
                obscureText: true,
              ),
            ],
            if (!_isProfessor) ...[
              TextField(
                controller: _codeController,
                decoration: const InputDecoration(
                    labelText: 'Code de la course'),
              ),
              TextField(
                controller: _pseudoController,
                decoration:
                    const InputDecoration(labelText: 'Pseudo'),
              ),
            ],
            const SizedBox(height: 20),
            if (_errorMessage != null)
              Text(_errorMessage!,
                  style: const TextStyle(color: Colors.red)),
            ElevatedButton(
              onPressed: _loading
                  ? null
                  : _isProfessor
                      ? _login
                      : _loginStudent,
              child: _loading
                  ? const CircularProgressIndicator()
                  : Text(_isProfessor
                      ? 'Login Prof'
                      : 'Rejoindre'),
            ),
          ],
        ),
      ),
    );
  }
}