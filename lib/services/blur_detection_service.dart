import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:blur_detection/blur_detection.dart' as original_blur;
import 'package:image/image.dart' as img;

// Result class to hold blur analysis data
class BlurResult {
  final bool isBlurry;
  final double blurPercentage;
  final double sharpnessPercentage;
  final double laplacianScore;

  BlurResult({
    required this.isBlurry,
    required this.blurPercentage,
    required this.sharpnessPercentage,
    required this.laplacianScore,
  });
}

// Custom blur detection service that uses only Laplacian variance
class CustomBlurDetectionService {
  static Future<BlurResult> analyzeImageBlur(File file) async {
    try {
      // Load image
      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image == null) {
        throw Exception('Failed to decode image');
      }

      // Calculate Laplacian variance
      final varianceOfLaplacian = _calculateVarianceOfLaplacian(image);

      // Calculate percentage score (0-100)
      // Higher variance = sharper image, lower variance = blurrier image
      final laplacianPercentage =
          _normalizeToPercentage(varianceOfLaplacian, 5000);

      // Blur percentage (inverse of sharpness)
      final blurPercentage = 100 - laplacianPercentage;

      // Sharpness percentage
      final sharpnessPercentage = laplacianPercentage;

      // Determine if image is blurry based on threshold
      // Lower laplacian variance indicates more blur
      final isBlurry = laplacianPercentage < 40; // Threshold can be adjusted

      return BlurResult(
        isBlurry: isBlurry,
        blurPercentage: blurPercentage,
        sharpnessPercentage: sharpnessPercentage,
        laplacianScore: laplacianPercentage,
      );
    } catch (e) {
      throw Exception('Error analyzing image: $e');
    }
  }

  static double _calculateVarianceOfLaplacian(img.Image image) {
    final width = image.width;
    final height = image.height;
    double sum = 0;
    double sumSquared = 0;
    int count = 0;

    // Laplacian kernel for edge detection
    final kernel = [
      [0, -1, 0],
      [-1, 4, -1],
      [0, -1, 0],
    ];

    for (int y = 1; y < height - 1; y++) {
      for (int x = 1; x < width - 1; x++) {
        double laplacian = 0;

        // Apply Laplacian kernel
        for (int ky = -1; ky <= 1; ky++) {
          for (int kx = -1; kx <= 1; kx++) {
            final pixel = image.getPixel(x + kx, y + ky);
            // Convert to grayscale using luminance method
            final gray = (pixel.r * 0.299 + pixel.g * 0.587 + pixel.b * 0.114);
            laplacian += gray * kernel[ky + 1][kx + 1];
          }
        }

        sum += laplacian;
        sumSquared += laplacian * laplacian;
        count++;
      }
    }

    // Calculate variance
    final mean = sum / count;
    final variance = (sumSquared / count) - (mean * mean);
    return variance;
  }

  static double _normalizeToPercentage(double value, double maxValue) {
    return (value / maxValue * 100).clamp(0, 100);
  }
}

// Main blur detection service
class BlurDetectionService {
  static Future<BlurResult> analyzeImage(File file) async {
    try {
      // Get custom analysis with Laplacian variance
      final customResult =
          await CustomBlurDetectionService.analyzeImageBlur(file);

      // Get original package result for comparison
      final originalIsBlurry =
          await original_blur.BlurDetectionService.isImageBlurred(file);

      // Return the custom result
      return customResult;
    } catch (e) {
      throw Exception('Error in blur detection: $e');
    }
  }

  // Method to get only the original package result
  static Future<bool> getOriginalAnalysis(File file) async {
    return await original_blur.BlurDetectionService.isImageBlurred(file);
  }

  // Method to get only the custom analysis
  static Future<BlurResult> getCustomAnalysis(File file) async {
    return await CustomBlurDetectionService.analyzeImageBlur(file);
  }
}
