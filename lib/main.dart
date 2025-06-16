import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

late Interpreter interpreter;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Image Picker(tflite)',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const ImagePickerScreen(),
    );
  }
}

class ImagePickerScreen extends StatefulWidget {
  const ImagePickerScreen({Key? key}) : super(key: key);

  @override
  _ImagePickerScreenState createState() => _ImagePickerScreenState();
}

class _ImagePickerScreenState extends State<ImagePickerScreen> {
  File? _image;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  String _predictionResult = '';
  Future<void>? _modelLoadFuture;

  @override
  void initState() {
    super.initState();
    _modelLoadFuture = loadModel();
  }

  Future<void> loadModel() async {
    interpreter = await Interpreter.fromAsset('model.tflite');
    print('Model loaded');
  }

  Future<void> _pickImage({required bool fromCamera}) async {
    setState(() {
      _isLoading = true;
    });
    final XFile? pickedFile = fromCamera
        ? await _picker.pickImage(source: ImageSource.camera)
        : await _picker.pickImage(source: ImageSource.gallery);

    setState(() {
      _isLoading = false;
      if (pickedFile != null) {
        _image = File(pickedFile.path);
        detectBlur(_image!);
      }
    });
  }

Future<List<List<List<double>>>> preprocess(File imageFile) async {
  final bytes = await imageFile.readAsBytes();
  final image = img.decodeImage(bytes)!;

  final resized = img.copyResize(image, width: 224, height: 224);

  return List.generate(224, (y) {
    return List.generate(224, (x) {
      final pixel = resized.getPixel(x, y);
      // final int pixelValue = pixel is int ? pixel : pixel.toInt();
      final int pixelValue = pixel as int;
      final r = (pixelValue >> 16) & 0xFF;
      final g = (pixelValue >> 8) & 0xFF;
      final b = pixelValue & 0xFF;

      return [r / 255.0, g / 255.0, b / 255.0];
    });
  });
}

  Future<void> detectBlur(File imageFile) async {
    var input = [await preprocess(imageFile)];
    var output = List.filled(1 * 1, 0.0).reshape([1, 1]);
    interpreter.run(input, output);
    setState(() {
      _predictionResult = "Prediction: ${output[0][0]}";
    });
    print("Prediction: ${output[0][0]}");
  }

  Widget _buildImagePreview() {
    if (_image == null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Icon(Icons.image, size: 100.0, color: Colors.grey),
          ),
          const Center(
            child: Padding(
              padding: EdgeInsets.all(8.0),
              child: Text(
                'No Image Selected',
                style: TextStyle(
                  fontSize: 20.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
          ),
          const Center(
            child: Text(
              'Please take or select a photo.',
              style: TextStyle(color: Colors.grey),
            ),
          )
        ],
      );
    } else {
      return Column(
        children: [
          Image.file(_image!),
          const SizedBox(height: 20),
          Text(_predictionResult, style: const TextStyle(fontSize: 18)),
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Image Picker(tflite)'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.image),
            onPressed: () => _pickImage(fromCamera: false),
          ),
          IconButton(
            icon: const Icon(Icons.camera_alt),
            onPressed: () => _pickImage(fromCamera: true),
          ),
        ],
        backgroundColor: Colors.blue,
        elevation: 0.0,
      ),
      body: FutureBuilder<void>(
        future: _modelLoadFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
                child: Text(
                    'Error loading model: \u001b[31m${snapshot.error}\u001b[0m'));
          } else {
            return Stack(
              children: [
                Center(child: _buildImagePreview()),
                if (_isLoading)
                  Container(
                    color: Colors.black.withOpacity(0.5),
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
              ],
            );
          }
        },
      ),
    );
  }
}
