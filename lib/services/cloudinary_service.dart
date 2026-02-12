import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Service for uploading videos to Cloudinary
/// Sign up at https://cloudinary.com and create an unsigned upload preset
class CloudinaryService {
  // TODO: Replace with your Cloudinary credentials
  // 1. Sign up at https://cloudinary.com
  // 2. Go to Settings > Upload > Upload presets
  // 3. Create an "Unsigned" upload preset
  // 4. Copy your cloud name and preset name below
  static const String _cloudName = 'dc7td9rfj'; // Replace with your cloud name
  static const String _uploadPreset = 'report_videos'; // Replace with your unsigned preset name
  
  static const String _uploadUrl = 'https://api.cloudinary.com/v1_1';

  /// Supported video extensions
  static const List<String> supportedVideoExtensions = [
    '.mp4', '.mov', '.avi', '.mkv', '.webm', '.m4v', '.3gp'
  ];

  /// Check if file is a video
  static bool isVideo(String filePath) {
    final ext = filePath.toLowerCase();
    return supportedVideoExtensions.any((e) => ext.endsWith(e));
  }

  /// Upload a single video to Cloudinary
  /// Returns the URL of the uploaded video or null if failed
  static Future<String?> uploadVideo(String videoPath) async {
    try {
      final file = File(videoPath);
      if (!await file.exists()) {
        print('Cloudinary Error: File does not exist at $videoPath');
        return null;
      }

      final url = Uri.parse('$_uploadUrl/$_cloudName/video/upload');
      
      final request = http.MultipartRequest('POST', url);
      request.fields['upload_preset'] = _uploadPreset;
      request.files.add(await http.MultipartFile.fromPath('file', videoPath));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        final videoUrl = jsonResponse['secure_url'] as String?;
        if (videoUrl != null) {
          print('Cloudinary: Video uploaded successfully: $videoUrl');
          return videoUrl;
        }
      }
      
      print('Cloudinary Error: HTTP ${response.statusCode} - ${response.body}');
      return null;
    } catch (e) {
      print('Cloudinary Error: Exception during upload - $e');
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
