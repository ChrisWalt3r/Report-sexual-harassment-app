import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/api_keys.dart';

/// Service for uploading images to ImgBB
/// Note: ImgBB only supports images (JPG, PNG, GIF, BMP, WEBP)
/// For videos, we'll need to use a different approach or store video URLs
class ImgbbService {
  static const String _apiKey = ApiKeys.imgbbApiKey;
  static const String _uploadUrl = 'https://api.imgbb.com/1/upload';

  /// Supported image extensions
  static const List<String> supportedImageExtensions = [
    '.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp'
  ];

  /// Supported video extensions (stored as base64 or external links)
  static const List<String> supportedVideoExtensions = [
    '.mp4', '.mov', '.avi', '.mkv', '.webm'
  ];

  /// Check if file is an image
  static bool isImage(String filePath) {
    final ext = filePath.toLowerCase();
    return supportedImageExtensions.any((e) => ext.endsWith(e));
  }

  /// Check if file is a video
  static bool isVideo(String filePath) {
    final ext = filePath.toLowerCase();
    return supportedVideoExtensions.any((e) => ext.endsWith(e));
  }

  /// Upload a single image to ImgBB
  /// Returns the URL of the uploaded image or null if failed
  static Future<String?> uploadImage(String imagePath) async {
    try {
      final file = File(imagePath);
      if (!await file.exists()) {
        print('ImgBB Error: File does not exist at $imagePath');
        return null;
      }

      // Read file and convert to base64
      final bytes = await file.readAsBytes();
      final base64Image = base64Encode(bytes);

      // Make POST request
      final response = await http.post(
        Uri.parse('$_uploadUrl?key=$_apiKey'),
        body: {
          'image': base64Image,
        },
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse['success'] == true) {
          final imageUrl = jsonResponse['data']['url'] as String;
          print('ImgBB: Image uploaded successfully: $imageUrl');
          return imageUrl;
        } else {
          print('ImgBB Error: Upload failed - ${jsonResponse['error']['message']}');
          return null;
        }
      } else {
        print('ImgBB Error: HTTP ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('ImgBB Error: Exception during upload - $e');
      return null;
    }
  }

  /// Upload image from bytes (useful for camera captures)
  static Future<String?> uploadImageBytes(List<int> bytes, {String? filename}) async {
    try {
      final base64Image = base64Encode(bytes);

      final body = <String, String>{
        'image': base64Image,
      };
      if (filename != null) {
        body['name'] = filename;
      }

      final response = await http.post(
        Uri.parse('$_uploadUrl?key=$_apiKey'),
        body: body,
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse['success'] == true) {
          return jsonResponse['data']['url'] as String;
        }
      }
      print('ImgBB Error: Failed to upload image bytes');
      return null;
    } catch (e) {
      print('ImgBB Error: Exception during bytes upload - $e');
      return null;
    }
  }

  /// Upload multiple images
  /// Returns list of URLs for successfully uploaded images
  static Future<List<String>> uploadMultipleImages(List<String> imagePaths) async {
    final List<String> uploadedUrls = [];

    for (final path in imagePaths) {
      if (isImage(path)) {
        final url = await uploadImage(path);
        if (url != null) {
          uploadedUrls.add(url);
        }
      } else {
        print('ImgBB Warning: Skipping non-image file: $path');
      }
    }

    return uploadedUrls;
  }

  /// Upload multiple files (images and videos)
  /// Images are uploaded to ImgBB
  /// Videos are handled separately (returns local path or null for now)
  /// Returns a map with 'images' and 'videos' lists
  static Future<Map<String, List<String>>> uploadFiles(List<String> filePaths) async {
    final List<String> imageUrls = [];
    final List<String> videoPaths = [];

    for (final path in filePaths) {
      if (isImage(path)) {
        final url = await uploadImage(path);
        if (url != null) {
          imageUrls.add(url);
        }
      } else if (isVideo(path)) {
        // For videos, we'll store a placeholder or handle differently
        // ImgBB doesn't support video uploads
        videoPaths.add(path);
        print('ImgBB Note: Video file detected. Videos need alternative storage: $path');
      }
    }

    return {
      'images': imageUrls,
      'videos': videoPaths,
    };
  }

  /// Get image info from ImgBB response
  static Map<String, dynamic>? parseUploadResponse(String responseBody) {
    try {
      final jsonResponse = json.decode(responseBody);
      if (jsonResponse['success'] == true) {
        final data = jsonResponse['data'];
        return {
          'url': data['url'],
          'displayUrl': data['display_url'],
          'thumbnail': data['thumb']?['url'],
          'deleteUrl': data['delete_url'],
          'width': data['width'],
          'height': data['height'],
          'size': data['size'],
        };
      }
    } catch (e) {
      print('ImgBB Error: Failed to parse response - $e');
    }
    return null;
  }
}