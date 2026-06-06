import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:translator/translator.dart';
import 'map_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// ---------------- WEBVIEW PAGE ----------------

class WebViewPage extends StatefulWidget {
  final String url;
  final String title;

  const WebViewPage({
    super.key,
    required this.url,
    required this.title,
  });

  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  late final WebViewController controller;

  @override
  void initState() {
    super.initState();

    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: WebViewWidget(controller: controller),
    );
  }
}

// ---------------- MAIN PAGE ----------------

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final player = AudioPlayer();
  final translator = GoogleTranslator();

  Timer? dataTimer;
  Timer? countdownTimer;

  bool muted = false;
  int? lastTriggeredValue;

  String voteText = "Loading votes...";
  String playerText = "Loading player count...";
  String queueText = "Checking server status...";
  String resetText = "Loading reset timers...";

  String selectedLanguage = "en";

  final TextEditingController searchController =
      TextEditingController();

  String? searchedPlayer;
  bool? isOnline;

  List<String> currentOnlinePlayers = [];

  Map<String, DateTime> lastSeen = {};

  @override
  void initState() {
    super.initState();

    dataTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => fetchData(),
    );

    countdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => updateResetTimers(),
    );

    fetchData();
    updateResetTimers();
  }

  Future<String> tr(String text) async {
    if (selectedLanguage == "en") {
      return text;
    }

    final result = await translator.translate(
      text,
      to: selectedLanguage,
    );

    return result.text;
  }

  Future<void> fetchData() async {
    try {
      final res = await http.get(
        Uri.parse("https://api.earthmc.net/v4/"),
      ).timeout(const Duration(seconds: 5));

      final data = jsonDecode(res.body);

      await Future.delayed(const Duration(seconds: 2));

      final onlineRes = await http.get(
        Uri.parse("https://api.earthmc.net/v4/online"),
      ).timeout(const Duration(seconds: 5));

      final onlineData = jsonDecode(onlineRes.body);

      final List players = onlineData["players"];

      currentOnlinePlayers = [];

      for (var p in players) {
        currentOnlinePlayers.add(
          p["name"].toString().toLowerCase(),
        );
      }

      if (searchedPlayer != null) {
        final name = searchedPlayer!.toLowerCase();
        final online = currentOnlinePlayers.contains(name);

        isOnline = online;

        if (online) {
          lastSeen[name] = DateTime.now();
        }
      }

      final remaining = data["voteParty"]["numRemaining"];
      final onlinePlayers = data["stats"]["numOnlinePlayers"];
      final maxPlayers = data["stats"]["maxPlayers"];

      final slotsLeft = maxPlayers - onlinePlayers;

      // SOUND ALERTS
      if (!muted && lastTriggeredValue != remaining) {
        if (remaining == 1000) {
          await player.play(
            AssetSource("sounds/1000.wav"),
          );
        } else if (remaining == 500) {
          await player.play(
            AssetSource("sounds/500.wav"),
          );
        } else if (remaining == 100) {
          await player.play(
            AssetSource("sounds/100.wav"),
          );
        } else if (remaining == 0) {
          await player.play(
            AssetSource("sounds/0.wav"),
          );
        }

        lastTriggeredValue = remaining;
      }

      final translatedVote =
          await tr("Votes remaining: $remaining");

      final translatedPlayers = await tr(
        "Players online: $onlinePlayers / $maxPlayers",
      );

      final translatedQueue = slotsLeft > 0
          ? await tr("$slotsLeft slots free")
          : await tr(
              "SERVER FULL / Queue likely active",
            );

      setState(() {
        voteText = translatedVote;
        playerText = translatedPlayers;
        queueText = translatedQueue;
      });
    } catch (e) {
      setState(() {
        voteText = "Failed to load data";
        playerText = "";
        queueText = "$e";
      });
    }
  }

  void searchPlayer(String value) {
    final name = value.trim();

    if (name.isEmpty) return;

    setState(() {
      searchedPlayer = name;

      isOnline = currentOnlinePlayers.contains(
        name.toLowerCase(),
      );

      if (isOnline == true) {
        lastSeen[name.toLowerCase()] = DateTime.now();
      }
    });
  }

  void updateResetTimers() {
    final now = DateTime.now();

    DateTime next1am = DateTime(
      now.year,
      now.month,
      now.day,
      1,
    );

    DateTime next6am = DateTime(
      now.year,
      now.month,
      now.day,
      6,
    );

    if (now.isAfter(next1am)) {
      next1am = next1am.add(
        const Duration(days: 1),
      );
    }

    if (now.isAfter(next6am)) {
      next6am = next6am.add(
        const Duration(days: 1),
      );
    }

    String format(Duration d) {
      String two(int n) =>
          n.toString().padLeft(2, "0");

      return "${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}";
    }

    setState(() {
      resetText =
          "Vote resets:\n\n"
          "minecraftservers.org → ${format(next1am.difference(now))}\n"
          "minerank.com → ${format(next1am.difference(now))}\n"
          "minecraft-mp.com → ${format(next6am.difference(now))}\n"
          "topminecraftservers.org → ${format(next6am.difference(now))}";
    });
  }

  @override
  void dispose() {
    dataTimer?.cancel();
    countdownTimer?.cancel();
    searchController.dispose();
    player.dispose();
    super.dispose();
  }

  String translatedWebUrl(String originalUrl) {
    if (selectedLanguage == "en") {
      return originalUrl;
    }

    return
        "https://translate.google.com/translate?sl=auto&tl=$selectedLanguage&u=$originalUrl";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("EarthMC Unofficial App"),
        actions: [
          IconButton(
            icon: const Icon(Icons.map),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const MapPage(),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(
              muted
                  ? Icons.volume_off
                  : Icons.volume_up,
            ),
            onPressed: () {
              setState(() {
                muted = !muted;
              });
            },
          ),
        ],
      ),

      body: SingleChildScrollView(
        child: Center(
          child: Column(
            children: [
              const SizedBox(height: 20),

              DropdownButton<String>(
                value: selectedLanguage,
                items: const [
                  DropdownMenuItem(
                    value: "en",
                    child: Text("English"),
                  ),
                  DropdownMenuItem(
                    value: "fr",
                    child: Text("Français"),
                  ),
                  DropdownMenuItem(
                    value: "de",
                    child: Text("Deutsch"),
                  ),
                  DropdownMenuItem(
                    value: "es",
                    child: Text("Español"),
                  ),
                  DropdownMenuItem(
                    value: "tr",
                    child: Text("Türkçe"),
                  ),
                  DropdownMenuItem(
                    value: "ja",
                    child: Text("日本語"),
                  ),
                ],
                onChanged: (value) async {
                  if (value == null) return;

                  setState(() {
                    selectedLanguage = value;
                  });

                  fetchData();
                },
              ),

              const SizedBox(height: 20),

              Text(
                voteText,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 20),

              Text(playerText),
              Text(queueText),

              const SizedBox(height: 20),

              Text(
                resetText,
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 25),

              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                ),
                child: TextField(
                  controller: searchController,
                  decoration: const InputDecoration(
                    labelText: "Search player",
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: searchPlayer,
                ),
              ),

              const SizedBox(height: 15),

              if (searchedPlayer != null)
                Text(
                  isOnline == true
                      ? "🟢 $searchedPlayer is ONLINE"
                      : "🔴 $searchedPlayer is OFFLINE",
                  style: const TextStyle(
                    fontSize: 20,
                  ),
                ),

              const SizedBox(height: 25),

              Row(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => WebViewPage(
                            url: translatedWebUrl(
                              "https://earthmc.net/docs/rules",
                            ),
                            title: "Rules",
                          ),
                        ),
                      );
                    },
                    child: const Text("Rules"),
                  ),

                  const SizedBox(width: 15),

                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => WebViewPage(
                            url: translatedWebUrl(
                              "https://earthmc.net/docs",
                            ),
                            title: "Docs",
                          ),
                        ),
                      );
                    },
                    child: const Text("Docs"),
                  ),
                ],
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
