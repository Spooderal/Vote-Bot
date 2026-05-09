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
  String text = "Connecting...";
  final player = AudioPlayer();

  Timer? timer;

  int? lastValue;
  int? lastTriggeredValue;

  bool muted = false;

  @override
  void initState() {
    super.initState();

    timer = Timer.periodic(const Duration(seconds: 10), (t) {
      fetchVoteData();
    });

    fetchVoteData();
  }

  Future<void> fetchVoteData() async {
    try {
      final res = await http.get(
        Uri.parse("https://api.earthmc.net/v4/")
      );

      final data = jsonDecode(res.body);
      final remaining = data["voteParty"]["numRemaining"];

      // SOUND LOGIC (exact triggers only)
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

      lastValue = remaining;

      setState(() {
        text = "Votes remaining: $remaining";
      });

    } catch (e) {
      setState(() {
        text = "Failed to load data: $e";
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
            icon: Icon(muted ? Icons.volume_off : Icons.volume_up),
            onPressed: () {
              setState(() {
                muted = !muted;
              });
            },
          )
        ],
      ),
      body: Center(
        child: Text(
          text,
          style: const TextStyle(fontSize: 22),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
