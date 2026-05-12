import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class RacesPage extends StatefulWidget {
  final String token;

  const RacesPage({super.key, required this.token});

  @override
  State<RacesPage> createState() => _RacesPageState();
}

class _RacesPageState extends State<RacesPage> {
  final String baseUrl = 'https://irina-pestersome-tolerably.ngrok-free.dev';
  bool _loading = true;
  List<Map<String, dynamic>> _races = [];
  bool _creating = false;

  String get _token => widget.token.trim();

  Map<String, String> get _authHeaders {
    if (_token.isEmpty) {
      throw Exception('JWT Token not found (token vide)');
    }
    return {
      'Authorization': 'Bearer $_token',
      'Accept': 'application/ld+json',
      'ngrok-skip-browser-warning': 'true',
    };
  }

  Future<http.Response> _sendPreservingAuthOnRedirects({
    required String method,
    required String url,
    Map<String, String>? extraHeaders,
    String? body,
  }) async {
    final client = http.Client();
    try {
      Uri current = Uri.parse(url);
      http.Response? last;

      for (int i = 0; i < 5; i++) {
        final req = http.Request(method, current);
        req.followRedirects = false;
        req.headers.addAll(_authHeaders);
        if (extraHeaders != null) req.headers.addAll(extraHeaders);
        if (body != null) req.body = body;

        final streamed = await client.send(req);
        last = await http.Response.fromStream(streamed);

        if (last.statusCode >= 300 && last.statusCode < 400) {
          final location = last.headers['location'];
          if (location == null || location.isEmpty) break;
          current = current.resolve(location);
          continue;
        }

        return last;
      }

      return last ??
          http.Response('Redirect loop or empty response', 599, request: null);
    } finally {
      client.close();
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchRaces();
  }

  Future<void> _fetchRaces() async {
    setState(() {
      _loading = true;
    });

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/races'),
        headers: _authHeaders,
      );

      if (response.statusCode != 200) {
        setState(() {
          _races = [];
          _loading = false;
        });
        return;
      }

      final decoded = json.decode(response.body);

      final List rawList =
          (decoded['member'] ?? decoded['hydra:member'] ?? []) as List;

      final races = rawList.cast<Map<String, dynamic>>();

      final claims = _decodeJwtClaims(_token);
      final profEtab = _extractEstablishmentId(claims);

      final filtered = profEtab == null
          ? races
          : races.where((r) {
              final raceEtab = _extractEstablishmentId(r);
              return raceEtab == null || raceEtab == profEtab;
            }).toList();

      setState(() {
        _races = filtered;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _races = [];
        _loading = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _fetchMaps() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/maps'),
        headers: _authHeaders,
      );

      if (response.statusCode != 200) {
        return [];
      }

      final decoded = json.decode(response.body);

      final List rawList =
          (decoded['member'] ?? decoded['hydra:member'] ?? []) as List;

      return rawList
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Map<String, dynamic>? _decodeJwtClaims(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = base64Url.normalize(parts[1]);
      final jsonStr = utf8.decode(base64Url.decode(payload));
      return json.decode(jsonStr) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  String? _extractEstablishmentId(Object? source) {
    if (source is Map<String, dynamic>) {
      const keys = [
        'establishment_id',
        'establishment',
        'id_school',
        'school',
        'schoolId',
        'school_id',
      ];
      for (final key in keys) {
        final value = source[key];
        if (value == null) continue;
        if (value is String && value.isNotEmpty) return value;
        if (value is int) return value.toString();
        if (value is Map && value['id'] != null) {
          return value['id'].toString();
        }
        if (value is String && value.startsWith('/api/')) {
          return value.split('/').last;
        }
      }
    }
    return null;
  }

  String _generateRaceCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = Random.secure();
    return List.generate(6, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  Future<Map<String, dynamic>> _createRace({
    required Map<String, dynamic> selectedMap,
    required String status,
  }) async {
    final code = _generateRaceCode();
    final mapIri = selectedMap['@id']?.toString();

    final candidates = <Map<String, dynamic>>[
      {
        'codeRace': code,
        'status': status,
        if (mapIri != null) 'map': mapIri,
      },
      {
        'code_race': code,
        'status': status,
        if (mapIri != null) 'map': mapIri,
      },
      {
        'codeRace': code,
        'status': status,
        if (mapIri != null) 'id_map': mapIri,
      },
      {
        'code_race': code,
        'status': status,
        if (mapIri != null) 'id_map': mapIri,
      },
      {
        'codeRace': code,
        'status': status,
        if (mapIri != null) 'idMap': mapIri,
      },
      {
        'code_race': code,
        'status': status,
        if (mapIri != null) 'idMap': mapIri,
      },
    ];

    http.Response? last;
    for (final payload in candidates) {
      last = await _sendPreservingAuthOnRedirects(
        method: 'POST',
        url: '$baseUrl/api/races',
        extraHeaders: {
          'Content-Type': 'application/ld+json',
        },
        body: json.encode(payload),
      );

      if (last.statusCode == 201 || last.statusCode == 200) {
        return json.decode(last.body) as Map<String, dynamic>;
      }
    }

    final body = (last?.body ?? '').trim();
    final bodyPreview = body.length > 300 ? body.substring(0, 300) : body;
    throw Exception('POST /api/races -> ${last?.statusCode}. $bodyPreview');
  }

  Future<void> _openCreateRaceFlow() async {
    if (_creating) return;

    setState(() => _creating = true);

    try {
      final maps = await _fetchMaps();

      final claims = _decodeJwtClaims(_token);
      final profEtab = _extractEstablishmentId(claims);
      final filteredMaps = profEtab == null
          ? maps
          : maps.where((m) {
              final mapEtab = _extractEstablishmentId(m);
              return mapEtab == null || mapEtab == profEtab;
            }).toList();

      if (!mounted) return;

      Map<String, dynamic>? selectedMap =
          filteredMaps.isNotEmpty ? filteredMaps.first : null;
      String status = 'ready';

      final result = await showModalBottomSheet<Map<String, dynamic>?>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setModalState) {
              return Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 8,
                  bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nouvelle course',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "Choisis un parcours. Un code de 6 caractères sera généré.",
                    ),
                    const SizedBox(height: 16),
                    if (filteredMaps.isEmpty)
                      const Text(
                        "Aucun parcours disponible pour ton établissement.",
                      )
                    else
                      DropdownButtonFormField<Map<String, dynamic>>(
                        value: selectedMap,
                        items: filteredMaps
                            .map(
                              (m) => DropdownMenuItem(
                                value: m,
                                child: Text(m['name_map'] ?? m['name'] ?? 'Parcours'),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          setModalState(() => selectedMap = v);
                        },
                        decoration: const InputDecoration(
                          labelText: 'Parcours',
                          prefixIcon: Icon(Icons.map_outlined),
                        ),
                      ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      value: status,
                      items: const [
                        DropdownMenuItem(value: 'ready', child: Text('ready')),
                        DropdownMenuItem(
                          value: 'in_progress',
                          child: Text('in_progress'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setModalState(() => status = v);
                      },
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        prefixIcon: Icon(Icons.tune),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: filteredMaps.isEmpty || selectedMap == null
                          ? null
                          : () {
                              Navigator.pop(
                                context,
                                {
                                  'map': selectedMap,
                                  'status': status,
                                },
                              );
                            },
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Créer et lancer'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => Navigator.pop(context, null),
                      child: const Text('Annuler'),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );

      if (result == null) return;

      final created = await _createRace(
        selectedMap: result['map'] as Map<String, dynamic>,
        status: result['status'] as String,
      );

      if (!mounted) return;

      final code =
          created['code_race'] ?? created['codeRace'] ?? '—';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Course créée. Code: $code')),
      );

      await _fetchRaces();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur création course: $e')),
      );
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text('Courses')),
        body: Center(child: CircularProgressIndicator()),
      );
    }


    return Scaffold(
      appBar: AppBar(
        title: const Text('Courses'),
        actions: [
          IconButton(
            onPressed: _fetchRaces,
            icon: const Icon(Icons.refresh),
            tooltip: 'Rafraîchir',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _creating ? null : _openCreateRaceFlow,
        icon: _creating
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.add),
        label: Text(_creating ? 'Création...' : 'Nouvelle course'),
      ),
      body: _races.isEmpty
          ? const Center(
              child: Text('Aucune course disponible pour votre établissement.'),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _races.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final race = _races[index];
                final code = race['code_race'] ?? race['codeRace'] ?? '-';

                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      child: Text('${index + 1}'),
                    ),
                    title: Text(
                      race['name'] ?? 'Course ${race['id'] ?? ''}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (code != '-')
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text('Code: $code'),
                          ),
                        if (race['description'] != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              race['description'],
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      final code =
                          race['code_race'] ?? race['codeRace'] ?? 'Inconnu';
                      showDialog(
                        context: context,
                        builder: (context) {
                          return AlertDialog(
                            title: const Text('Course'),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(race['name'] ?? 'Course'),
                                const SizedBox(height: 8),
                                Text('Code à communiquer aux élèves : $code'),
                                const SizedBox(height: 8),
                                Text('Status : ${race['status'] ?? '—'}'),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Fermer'),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}

