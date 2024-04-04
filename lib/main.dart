import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tflite/flutter_tflite.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

int total = 0;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  final firstCamera = cameras.first;

  runApp(
    MaterialApp(
      theme: ThemeData.dark(),
      debugShowCheckedModeBanner: true,
      home: TakePictureScreen(
        // Pass the appropriate camera to the TakePictureScreen widget.
        camera: firstCamera,
      ),
    ),
  );
}

class TakePictureScreen extends StatefulWidget {
  final CameraDescription camera;
  const TakePictureScreen({
    Key? key, // Making the key parameter nullable
    required this.camera, // Using the required keyword
  }) : super(key: key);

  @override
  _TakePictureScreenState createState() => _TakePictureScreenState();
}

class _TakePictureScreenState extends State<TakePictureScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;

  @override
  void initState() {
    super.initState();
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.high,
    );
    _initializeControllerFuture = _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Center(child: Text('Currency Recognition app'))),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return CameraPreview(_controller);
          } else {
            return Center(child: CircularProgressIndicator());
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.camera_alt),
        onPressed: () async {
          try {
            await _initializeControllerFuture;
            final path = join(
              (await getTemporaryDirectory()).path,
              '${DateTime.now()}.png',
            );
            await _controller.takePicture(); // Remove the path argument
            Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => DisplayPictureScreen(path)));
            // Navigator.push(
            //   context,
            //   MaterialPageRoute(
            //     builder: (context) => DisplayPictureScreen(path),
            //   ),
            // );
          } catch (e) {
            print(e);
          }
        },
      ),
    );
  }
}

class DisplayPictureScreen extends StatefulWidget {
  final String imagePath;
  DisplayPictureScreen(this.imagePath);
  @override
  _DisplayPictureScreenState createState() => _DisplayPictureScreenState();
}

class _DisplayPictureScreenState extends State<DisplayPictureScreen> {
  late List<dynamic> op = [];
  late Image img;
  late FlutterTts flutterTts;

  @override
  void initState() {
    super.initState();
    flutterTts = FlutterTts();
    img = Image.file(File(widget.imagePath));
    loadModel();
    classifyImage(widget.imagePath);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Display the Picture')),
      body: Container(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Expanded(child: Center(child: img)),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> runTextToSpeech(String outputMoney, int totalMoney) async {
    String speakString = '';
    switch (outputMoney) {
      case "10 rupees":
        speakString = "Ten rupees, Your total is now rupees, $totalMoney";
        break;
      case "20 rupees":
        speakString = "Twenty rupees, Your total is now rupees, $totalMoney";
        break;
      case "50 rupees":
        speakString = "Fifty rupees, Your total is now rupees, $totalMoney";
        break;
      case "100 rupees":
        speakString =
            "One Hundred rupees, Your total is now rupees, $totalMoney";
        break;
      case "200 rupees":
        speakString =
            "Two Hundred rupees, Your total is now rupees, $totalMoney";
        break;
      case "500 rupees":
        speakString =
            "Five Hundred rupees, Your total is now rupees, $totalMoney";
        break;
      default:
        speakString = "No note found";
        break;
    }

    await flutterTts.setSpeechRate(0.8);
    await flutterTts.awaitSpeakCompletion(true);
    await flutterTts.speak(speakString);
  }

  Future<void> classifyImage(String image) async {
    var output = await Tflite.runModelOnImage(
      path: image,
      numResults: 5,
      threshold: 0.5,
      imageMean: 127.5,
      imageStd: 127.5,
    );

    setState(() {
      op = output ?? [];
    });

    if (op.isNotEmpty) {
      String label = op[0]["label"];
      int amount = 0;
      switch (label) {
        case "10 rupees":
          amount = 10;
          break;
        case "20 rupees":
          amount = 20;
          break;
        case "50 rupees":
          amount = 50;
          break;
        case "100 rupees":
          amount = 100;
          break;
        case "200 rupees":
          amount = 200;
          break;
        case "500 rupees":
          amount = 500;
          break;
        default:
          break;
      }
      total += amount;
      runTextToSpeech(label, total);
    } else {
      runTextToSpeech("No note found", total);
    }
  }

  Future<void> loadModel() async {
    await Tflite.loadModel(
        model: "assets/detect.tflite", labels: "assets/labelmap.txt");
  }

  @override
  void dispose() {
    Tflite.close();
    flutterTts.stop();
    super.dispose();
  }
}
