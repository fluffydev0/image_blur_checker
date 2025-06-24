import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:blur_detection/blur_detection.dart' as original_blur;
import 'services/blur_detection_service.dart';

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
  BlurResult? _blurResult;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage({required bool fromCamera}) async {
    final XFile? pickedFile = fromCamera
        ? await _picker.pickImage(source: ImageSource.camera)
        : await _picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _isLoading = true;
        _isBlurry = null;
        _blurResult = null;
      });

      final file = File(pickedFile.path);

      try {
        // Using the new blur detection service
        final blurResult = await BlurDetectionService.analyzeImage(file);

        // Also get the original boolean result for comparison
        final isBlurry =
            await original_blur.BlurDetectionService.isImageBlurred(file);

        setState(() {
          _image = file;
          _isBlurry = isBlurry;
          _blurResult = blurResult;
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
          if (_blurResult != null)
            Container(
              padding: const EdgeInsets.all(16.0),
              color: _blurResult!.isBlurry
                  ? Colors.red.shade100
                  : Colors.green.shade100,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _blurResult!.isBlurry ? Icons.blur_on : Icons.blur_off,
                        color:
                            _blurResult!.isBlurry ? Colors.red : Colors.green,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _blurResult!.isBlurry
                            ? 'Image is Blurry'
                            : 'Image is Sharp',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color:
                              _blurResult!.isBlurry ? Colors.red : Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Percentage display
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildPercentageCard(
                        'Blur',
                        _blurResult!.blurPercentage,
                        Colors.red,
                        Icons.blur_on,
                      ),
                      _buildPercentageCard(
                        'Sharpness',
                        _blurResult!.sharpnessPercentage,
                        Colors.green,
                        Icons.blur_off,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Laplacian metric
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildMetricCard(
                          'Laplacian Variance', _blurResult!.laplacianScore),
                    ],
                  ),
                ],
              ),
            ),
        ],
      );
    }
  }

  Widget _buildPercentageCard(
      String label, double percentage, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: color),
          ),
          Text(
            '${percentage.toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String label, double value) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
          Text(
            value.toStringAsFixed(1),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
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
