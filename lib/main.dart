import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Audio Player',
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late AudioRecorder audioRecord;
  late AudioPlayer audioPlayer;

  List<FileSystemEntity> m4aFiles = [];

  bool isRecording = false;
  bool isAudioPlaying = false;

  String path = 'record/';
  String audioPath = '';

  int? currentlyPlayingIndex;

  @override
  void initState() {
    audioRecord = AudioRecorder();
    audioPlayer = AudioPlayer();
    _initPath();
    audioPlayer.onPlayerStateChanged.listen((event) {
      isAudioPlaying = event == PlayerState.playing;
      setState(() {});
    });

    super.initState();
  }

  @override
  void dispose() {
    audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _initPath() async {
    final appDocumentsDirectory = await getApplicationDocumentsDirectory();
    path = appDocumentsDirectory.path;
    audioPlayer.onPlayerComplete.listen((event) {
      next();
    });
    loadM4AFiles();
  }

  void loadM4AFiles() {
    final Directory directory = Directory(path);
    final List<FileSystemEntity> files = directory.listSync();

    setState(() {
      m4aFiles = files.whereType<File>().where((file) {
        return file.path.toLowerCase().endsWith('.m4a');
      }).toList();
    });
  }

  Future<void> startRecording() async {
    try {
      if (await audioRecord.hasPermission()) {
        await audioRecord.start(const RecordConfig(),
            path: '$path/${DateTime.now().millisecondsSinceEpoch}.m4a');
        setState(() {
          isRecording = true;
        });
      }
    } catch (e) {
      print(e);
    }
  }

  Future<void> stopRecording() async {
    try {
      String? p = await audioRecord.stop();
      loadM4AFiles();
      setState(() {
        isRecording = false;
        audioPath = p!;
      });
    } catch (e) {
      print(e);
    }
  }

  Future<void> playRecording(int index) async {
    try {
      if (currentlyPlayingIndex != null) {
        await audioPlayer.stop();
      }

      Source url = UrlSource(m4aFiles[index].path);
      await audioPlayer.play(url);

      setState(() {
        currentlyPlayingIndex = index;
      });
    } catch (e) {
      print(e);
    }
  }

  Future<void> deleteRecording(int index) async {
    try {
      if (currentlyPlayingIndex == index) {
        await audioPlayer.stop();
        setState(() {
          currentlyPlayingIndex = null;
        });
      }

      final file = m4aFiles[index];
      await file.delete();

      loadM4AFiles();
    } catch (e) {
      print(e);
    }
  }

  Future<void> playPause() async {
    try {
      if (audioPlayer.state == PlayerState.playing) {
        await audioPlayer.pause();
      } else {
        await audioPlayer.resume();
      }
    } catch (e) {
      print(e);
    }
  }

  Future<void> previous() async {
    try {
      if (currentlyPlayingIndex != null && currentlyPlayingIndex! > 0) {
        await audioPlayer.stop();
        playRecording(currentlyPlayingIndex! - 1);
      }
    } catch (e) {
      print(e);
    }
  }

  Future<void> next() async {
    try {
      if (currentlyPlayingIndex != null &&
          currentlyPlayingIndex! < m4aFiles.length - 1) {
        await audioPlayer.stop();
        playRecording(currentlyPlayingIndex! + 1);
      } else if (m4aFiles.isNotEmpty) {
        await audioPlayer.stop();
        playRecording(0);
      }
    } catch (e) {
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audio Recorder'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (isRecording) const Text('Recording in progress'),
          ElevatedButton(
            onPressed: isRecording ? stopRecording : startRecording,
            child: Text(isRecording ? 'Stop Record' : 'Start Record'),
          ),
          const SizedBox(
            height: 5,
          ),
          const Divider(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(File(audioPath).uri.pathSegments.last.toString() ?? ''),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (currentlyPlayingIndex != null &&
                      currentlyPlayingIndex! > 0)
                    IconButton(
                      onPressed: previous,
                      icon: const Icon(Icons.skip_previous),
                    ),
                  IconButton(
                    onPressed: () {
                      playPause();
                    },
                    icon: Icon(
                      isAudioPlaying ? Icons.pause : Icons.play_arrow,
                    ),
                  ),
                  if (currentlyPlayingIndex != null &&
                      currentlyPlayingIndex! < m4aFiles.length - 1)
                    IconButton(
                      onPressed: next,
                      icon: const Icon(Icons.skip_next),
                    ),
                ],
              ),
            ],
          ),
          const Divider(),
          Expanded(
            child: m4aFiles.isEmpty
                ? const Center(child: Text('No M4A files found'))
                : ListView.builder(
                    itemCount: m4aFiles.length,
                    itemBuilder: (context, index) {
                      final file = m4aFiles[index];
                      return ListTile(
                        title: Text(file.uri.pathSegments.last),
                        onTap: () {
                          print('File tapped: ${file.path}');
                          audioPath = file.path;

                          playRecording(index);
                        },
                        trailing: IconButton(
                          onPressed: () {
                            deleteRecording(index);
                          },
                          icon: const Icon(
                            Icons.delete,
                            color: Colors.red,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
