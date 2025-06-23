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
  final double frequencyScore;
  final double brightnessScore;

  BlurResult({
    required this.isBlurry,
    required this.blurPercentage,
    required this.sharpnessPercentage,
    required this.laplacianScore,
    required this.frequencyScore,
    required this.brightnessScore,
  });
}

// Custom blur detection service that provides percentage values
class CustomBlurDetectionService {
  static Future<BlurResult> analyzeImageBlur(File file) async {
    try {
      // Load image
      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image == null) {
        throw Exception('Failed to decode image');
      }

      // Calculate various metrics
      final varianceOfLaplacian = _calculateVarianceOfLaplacian(image);
      final frequencyContent = _calculateFrequencyContent(image);
      final brightness = _calculateBrightness(image);

      // Calculate percentage scores (0-100)
      final laplacianPercentage =
          _normalizeToPercentage(varianceOfLaplacian, 5000);
      final frequencyPercentage =
          _normalizeToPercentage(frequencyContent, 2000);
      final brightnessPercentage = _normalizeToPercentage(brightness, 255);

      // Combined blur percentage (higher = more blurry)
      final combinedBlurPercentage = _calculateCombinedBlurPercentage(
        laplacianPercentage,
        frequencyPercentage,
        brightnessPercentage,
      );

      // Sharpness percentage (inverse of blur)
      final sharpnessPercentage = 100 - combinedBlurPercentage;

      // Determine if image is blurry based on threshold
      final isBlurry = combinedBlurPercentage > 60; // Threshold can be adjusted

      return BlurResult(
        isBlurry: isBlurry,
        blurPercentage: combinedBlurPercentage,
        sharpnessPercentage: sharpnessPercentage,
        laplacianScore: laplacianPercentage,
        frequencyScore: frequencyPercentage,
        brightnessScore: brightnessPercentage,
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

    // Laplacian kernel
    final kernel = [
      [0, -1, 0],
      [-1, 4, -1],
      [0, -1, 0],
    ];

    for (int y = 1; y < height - 1; y++) {
      for (int x = 1; x < width - 1; x++) {
        double laplacian = 0;

        for (int ky = -1; ky <= 1; ky++) {
          for (int kx = -1; kx <= 1; kx++) {
            final pixel = image.getPixel(x + kx, y + ky);
            final gray = (pixel.r * 0.299 + pixel.g * 0.587 + pixel.b * 0.114);
            laplacian += gray * kernel[ky + 1][kx + 1];
          }
        }

        sum += laplacian;
        sumSquared += laplacian * laplacian;
        count++;
      }
    }

    final mean = sum / count;
    final variance = (sumSquared / count) - (mean * mean);
    return variance;
  }

  static double _calculateFrequencyContent(img.Image image) {
    final width = image.width;
    final height = image.height;
    double frequencySum = 0;

    for (int y = 1; y < height - 1; y++) {
      for (int x = 1; x < width - 1; x++) {
        final center = image.getPixel(x, y);
        final right = image.getPixel(x + 1, y);
        final bottom = image.getPixel(x, y + 1);

        final centerGray =
            center.r * 0.299 + center.g * 0.587 + center.b * 0.114;
        final rightGray = right.r * 0.299 + right.g * 0.587 + right.b * 0.114;
        final bottomGray =
            bottom.r * 0.299 + bottom.g * 0.587 + bottom.b * 0.114;

        final dx = (rightGray - centerGray).abs();
        final dy = (bottomGray - centerGray).abs();

        frequencySum += dx + dy;
      }
    }

    return frequencySum / ((width - 1) * (height - 1));
  }

  static double _calculateBrightness(img.Image image) {
    double totalBrightness = 0;
    final pixelCount = image.width * image.height;

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        totalBrightness += (pixel.r + pixel.g + pixel.b) / 3;
      }
    }

    return totalBrightness / pixelCount;
  }

  static double _normalizeToPercentage(double value, double maxValue) {
    return (value / maxValue * 100).clamp(0, 100);
  }

  static double _calculateCombinedBlurPercentage(
    double laplacianPercentage,
    double frequencyPercentage,
    double brightnessPercentage,
  ) {
    // Weighted combination of metrics
    // Lower laplacian and frequency scores indicate more blur
    final laplacianBlur = 100 - laplacianPercentage;
    final frequencyBlur = 100 - frequencyPercentage;

    // Brightness affects blur perception
    final brightnessFactor = brightnessPercentage < 50 ? 1.2 : 1.0;

    final combinedBlur =
        (laplacianBlur * 0.5 + frequencyBlur * 0.5) * brightnessFactor;

    return combinedBlur.clamp(0, 100);
  }
}

// Main blur detection service that combines both approaches
class BlurDetectionService {
  static Future<BlurResult> analyzeImage(File file) async {
    try {
      // Get custom analysis with percentages
      final customResult =
          await CustomBlurDetectionService.analyzeImageBlur(file);

      // Get original package result for comparison
      final originalIsBlurry =
          await original_blur.BlurDetectionService.isImageBlurred(file);

      // You can choose to use either result or combine them
      // For now, we'll use the custom result but you could modify this logic
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
