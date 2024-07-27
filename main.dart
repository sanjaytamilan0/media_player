import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';

void main() => runApp(const VideoApp());

/// Stateful widget to fetch and then display video content.
class VideoApp extends StatefulWidget {
  const VideoApp({super.key});

  @override
  _VideoAppState createState() => _VideoAppState();
}

class _VideoAppState extends State<VideoApp> {
  late VideoPlayerController _controller;
  bool _isLooping = false;
  bool _isContinuousPlay = false;
  int _speedIndex = 0;
  Duration? _trimStart;
  Duration? _trimEnd;
  final List<double> _speeds = [
    0.5,
    1.0,
    1.5,
    2.0,
    3.0,
    4.0,
  ];
  bool _isDownloading = false;
  String _downloadProgress = '';

  @override
  void initState() {
    super.initState();
    _initializeVideoPlayer();
  }

  Future<void> _initializeVideoPlayer({String? videoUrl}) async {
    _controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl ??
        'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4'))
      ..initialize().then((_) {
        setState(() {});
      });
    // Add listener to update state when video progress changes
    _controller.addListener(() {
      setState(() {});
      if (_controller.value.position == _controller.value.duration) {
        if (_isContinuousPlay) {
          _controller.seekTo(Duration.zero);
          _controller.play();
        }
      }
      if (_trimEnd != null && _controller.value.position >= _trimEnd!) {
        _controller.pause();
        _controller.seekTo(_trimStart!);
      }
    });
  }

  void _changeSpeed() {
    setState(() {
      _speedIndex = (_speedIndex + 1) % _speeds.length;
      _controller.setPlaybackSpeed(_speeds[_speedIndex]);
    });
  }

  void _setTrimStart() {
    setState(() {
      _trimStart = _controller.value.position;
    });
  }

  void _setTrimEnd() {
    setState(() {
      _trimEnd = _controller.value.position;
    });
  }

  void _applyTrim() {
    setState(() {
      if (_trimStart != null) {
        _controller.seekTo(_trimStart!);
      }
    });
  }

  Future<void> _downloadVideo() async {
    setState(() {
      _isDownloading = true;
    });
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final savePath = '${appDir.path}/video.mp4';
      final dio = Dio();

      await dio.download(
        'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            setState(() {
              _downloadProgress =
                  (received / total * 100).toStringAsFixed(0) + '%';
            });
          }
        },
      );
      setState(() {
        _downloadProgress = 'Download completed';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download completed: $savePath')),
      );
    } catch (e) {
      setState(() {
        _downloadProgress = 'Download failed';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: $e')),
      );
    } finally {
      setState(() {
        _isDownloading = false;
      });
    }
  }

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickVideo(source: ImageSource.gallery);

    if (pickedFile != null) {
      await _controller.dispose();
      _initializeVideoPlayer(videoUrl: pickedFile.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Video Demo',
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Video Editor'),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                _controller.value.isInitialized
                    ? AspectRatio(
                        aspectRatio: _controller.value.aspectRatio,
                        child: VideoPlayer(_controller),
                      )
                    : Container(),
                // Add video progress indicator
                Container(
                  height: 30,
                  child: VideoProgressIndicator(
                    _controller,
                    allowScrubbing: true,
                    colors: const VideoProgressColors(
                      playedColor: Colors.red,
                      bufferedColor: Colors.grey,
                      backgroundColor: Colors.black,
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Trim Start: ${_trimStart != null ? _trimStart.toString().split('.').first : 'Not Set'}',
                    ),
                    const SizedBox(width: 20),
                    Text(
                      'Trim End: ${_trimEnd != null ? _trimEnd.toString().split('.').first : 'Not Set'}',
                    ),
                  ],
                ),
                _isDownloading
                    ? Text('Downloading: $_downloadProgress')
                    : Container(),
              ],
            ),
          ),
        ),
        floatingActionButton: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                FloatingActionButton(
                  onPressed: () {
                    setState(() {
                      _controller.value.isPlaying
                          ? _controller.pause()
                          : _controller.play();
                    });
                  },
                  child: Icon(
                    _controller.value.isPlaying
                        ? Icons.pause
                        : Icons.play_arrow,
                  ),
                ),
                FloatingActionButton(
                  onPressed: () {
                    setState(() {
                      _isLooping = !_isLooping;
                      _controller.setLooping(_isLooping);
                    });
                  },
                  child: Icon(
                    _isLooping ? Icons.loop : Icons.loop_outlined,
                  ),
                ),
                FloatingActionButton(
                  onPressed: _changeSpeed,
                  child: Text(
                    '${_speeds[_speedIndex]}x',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
                FloatingActionButton(
                  onPressed: () {
                    if (mounted) {
                      setState(() {
                        _isContinuousPlay = !_isContinuousPlay;
                      });
                    }
                  },
                  child: Icon(
                    _isContinuousPlay ? Icons.repeat_one : Icons.repeat,
                  ),
                ),
              ],
            ),
            SizedBox(height: 20,),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                FloatingActionButton(
                  onPressed: _setTrimStart,
                  child: const Icon(Icons.playlist_add),
                ),
                FloatingActionButton(
                  onPressed: _setTrimEnd,
                  child: const Icon(Icons.playlist_add_check),
                ),
                FloatingActionButton(
                  onPressed: _applyTrim,
                  child: const Icon(Icons.cut),
                ),
                FloatingActionButton(
                  onPressed: _downloadVideo,
                  child: const Icon(Icons.download),
                ),
                FloatingActionButton(
                  onPressed: _pickVideo,
                  child: const Icon(Icons.video_collection),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
