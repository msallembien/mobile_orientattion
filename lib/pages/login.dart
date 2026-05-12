
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

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _codeController.dispose();
    _pseudoController.dispose();
    super.dispose();
  }

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
      final token = (data['token'] as String).trim();

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
      final List races =
          (decoded['member'] ?? decoded['hydra:member'] ?? []) as List;

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
            'id_race': race['@id'], // <-- ici on envoie l'IRI de la course
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
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mobile Orientation',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Connectez-vous pour accéder à votre espace.',
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                setState(() => _isProfessor = true);
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  color: _isProfessor
                                      ? colors.primaryContainer
                                      : colors.surface,
                                  border: Border.all(
                                    color: _isProfessor
                                        ? colors.primary
                                        : colors.outlineVariant,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.school_outlined,
                                      size: 20,
                                      color: _isProfessor
                                          ? colors.onPrimaryContainer
                                          : colors.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Professeur',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: _isProfessor
                                            ? colors.onPrimaryContainer
                                            : colors.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                setState(() => _isProfessor = false);
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  color: !_isProfessor
                                      ? colors.primaryContainer
                                      : colors.surface,
                                  border: Border.all(
                                    color: !_isProfessor
                                        ? colors.primary
                                        : colors.outlineVariant,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.directions_run_outlined,
                                      size: 20,
                                      color: !_isProfessor
                                          ? colors.onPrimaryContainer
                                          : colors.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Élève',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: !_isProfessor
                                            ? colors.onPrimaryContainer
                                            : colors.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      if (_isProfessor) ...[
                        TextField(
                          controller: _usernameController,
                          decoration: const InputDecoration(
                            labelText: 'Nom d\'utilisateur',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _passwordController,
                          decoration: const InputDecoration(
                            labelText: 'Mot de passe',
                            prefixIcon: Icon(Icons.lock_outline),
                          ),
                          obscureText: true,
                        ),
                      ] else ...[
                        TextField(
                          controller: _codeController,
                          decoration: const InputDecoration(
                            labelText: 'Code de la course',
                            prefixIcon: Icon(Icons.qr_code_2),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _pseudoController,
                          decoration: const InputDecoration(
                            labelText: 'Pseudo',
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                        ),
                      ],
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 14),
                        Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: colors.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      ElevatedButton.icon(
                        onPressed: _loading
                            ? null
                            : _isProfessor
                                ? _login
                                : _loginStudent,
                        icon: _loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Icon(_isProfessor ? Icons.login : Icons.flag_outlined),
                        label: Text(_isProfessor ? 'Se connecter' : 'Rejoindre la course'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
