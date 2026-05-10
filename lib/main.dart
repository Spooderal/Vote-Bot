import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';

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

  Timer? timer;

  bool muted = false;

  int? lastTriggeredValue;

  String voteText = "Loading votes...";
  String playerText = "Loading player count...";
  String queueText = "Checking server status...";

  @override
  void initState() {
    super.initState();

    // Refresh every 10 seconds
    timer = Timer.periodic(const Duration(seconds: 10), (t) {
      fetchData();
    });

    // Run instantly on startup
    fetchData();
  }

  Future<void> fetchData() async {
    try {
      final res = await http.get(
        Uri.parse("https://api.earthmc.net/v4/")
      );

      final data = jsonDecode(res.body);

      // Vote data
      final remaining = data["voteParty"]["numRemaining"];

      // Player/server data
      final onlinePlayers = data["stats"]["numOnlinePlayers"];
      final maxPlayers = data["stats"]["maxPlayers"];

      final slotsLeft = maxPlayers - onlinePlayers;

      // SOUND ALERTS (exact values only)
      if (!muted && lastTriggeredValue != remaining) {

        if (remaining == 1000) {
          await player.play(AssetSource("sounds/1000.wav"));
          lastTriggeredValue = remaining;

        } else if (remaining == 500) {
          await player.play(AssetSource("sounds/500.wav"));
          lastTriggeredValue = remaining;

        } else if (remaining == 100) {
          await player.play(AssetSource("sounds/100.wav"));
          lastTriggeredValue = remaining;

        } else if (remaining == 0) {
          await player.play(AssetSource("sounds/0.wav"));
          lastTriggeredValue = remaining;
        }
      }

      setState(() {

        voteText = "Votes remaining: $remaining";

        playerText =
            "Players online: $onlinePlayers / $maxPlayers";

        if (slotsLeft > 0) {
          queueText = "$slotsLeft slots free";
        } else {
          queueText = "SERVER FULL / Queue likely active";
        }

      });

    } catch (e) {

      setState(() {

        voteText = "Failed to load data";
        playerText = "";
        queueText = "$e";

      });

    }
  }

  @override
  void dispose() {
    timer?.cancel();
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title: const Text("EarthMC Live Tracker"),

        actions: [

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

      body: Center(

        child: Column(

          mainAxisAlignment: MainAxisAlignment.center,

          children: [

            Text(
              voteText,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 30),

            Text(
              playerText,
              style: const TextStyle(
                fontSize: 22,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 20),

            Text(
              queueText,
              style: const TextStyle(
                fontSize: 20,
              ),
              textAlign: TextAlign.center,
            ),

          ],
        ),
      ),
    );
  }
}
