import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/api_keys.dart';

/// Service for uploading videos and audio to Cloudinary
/// Sign up at https://cloudinary.com and create an unsigned upload preset
class CloudinaryService {
  static const String _cloudName = ApiKeys.cloudinaryCloudName;
  static const String _uploadPreset = ApiKeys.cloudinaryUploadPreset;
  
  static const String _uploadUrl = 'https://api.cloudinary.com/v1_1';

  /// Supported image extensions
  static const List<String> supportedImageExtensions = [
    '.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp', '.tiff', '.svg'
  ];

  /// Check if file is an image
  static bool isImage(String filePath) {
    final ext = filePath.toLowerCase();
    return supportedImageExtensions.any((e) => ext.endsWith(e));
  }

  /// Supported video extensions
  static const List<String> supportedVideoExtensions = [
    '.mp4', '.mov', '.avi', '.mkv', '.webm', '.m4v', '.3gp'
  ];

  /// Supported audio extensions
  static const List<String> supportedAudioExtensions = [
    '.mp3', '.wav', '.aac', '.m4a', '.ogg', '.flac', '.wma', '.opus'
  ];

  /// Check if file is a video
  static bool isVideo(String filePath) {
    final ext = filePath.toLowerCase();
    return supportedVideoExtensions.any((e) => ext.endsWith(e));
  }

  /// Check if file is an audio file
  static bool isAudio(String filePath) {
    final ext = filePath.toLowerCase();
    return supportedAudioExtensions.any((e) => ext.endsWith(e));
  }

  /// Upload a single image to Cloudinary
  /// Returns the URL of the uploaded image or null if failed
  static Future<String?> uploadImage(String imagePath) async {
    try {
      final file = File(imagePath);
      if (!await file.exists()) {
        lastError = 'Image file does not exist at $imagePath';
        print('Cloudinary Error: $lastError');
        return null;
      }

      final fileSize = await file.length();
      print('Cloudinary: Uploading image from $imagePath ($fileSize bytes)');
      print('Cloudinary: Cloud name=$_cloudName, preset=$_uploadPreset');

      final url = Uri.parse('$_uploadUrl/$_cloudName/image/upload');
      
      final request = http.MultipartRequest('POST', url);
      request.fields['upload_preset'] = _uploadPreset;
      request.files.add(await http.MultipartFile.fromPath('file', imagePath));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('Cloudinary: Image upload response status=${response.statusCode}');
      print('Cloudinary: Image upload response body=${response.body}');

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        final imageUrl = jsonResponse['secure_url'] as String?;
        if (imageUrl != null) {
          print('Cloudinary: Image uploaded successfully: $imageUrl');
          lastError = null;
          return imageUrl;
        }
      }
      
      lastError = 'HTTP ${response.statusCode}: ${response.body}';
      print('Cloudinary Error: $lastError');
      return null;
    } catch (e) {
      lastError = 'Exception: $e';
      print('Cloudinary Error: $lastError');
      return null;
    }
  }

  /// Upload image from bytes (for web or when you have image data)
  static Future<String?> uploadImageBytes(List<int> bytes, String filename) async {
    try {
      print('Cloudinary: Uploading image bytes (${bytes.length} bytes)');
      print('Cloudinary: Cloud name=$_cloudName, preset=$_uploadPreset');

      final url = Uri.parse('$_uploadUrl/$_cloudName/image/upload');
      
      final request = http.MultipartRequest('POST', url);
      request.fields['upload_preset'] = _uploadPreset;
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename,
      ));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('Cloudinary: Image bytes upload response status=${response.statusCode}');
      print('Cloudinary: Image bytes upload response body=${response.body}');

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        final imageUrl = jsonResponse['secure_url'] as String?;
        if (imageUrl != null) {
          print('Cloudinary: Image bytes uploaded successfully: $imageUrl');
          lastError = null;
          return imageUrl;
        }
      }
      
      lastError = 'HTTP ${response.statusCode}: ${response.body}';
      print('Cloudinary Error: $lastError');
      return null;
    } catch (e) {
      lastError = 'Exception: $e';
      print('Cloudinary Error: $lastError');
      return null;
    }
  }

  /// Upload a single video to Cloudinary
  /// Returns the URL of the uploaded video or null if failed
  static Future<String?> uploadVideo(String videoPath) async {
    try {
      final file = File(videoPath);
      if (!await file.exists()) {
        lastError = 'Video file does not exist at $videoPath';
        print('Cloudinary Error: $lastError');
        return null;
      }

      final fileSize = await file.length();
      print('Cloudinary: Uploading video from $videoPath ($fileSize bytes)');
      print('Cloudinary: Cloud name=$_cloudName, preset=$_uploadPreset');

      final url = Uri.parse('$_uploadUrl/$_cloudName/video/upload');
      
      final request = http.MultipartRequest('POST', url);
      request.fields['upload_preset'] = _uploadPreset;
      request.files.add(await http.MultipartFile.fromPath('file', videoPath));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('Cloudinary: Video upload response status=${response.statusCode}');
      print('Cloudinary: Video upload response body=${response.body}');

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        final videoUrl = jsonResponse['secure_url'] as String?;
        if (videoUrl != null) {
          print('Cloudinary: Video uploaded successfully: $videoUrl');
          lastError = null;
          return videoUrl;
        }
      }
      
      lastError = 'HTTP ${response.statusCode}: ${response.body}';
      print('Cloudinary Error: $lastError');
      return null;
    } catch (e) {
      lastError = 'Exception: $e';
      print('Cloudinary Error: $lastError');
      return null;
    }
  }

  /// Upload video from bytes
  static Future<String?> uploadVideoBytes(List<int> bytes, String filename) async {
    try {
      final url = Uri.parse('$_uploadUrl/$_cloudName/video/upload');
      
      final request = http.MultipartRequest('POST', url);
      request.fields['upload_preset'] = _uploadPreset;
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename,
      ));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        return jsonResponse['secure_url'] as String?;
      }
      
      print('Cloudinary Error: Failed to upload video bytes');
      return null;
    } catch (e) {
      print('Cloudinary Error: Exception during bytes upload - $e');
      return null;
    }
  }

  /// Upload multiple videos
  /// Returns list of URLs for successfully uploaded videos
  static Future<List<String>> uploadMultipleVideos(List<String> videoPaths) async {
    final List<String> uploadedUrls = [];

    for (final path in videoPaths) {
      if (isVideo(path)) {
        final url = await uploadVideo(path);
        if (url != null) {
          uploadedUrls.add(url);
        }
      } else {
        print('Cloudinary Warning: Skipping non-video file: $path');
      }
    }

    return uploadedUrls;
  }

  /// Upload a single audio file to Cloudinary
  /// Cloudinary handles audio under the "video" resource type
  /// Returns the URL of the uploaded audio or null if failed
  /// Last upload error message for debugging
  static String? lastError;

  static Future<String?> uploadAudio(String audioPath) async {
    try {
      final file = File(audioPath);
      if (!await file.exists()) {
        lastError = 'Audio file does not exist at $audioPath';
        print('Cloudinary Error: $lastError');
        return null;
      }

      final fileSize = await file.length();
      print('Cloudinary: Uploading audio from $audioPath (${fileSize} bytes)');
      print('Cloudinary: Cloud name=$_cloudName, preset=$_uploadPreset');

      // Cloudinary uses the video/upload endpoint for audio files too
      final url = Uri.parse('$_uploadUrl/$_cloudName/video/upload');
      
      final request = http.MultipartRequest('POST', url);
      request.fields['upload_preset'] = _uploadPreset;
      request.files.add(await http.MultipartFile.fromPath('file', audioPath));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('Cloudinary: Audio upload response status=${response.statusCode}');
      print('Cloudinary: Audio upload response body=${response.body}');

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        final audioUrl = jsonResponse['secure_url'] as String?;
        if (audioUrl != null) {
          print('Cloudinary: Audio uploaded successfully: $audioUrl');
          lastError = null;
          return audioUrl;
        }
      }
      
      lastError = 'HTTP ${response.statusCode}: ${response.body}';
      print('Cloudinary Error: $lastError');
      return null;
    } catch (e) {
      lastError = 'Exception: $e';
      print('Cloudinary Error: $lastError');
      return null;
    }
  }

  /// Upload multiple audio files
  /// Returns list of URLs for successfully uploaded audio files
  static Future<List<String>> uploadMultipleAudios(List<String> audioPaths) async {
    final List<String> uploadedUrls = [];

    for (final path in audioPaths) {
      if (isAudio(path)) {
        final url = await uploadAudio(path);
        if (url != null) {
          uploadedUrls.add(url);
        }
      } else {
        print('Cloudinary Warning: Skipping non-audio file: $path');
      }
    }

    return uploadedUrls;
  }

  /// Get video thumbnail URL from Cloudinary video URL
  /// Cloudinary auto-generates thumbnails for videos
  static String? getThumbnailUrl(String videoUrl) {
    try {
      // Convert video URL to thumbnail by changing extension and adding transformation
      // Example: .../video/upload/v123/sample.mp4 -> .../video/upload/so_0,f_jpg/v123/sample.jpg
      if (videoUrl.contains('/video/upload/')) {
        final parts = videoUrl.split('/video/upload/');
        if (parts.length == 2) {
          // Add transformation for thumbnail: start offset 0, format jpg
          return '${parts[0]}/video/upload/so_0,w_400,h_300,c_fill,f_jpg/${parts[1].replaceAll(RegExp(r'\.(mp4|mov|avi|mkv|webm|m4v|3gp)$'), '.jpg')}';
        }
      }
    } catch (e) {
      print('Cloudinary: Could not generate thumbnail URL');
    }
    return null;
  }
}
