import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:detector_blur_image/blur_detector.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Blur Detector',
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
  bool _isLoading = false;
  bool? _isBlurry;
  final ImagePicker _picker = ImagePicker();

  Future<bool> _requestPermission(bool isCamera) async {
    final status = isCamera
        ? await Permission.camera.request()
        : await Permission.photos.request();

    if (status.isGranted) {
      return true;
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${isCamera ? 'Camera' : 'Photo library'} permission is required to ${isCamera ? 'take' : 'select'} photos'),
          action: SnackBarAction(
            label: 'Settings',
            onPressed: () => openAppSettings(),
          ),
        ),
      );
      return false;
    }
  }

  Future<void> _pickImage({required bool fromCamera}) async {
    final hasPermission = await _requestPermission(fromCamera);
    if (!hasPermission) return;

    final XFile? pickedFile = fromCamera
        ? await _picker.pickImage(source: ImageSource.camera)
        : await _picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _isLoading = true;
        _isBlurry = null;
      });

      final file = File(pickedFile.path);

      try {
        final bool isImageClear = await BlurRadio.evaluateImageQuality(
          imagePath: file.path,
          acceptableBlurThreshold: 50,
        );

        setState(() {
          _image = file;
          _isBlurry = !isImageClear;
          _isLoading = false;
        });
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error detecting blur: ${e.toString()}')),
        );
      }
    }
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: Image.file(_image!),
          ),
          if (_isBlurry != null)
            Container(
              padding: const EdgeInsets.all(16.0),
              color: _isBlurry! ? Colors.red.shade100 : Colors.green.shade100,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isBlurry! ? Icons.blur_on : Icons.blur_off,
                    color: _isBlurry! ? Colors.red : Colors.green,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isBlurry! ? 'Image is Blurry' : 'Image is Sharp',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _isBlurry! ? Colors.red : Colors.green,
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Blur Detector'),
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
      body: Stack(
        children: [
          _buildImagePreview(),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}
