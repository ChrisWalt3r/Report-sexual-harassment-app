import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import '../services/imgbb_service.dart';
import '../services/cloudinary_service.dart';
import '../constants/app_colors.dart';

class ReportFormScreen extends StatefulWidget {
  const ReportFormScreen({super.key});

  @override
  State<ReportFormScreen> createState() => _ReportFormScreenState();
}

class _ReportFormScreenState extends State<ReportFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _perpetratorController = TextEditingController();
  final _witnessesController = TextEditingController();
  final _responseController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  final Set<String> _selectedIncidentTypes = {};
  final TextEditingController _otherTypeController = TextEditingController();
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String _uploadStatus = '';
  final List<File> _selectedImages = [];
  final List<File> _selectedVideos = [];
  final List<File> _selectedAudios = [];

  // Audio recording state
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  bool _isRecording = false;
  bool _isPlaying = false;
  String? _currentlyPlayingPath;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;

  // Incident types aligned with MUST Anti-Sexual Harassment Policy definitions
  final List<Map<String, dynamic>> _incidentTypes = [
    {
      'name': 'Quid Pro Quo',
      'icon': Icons.swap_horiz,
      'description': 'Sexual favors demanded in exchange for benefits',
    },
    {
      'name': 'Hostile Environment',
      'icon': Icons.dangerous,
      'description': 'Conduct making work/study environment intolerable',
    },
    {
      'name': 'Unwelcome Physical Conduct',
      'icon': Icons.front_hand,
      'description': 'Unwanted touching, grabbing, or physical contact',
    },
    {
      'name': 'Unwelcome Verbal Conduct',
      'icon': Icons.record_voice_over,
      'description': 'Sexual comments, jokes, or advances',
    },
    {
      'name': 'Unwelcome Non-Verbal Conduct',
      'icon': Icons.visibility,
      'description':
          'Obscene gestures, indecent exposure, sending explicit content',
    },
    {
      'name': 'Sexual Assault',
      'icon': Icons.warning_amber,
      'description': 'Non-consensual sexual touching or contact',
    },
    {
      'name': 'Sexual Exploitation',
      'icon': Icons.camera_alt,
      'description': 'Recording/sharing sexual content, voyeurism',
    },
    {
      'name': 'Stalking',
      'icon': Icons.person_search,
      'description': 'Repeated unwanted contact or following',
    },
    {
      'name': 'Dating Violence',
      'icon': Icons.heart_broken,
      'description': 'Abusive behavior by intimate partner',
    },
    {
      'name': 'Online/Cyber Harassment',
      'icon': Icons.computer,
      'description': 'Harassment via electronic means',
    },
    {
      'name': 'Other',
      'icon': Icons.more_horiz,
      'description': 'Other forms of sexual harassment',
    },
  ];

  @override
  void dispose() {
    _descriptionController.dispose();
    _locationController.dispose();
    _perpetratorController.dispose();
    _witnessesController.dispose();
    _responseController.dispose();
    _otherTypeController.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _recordingTimer?.cancel();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage();
    setState(() {
      _selectedImages.addAll(images.map((xfile) => File(xfile.path)));
    });
  }

  Future<void> _pickVideo() async {
    final ImagePicker picker = ImagePicker();
    final XFile? video = await picker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      setState(() {
        _selectedVideos.add(File(video.path));
      });
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryGreen,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryGreen,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  void _removeVideo(int index) {
    setState(() {
      _selectedVideos.removeAt(index);
    });
  }

  void _removeAudio(int index) {
    setState(() {
      _selectedAudios.removeAt(index);
    });
  }

  Future<void> _playAudio(String path) async {
    try {
      if (_isPlaying && _currentlyPlayingPath == path) {
        await _audioPlayer.stop();
        setState(() {
          _isPlaying = false;
          _currentlyPlayingPath = null;
        });
      } else {
        if (_isPlaying) {
          await _audioPlayer.stop();
        }
        await _audioPlayer.play(DeviceFileSource(path));
        setState(() {
          _isPlaying = true;
          _currentlyPlayingPath = path;
        });

        _audioPlayer.onPlayerComplete.listen((_) {
          setState(() {
            _isPlaying = false;
            _currentlyPlayingPath = null;
          });
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error playing audio: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return '$twoDigitMinutes:$twoDigitSeconds';
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final tempDir = await getTemporaryDirectory();
        final filePath =
            '${tempDir.path}/audio_evidence_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _audioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 128000,
            sampleRate: 44100,
          ),
          path: filePath,
        );

        setState(() {
          _isRecording = true;
          _recordingDuration = Duration.zero;
        });

        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() {
            _recordingDuration += const Duration(seconds: 1);
          });
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Microphone permission is required to record audio',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting recording: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    try {
      _recordingTimer?.cancel();
      final path = await _audioRecorder.stop();
      if (path != null) {
        setState(() {
          _selectedAudios.add(File(path));
          _isRecording = false;
          _recordingDuration = Duration.zero;
        });
      }
    } catch (e) {
      setState(() {
        _isRecording = false;
        _recordingDuration = Duration.zero;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error stopping recording: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Generate a unique tracking token for anonymous reports
  String _generateTrackingToken() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    final token =
        List.generate(12, (_) => chars[random.nextInt(chars.length)]).join();
    // Format as XXXX-XXXX-XXXX for readability
    return '${token.substring(0, 4)}-${token.substring(4, 8)}-${token.substring(8, 12)}';
  }

  /// Show dialog with tracking token for anonymous reports
  Future<void> _showTrackingTokenDialog(String token) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        bool copied = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_circle_outline_rounded,
                      size: 48,
                      color: Colors.green.shade600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Report Submitted!',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Your anonymous report has been submitted successfully. Save this tracking token to check your report status later.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primaryGreen.withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Your Tracking Token',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.primaryGreen,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SelectableText(
                          token,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryGreen,
                            letterSpacing: 2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: token));
                        setDialogState(() {
                          copied = true;
                        });
                      },
                      icon: Icon(
                        copied ? Icons.check_rounded : Icons.copy_rounded,
                        size: 18,
                      ),
                      label: Text(copied ? 'Copied!' : 'Copy Token'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor:
                            copied ? Colors.green : AppColors.primaryGreen,
                        side: BorderSide(
                          color:
                              copied
                                  ? Colors.green
                                  : AppColors.primaryGreen.withOpacity(0.4),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 18,
                          color: Colors.orange.shade700,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Save this token! You won\'t be able to retrieve it later.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange.shade800,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Done',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Upload images to ImgBB
  Future<List<String>> _uploadImages(List<File> files) async {
    List<String> urls = [];

    for (var file in files) {
      final url = await ImgbbService.uploadImage(file.path);
      if (url != null) {
        urls.add(url);
      }
    }

    return urls;
  }

  /// Upload videos to Cloudinary
  Future<List<String>> _uploadVideos(List<File> files) async {
    List<String> urls = [];

    for (var file in files) {
      print('DEBUG: Attempting video upload for: ${file.path}');
      final url = await CloudinaryService.uploadVideo(file.path);
      if (url != null) {
        urls.add(url);
        print('DEBUG: Video upload succeeded: $url');
      } else {
        print(
          'DEBUG: Video upload FAILED. Error: ${CloudinaryService.lastError}',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Video upload failed: ${CloudinaryService.lastError ?? "Unknown error"}',
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    }

    return urls;
  }

  /// Upload audio files to Cloudinary
  Future<List<String>> _uploadAudios(List<File> files) async {
    List<String> urls = [];

    for (var file in files) {
      print('DEBUG: Attempting audio upload for: ${file.path}');
      final url = await CloudinaryService.uploadAudio(file.path);
      if (url != null) {
        urls.add(url);
        print('DEBUG: Audio upload succeeded: $url');
      } else {
        print(
          'DEBUG: Audio upload FAILED. Error: ${CloudinaryService.lastError}',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Audio upload failed: ${CloudinaryService.lastError ?? "Unknown error"}',
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    }

    return urls;
  }

  Future<String> _getDeviceId() async {
    const storageKey = 'anonymous_device_id';
    String? storedId = await _secureStorage.read(key: storageKey);

    if (storedId == null || storedId.isEmpty) {
      storedId = const Uuid().v4();
      await _secureStorage.write(key: storageKey, value: storedId);
    }

    return storedId;
  }

  Future<void> _submitReport() async {
    if (_formKey.currentState!.validate()) {
      // Build final list of selected types
      final List<String> incidentTypes = _selectedIncidentTypes.toList();
      if (_selectedIncidentTypes.contains('Other')) {
        final customType = _otherTypeController.text.trim();
        if (customType.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please specify the incident type for "Other"'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }
        incidentTypes.remove('Other');
        incidentTypes.add(customType);
      }
      final String incidentTypeString = incidentTypes.join(', ');

      // Check internet connectivity
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult.contains(ConnectivityResult.none)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.wifi_off, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Internet connection required to submit report',
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      // ---------------- DEVICE ID LIMIT CHECK ----------------
      final user = FirebaseAuth.instance.currentUser;
      final bool isAnonymous = user == null;
      String? deviceId;

      if (isAnonymous) {
        setState(() {
          _isUploading = true;
          _uploadStatus = 'Checking device permissions...';
        });

        try {
          deviceId = await _getDeviceId();
          final snapshot =
              await FirebaseFirestore.instance
                  .collection('reports')
                  .where('deviceId', isEqualTo: deviceId)
                  .get();

          if (snapshot.docs.length >= 2) {
            setState(() => _isUploading = false);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Device Limit Reached: You have submitted 2 anonymous reports. Please sign up or log in to submit more.',
                  ),
                  backgroundColor: AppColors.error,
                  duration: Duration(seconds: 6),
                ),
              );
            }
            return; // Block submission
          }
        } catch (e) {
          setState(() => _isUploading = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to check device ID: $e'),
                backgroundColor: AppColors.error,
              ),
            );
          }
          return;
        }
      }

      setState(() {
        _isUploading = true;
        _uploadProgress = 0.0;
        _uploadStatus = 'Preparing upload...';
      });

      try {
        List<String> imageUrls = [];
        if (_selectedImages.isNotEmpty) {
          setState(() {
            _uploadStatus = 'Uploading images...';
          });
          imageUrls = await _uploadImages(_selectedImages);
          if (imageUrls.length < _selectedImages.length) {
            print(
              'WARNING: Only ${imageUrls.length}/${_selectedImages.length} images uploaded',
            );
          }
          setState(() {
            _uploadProgress = 0.4;
          });
        }
        List<String> videoUrls = [];
        if (_selectedVideos.isNotEmpty) {
          setState(() {
            _uploadStatus = 'Uploading videos...';
          });
          print('DEBUG: Uploading ${_selectedVideos.length} videos');
          videoUrls = await _uploadVideos(_selectedVideos);
          print(
            'DEBUG: Video upload complete. Got ${videoUrls.length} URLs: $videoUrls',
          );
          if (videoUrls.length < _selectedVideos.length) {
            print(
              'WARNING: Only ${videoUrls.length}/${_selectedVideos.length} videos uploaded',
            );
          }
          setState(() {
            _uploadProgress = 0.55;
          });
        }

        List<String> audioUrls = [];
        if (_selectedAudios.isNotEmpty) {
          setState(() {
            _uploadStatus = 'Uploading audio recordings...';
          });
          print('DEBUG: Uploading ${_selectedAudios.length} audios');
          for (var a in _selectedAudios) {
            print(
              'DEBUG: Audio file path=${a.path}, exists=${await a.exists()}, size=${await a.length()} bytes',
            );
          }
          audioUrls = await _uploadAudios(_selectedAudios);
          print(
            'DEBUG: Audio upload complete. Got ${audioUrls.length} URLs: $audioUrls',
          );
          if (audioUrls.length < _selectedAudios.length) {
            print(
              'WARNING: Only ${audioUrls.length}/${_selectedAudios.length} audios uploaded',
            );
          }
          setState(() {
            _uploadProgress = 0.7;
          });
        }

        // Warn user if some evidence failed to upload
        final int totalSelected =
            _selectedImages.length +
            _selectedVideos.length +
            _selectedAudios.length;
        final int totalUploaded =
            imageUrls.length + videoUrls.length + audioUrls.length;
        if (totalSelected > 0 && totalUploaded < totalSelected) {
          if (mounted) {
            final bool proceed =
                await showDialog<bool>(
                  context: context,
                  builder:
                      (ctx) => AlertDialog(
                        title: const Text('Upload Warning'),
                        content: Text(
                          '$totalUploaded out of $totalSelected evidence files uploaded successfully. '
                          '${totalSelected - totalUploaded} file(s) failed to upload.\n\n'
                          'Do you want to submit the report anyway?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Submit Anyway'),
                          ),
                        ],
                      ),
                ) ??
                false;
            if (!proceed) {
              setState(() {
                _isUploading = false;
                _uploadProgress = 0.0;
                _uploadStatus = '';
              });
              return;
            }
          }
        }
        setState(() {
          _uploadStatus = 'Submitting report...';
          _uploadProgress = 0.85;
        });

        // Get current user ID (handled above)

        // Generate tracking token for anonymous reports
        final String? trackingToken =
            isAnonymous ? _generateTrackingToken() : null;

        await FirebaseFirestore.instance.collection('reports').add({
          'userId': user?.uid, // Add userId for filtering
          'deviceId': deviceId, // Store device ID to enforce anonymous limit
          'description': _descriptionController.text,
          'location': _locationController.text,
          'date': _selectedDate?.toIso8601String(),
          'time':
              _selectedTime != null
                  ? '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}'
                  : null,
          'perpetratorInfo':
              _perpetratorController.text.trim().isNotEmpty
                  ? _perpetratorController.text.trim()
                  : null,
          'witnesses':
              _witnessesController.text.trim().isNotEmpty
                  ? _witnessesController.text.trim()
                  : null,
          'complainantResponse':
              _responseController.text.trim().isNotEmpty
                  ? _responseController.text.trim()
                  : null,
          'incidentType': incidentTypeString,
          'incidentTypes': incidentTypes, // Store as list for structured access
          'category': incidentTypeString, // Combined category string
          'imageUrls': imageUrls,
          'videoUrls': videoUrls,
          'audioUrls': audioUrls,
          'timestamp': FieldValue.serverTimestamp(),
          'createdAt':
              FieldValue.serverTimestamp(), // Add createdAt for ordering
          'status': 'pending',
          'isAnonymous': isAnonymous,
          if (trackingToken != null) 'trackingToken': trackingToken,
        });

        setState(() {
          _uploadProgress = 1.0;
          _uploadStatus = 'Upload complete!';
        });

        if (mounted) {
          if (isAnonymous && trackingToken != null) {
            // Show tracking token dialog for anonymous reports
            setState(() {
              _isUploading = false;
              _uploadProgress = 0.0;
              _uploadStatus = '';
            });
            await _showTrackingTokenDialog(trackingToken);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Report submitted successfully'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.pop(context);
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error submitting report: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isUploading = false;
            _uploadProgress = 0.0;
            _uploadStatus = '';
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Report Incident',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        foregroundColor: Colors.white,
        elevation: 0,
        backgroundColor: AppColors.primaryGreen,
      ),
      body:
          _isUploading
              ? Center(
                child: Container(
                  padding: const EdgeInsets.all(32),
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryGreen.withOpacity(0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 100,
                        height: 100,
                        child: CircularProgressIndicator(
                          value: _uploadProgress,
                          color: AppColors.primaryGreen,
                          strokeWidth: 8,
                          backgroundColor: Colors.grey[200],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        '${(_uploadProgress * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Uploading your report...',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _uploadStatus,
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
              : Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: MediaQuery.of(context).size.height - 200,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Incident Type Section
                        _buildSectionTitle('Type of Incident', Icons.category),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: DropdownButtonFormField<String>(
                            decoration: InputDecoration(
                              hintText: 'Select incident type...',
                              hintStyle: TextStyle(color: Colors.grey[400]),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.all(16),
                              prefixIcon: Icon(
                                Icons.category,
                                color: AppColors.royalBlue,
                              ),
                            ),
                            value:
                                _selectedIncidentTypes.isEmpty
                                    ? null
                                    : _selectedIncidentTypes.first,
                            isExpanded: true,
                            items:
                                _incidentTypes.map((type) {
                                  return DropdownMenuItem<String>(
                                    value: type['name'],
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          type['icon'],
                                          size: 18,
                                          color: AppColors.royalBlue,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            type['name'],
                                            style: const TextStyle(
                                              fontSize: 14,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                            onChanged: (String? value) {
                              setState(() {
                                _selectedIncidentTypes.clear();
                                if (value != null) {
                                  _selectedIncidentTypes.add(value);
                                }
                              });
                            },
                            validator:
                                (value) =>
                                    value == null
                                        ? 'Please select an incident type'
                                        : null,
                          ),
                        ),

                        // Custom "Other" text field
                        if (_selectedIncidentTypes.contains('Other')) ...[
                          const SizedBox(height: 12),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: TextFormField(
                              controller: _otherTypeController,
                              decoration: InputDecoration(
                                hintText: 'Please specify the incident type...',
                                hintStyle: TextStyle(color: Colors.grey[400]),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.all(16),
                                prefixIcon: Icon(
                                  Icons.edit_rounded,
                                  color: AppColors.royalBlue,
                                ),
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 24),

                        // Description Section
                        _buildSectionTitle('Description', Icons.description),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: TextFormField(
                            controller: _descriptionController,
                            decoration: InputDecoration(
                              hintText: 'Describe what happened...',
                              hintStyle: TextStyle(color: Colors.grey[400]),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.all(16),
                            ),
                            maxLines: 5,
                            validator:
                                (value) =>
                                    value?.isEmpty ?? true
                                        ? 'Please enter description'
                                        : null,
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Location Section
                        _buildSectionTitle('Location', Icons.location_on),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: TextFormField(
                            controller: _locationController,
                            decoration: InputDecoration(
                              hintText: 'Where did this happen?',
                              hintStyle: TextStyle(color: Colors.grey[400]),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              prefixIcon: Icon(
                                Icons.place,
                                color: Colors.grey[400],
                              ),
                              contentPadding: const EdgeInsets.all(16),
                            ),
                            validator:
                                (value) =>
                                    value?.isEmpty ?? true
                                        ? 'Please enter location'
                                        : null,
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Date Section
                        _buildSectionTitle(
                          'Date of Incident',
                          Icons.calendar_month,
                        ),
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: _selectDate,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.royalBlue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.calendar_today,
                                    color: AppColors.royalBlue,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    _selectedDate == null
                                        ? 'Select date'
                                        : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color:
                                          _selectedDate == null
                                              ? Colors.grey[400]
                                              : Colors.black87,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  size: 16,
                                  color: Colors.grey[400],
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Evidence/Attachment Section
                        _buildSectionTitle(
                          'Attach Evidence (Optional)',
                          Icons.attach_file,
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Attachment buttons
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _pickImages,
                                      icon: const Icon(
                                        Icons.photo_library,
                                        size: 18,
                                      ),
                                      label: const Text('Photos'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primaryGreen,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _pickVideo,
                                      icon: const Icon(
                                        Icons.videocam,
                                        size: 18,
                                      ),
                                      label: const Text('Video'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.royalBlue,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _toggleRecording,
                                      icon: Icon(
                                        _isRecording ? Icons.stop : Icons.mic,
                                        size: 18,
                                      ),
                                      label: Text(
                                        _isRecording ? 'Stop' : 'Record',
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            _isRecording
                                                ? Colors.red
                                                : AppColors.secondaryOrange,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              // Recording indicator
                              if (_isRecording) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.red.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 12,
                                        height: 12,
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Recording: ${_formatDuration(_recordingDuration)}',
                                        style: const TextStyle(
                                          color: Colors.red,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              // Selected images
                              if (_selectedImages.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                Text(
                                  'Selected Photos (${_selectedImages.length})',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  height: 80,
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: _selectedImages.length,
                                    itemBuilder: (context, index) {
                                      return Container(
                                        margin: const EdgeInsets.only(right: 8),
                                        child: Stack(
                                          children: [
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: Image.file(
                                                _selectedImages[index],
                                                width: 80,
                                                height: 80,
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                            Positioned(
                                              top: 4,
                                              right: 4,
                                              child: GestureDetector(
                                                onTap:
                                                    () => _removeImage(index),
                                                child: Container(
                                                  padding: const EdgeInsets.all(
                                                    4,
                                                  ),
                                                  decoration:
                                                      const BoxDecoration(
                                                        color: Colors.red,
                                                        shape: BoxShape.circle,
                                                      ),
                                                  child: const Icon(
                                                    Icons.close,
                                                    color: Colors.white,
                                                    size: 12,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],

                              // Selected videos
                              if (_selectedVideos.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                Text(
                                  'Selected Videos (${_selectedVideos.length})',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Column(
                                  children:
                                      _selectedVideos.asMap().entries.map((
                                        entry,
                                      ) {
                                        int index = entry.key;
                                        File video = entry.value;
                                        return Container(
                                          margin: const EdgeInsets.only(
                                            bottom: 8,
                                          ),
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: AppColors.royalBlue
                                                .withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: AppColors.royalBlue
                                                  .withOpacity(0.3),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.videocam,
                                                color: AppColors.royalBlue,
                                                size: 20,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  'Video ${index + 1}',
                                                  style: TextStyle(
                                                    color: AppColors.royalBlue,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                              GestureDetector(
                                                onTap:
                                                    () => _removeVideo(index),
                                                child: Container(
                                                  padding: const EdgeInsets.all(
                                                    4,
                                                  ),
                                                  decoration:
                                                      const BoxDecoration(
                                                        color: Colors.red,
                                                        shape: BoxShape.circle,
                                                      ),
                                                  child: const Icon(
                                                    Icons.close,
                                                    color: Colors.white,
                                                    size: 12,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                ),
                              ],

                              // Selected audio recordings
                              if (_selectedAudios.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                Text(
                                  'Audio Recordings (${_selectedAudios.length})',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Column(
                                  children:
                                      _selectedAudios.asMap().entries.map((
                                        entry,
                                      ) {
                                        int index = entry.key;
                                        File audio = entry.value;
                                        return Container(
                                          margin: const EdgeInsets.only(
                                            bottom: 8,
                                          ),
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: AppColors.secondaryOrange
                                                .withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: AppColors.secondaryOrange
                                                  .withOpacity(0.3),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.mic,
                                                color:
                                                    AppColors.secondaryOrange,
                                                size: 20,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  'Audio Recording ${index + 1}',
                                                  style: TextStyle(
                                                    color:
                                                        AppColors
                                                            .secondaryOrange,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                              GestureDetector(
                                                onTap:
                                                    () =>
                                                        _playAudio(audio.path),
                                                child: Container(
                                                  padding: const EdgeInsets.all(
                                                    6,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        AppColors
                                                            .secondaryOrange,
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: Icon(
                                                    _isPlaying &&
                                                            _currentlyPlayingPath ==
                                                                audio.path
                                                        ? Icons.pause
                                                        : Icons.play_arrow,
                                                    color: Colors.white,
                                                    size: 16,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              GestureDetector(
                                                onTap:
                                                    () => _removeAudio(index),
                                                child: Container(
                                                  padding: const EdgeInsets.all(
                                                    4,
                                                  ),
                                                  decoration:
                                                      const BoxDecoration(
                                                        color: Colors.red,
                                                        shape: BoxShape.circle,
                                                      ),
                                                  child: const Icon(
                                                    Icons.close,
                                                    color: Colors.white,
                                                    size: 12,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                ),
                              ],
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Submit Button
                        Container(
                          width: double.infinity,
                          height: 56,
                          decoration: BoxDecoration(
                            color: AppColors.secondaryOrange,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.secondaryOrange.withOpacity(
                                  0.4,
                                ),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: _submitReport,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.send_rounded),
                                SizedBox(width: 10),
                                Text(
                                  'Submit Report',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.royalBlue),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}
