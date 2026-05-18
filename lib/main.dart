import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
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

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {

  final player = AudioPlayer();

  Timer? dataTimer;
  Timer? countdownTimer;

  bool muted = false;
  int? lastTriggeredValue;

  String voteText = "Loading votes...";
  String playerText = "Loading player count...";
  String queueText = "Checking server status...";
  String resetText = "Loading reset timers...";

  final List<String> trackedPlayers = [
    "Fix",
    "K1kimor",
    "Veyronity",
    "SaloCorey",
  ];

  Map<String, bool> playerStatuses = {};

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

      List<String> onlinePlayersList = [];

      for (var p in players) {
        onlinePlayersList.add(
          p["name"].toString().toLowerCase(),
        );
      }

      Map<String, bool> updated = {};

      for (String name in trackedPlayers) {
        updated[name] =
            onlinePlayersList.contains(name.toLowerCase());
      }

      final remaining = data["voteParty"]["numRemaining"];
      final onlinePlayers = data["stats"]["numOnlinePlayers"];
      final maxPlayers = data["stats"]["maxPlayers"];

      final slotsLeft = maxPlayers - onlinePlayers;

      if (!muted && lastTriggeredValue != remaining) {

        if (remaining == 1000) {
          await player.play(AssetSource("sounds/1000.wav"));
        } else if (remaining == 500) {
          await player.play(AssetSource("sounds/500.wav"));
        } else if (remaining == 100) {
          await player.play(AssetSource("sounds/100.wav"));
        } else if (remaining == 0) {
          await player.play(AssetSource("sounds/0.wav"));
        }

        lastTriggeredValue = remaining;
      }

      setState(() {

        playerStatuses = updated;

        voteText = "Votes remaining: $remaining";

        playerText =
            "Players online: $onlinePlayers / $maxPlayers";

        queueText = slotsLeft > 0
            ? "$slotsLeft slots free"
            : "SERVER FULL / Queue likely active";
      });

    } catch (e) {

      setState(() {
        voteText = "Failed to load data";
        playerText = "";
        queueText = "$e";
      });

    }
  }

  void updateResetTimers() {

    final now = DateTime.now();

    DateTime next1am = DateTime(now.year, now.month, now.day, 1);
    DateTime next6am = DateTime(now.year, now.month, now.day, 6);

    if (now.isAfter(next1am)) {
      next1am = next1am.add(const Duration(days: 1));
    }

    if (now.isAfter(next6am)) {
      next6am = next6am.add(const Duration(days: 1));
    }

    Duration diff1 = next1am.difference(now);
    Duration diff6 = next6am.difference(now);

    String format(Duration d) {
      String two(int n) => n.toString().padLeft(2, "0");

      return "${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}";
    }

    setState(() {
      resetText =
          "Vote resets:\n\n"
          "minecraftservers.org → ${format(diff1)}\n"
          "minerank.com → ${format(diff1)}\n"
          "minecraft-mp.com → ${format(diff6)}\n"
          "topminecraftservers.org → ${format(diff6)}";
    });
  }

  @override
  void dispose() {
    dataTimer?.cancel();
    countdownTimer?.cancel();
    player.dispose();
    super.dispose();
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
              muted ? Icons.volume_off : Icons.volume_up,
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

              const SizedBox(height: 25),

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

              const SizedBox(height: 30),

              const Text(
                "Tracked Players",
                style: TextStyle(fontSize: 20),
              ),

              const SizedBox(height: 10),

              ...trackedPlayers.map((name) {
                final online = playerStatuses[name] ?? false;

                return Text(
                  online ? "🟢 $name" : "🔴 $name",
                  style: const TextStyle(fontSize: 18),
                );
              }),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
