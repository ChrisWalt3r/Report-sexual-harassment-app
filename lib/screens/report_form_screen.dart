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
  bool _isRecording = false;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;

  // Incident types aligned with MUST Anti-Sexual Harassment Policy definitions
  final List<Map<String, dynamic>> _incidentTypes = [
    {'name': 'Quid Pro Quo', 'icon': Icons.swap_horiz, 'description': 'Sexual favors demanded in exchange for benefits'},
    {'name': 'Hostile Environment', 'icon': Icons.dangerous, 'description': 'Conduct making work/study environment intolerable'},
    {'name': 'Unwelcome Physical Conduct', 'icon': Icons.front_hand, 'description': 'Unwanted touching, grabbing, or physical contact'},
    {'name': 'Unwelcome Verbal Conduct', 'icon': Icons.record_voice_over, 'description': 'Sexual comments, jokes, or advances'},
    {'name': 'Unwelcome Non-Verbal Conduct', 'icon': Icons.visibility, 'description': 'Obscene gestures, indecent exposure, sending explicit content'},
    {'name': 'Sexual Assault', 'icon': Icons.warning_amber, 'description': 'Non-consensual sexual touching or contact'},
    {'name': 'Sexual Exploitation', 'icon': Icons.camera_alt, 'description': 'Recording/sharing sexual content, voyeurism'},
    {'name': 'Stalking', 'icon': Icons.person_search, 'description': 'Repeated unwanted contact or following'},
    {'name': 'Dating Violence', 'icon': Icons.heart_broken, 'description': 'Abusive behavior by intimate partner'},
    {'name': 'Online/Cyber Harassment', 'icon': Icons.computer, 'description': 'Harassment via electronic means'},
    {'name': 'Other', 'icon': Icons.more_horiz, 'description': 'Other forms of sexual harassment'},
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
              primary: AppColors.mustBlue,
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
              primary: AppColors.mustBlue,
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
        final filePath = '${tempDir.path}/audio_evidence_${DateTime.now().millisecondsSinceEpoch}.m4a';

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
              content: Text('Microphone permission is required to record audio'),
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

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  /// Generate a unique tracking token for anonymous reports
  String _generateTrackingToken() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    final token = List.generate(12, (_) => chars[random.nextInt(chars.length)]).join();
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                      color: AppColors.mustBlue.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.mustBlue.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Your Tracking Token',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.mustBlue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SelectableText(
                          token,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.mustBlue,
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
                        foregroundColor: copied ? Colors.green : AppColors.mustBlue,
                        side: BorderSide(
                          color: copied ? Colors.green : AppColors.mustBlue.withOpacity(0.4),
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
                        Icon(Icons.warning_amber_rounded, size: 18, color: Colors.orange.shade700),
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
                      backgroundColor: AppColors.mustBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Done',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
        print('DEBUG: Video upload FAILED. Error: ${CloudinaryService.lastError}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Video upload failed: ${CloudinaryService.lastError ?? "Unknown error"}'),
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
        print('DEBUG: Audio upload FAILED. Error: ${CloudinaryService.lastError}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Audio upload failed: ${CloudinaryService.lastError ?? "Unknown error"}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    }
    
    return urls;
  }

  Future<void> _submitReport() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedIncidentTypes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select at least one incident type'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Build final list of selected types
      final List<String> incidentTypes = _selectedIncidentTypes
          .where((t) => t != 'Other')
          .toList();
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
                    child: Text('Internet connection required to submit report'),
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
            print('WARNING: Only ${imageUrls.length}/${_selectedImages.length} images uploaded');
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
          print('DEBUG: Video upload complete. Got ${videoUrls.length} URLs: $videoUrls');
          if (videoUrls.length < _selectedVideos.length) {
            print('WARNING: Only ${videoUrls.length}/${_selectedVideos.length} videos uploaded');
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
            print('DEBUG: Audio file path=${a.path}, exists=${await a.exists()}, size=${await a.length()} bytes');
          }
          audioUrls = await _uploadAudios(_selectedAudios);
          print('DEBUG: Audio upload complete. Got ${audioUrls.length} URLs: $audioUrls');
          if (audioUrls.length < _selectedAudios.length) {
            print('WARNING: Only ${audioUrls.length}/${_selectedAudios.length} audios uploaded');
          }
          setState(() {
            _uploadProgress = 0.7;
          });
        }

        // Warn user if some evidence failed to upload
        final int totalSelected = _selectedImages.length + _selectedVideos.length + _selectedAudios.length;
        final int totalUploaded = imageUrls.length + videoUrls.length + audioUrls.length;
        if (totalSelected > 0 && totalUploaded < totalSelected) {
          if (mounted) {
            final bool proceed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
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
            ) ?? false;
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

        // Get current user ID
        final user = FirebaseAuth.instance.currentUser;
        final bool isAnonymous = user == null;

        // Generate tracking token for anonymous reports
        final String? trackingToken = isAnonymous ? _generateTrackingToken() : null;

        await FirebaseFirestore.instance.collection('reports').add({
          'userId': user?.uid, // Add userId for filtering
          'description': _descriptionController.text,
          'location': _locationController.text,
          'date': _selectedDate?.toIso8601String(),
          'time': _selectedTime != null 
              ? '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}' 
              : null,
          'perpetratorInfo': _perpetratorController.text.trim().isNotEmpty 
              ? _perpetratorController.text.trim() 
              : null,
          'witnesses': _witnessesController.text.trim().isNotEmpty 
              ? _witnessesController.text.trim() 
              : null,
          'complainantResponse': _responseController.text.trim().isNotEmpty 
              ? _responseController.text.trim() 
              : null,
          'incidentType': incidentTypeString,
          'incidentTypes': incidentTypes, // Store as list for structured access
          'category': incidentTypeString, // Combined category string
          'imageUrls': imageUrls,
          'videoUrls': videoUrls,
          'audioUrls': audioUrls,
          'timestamp': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(), // Add createdAt for ordering
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
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.mustBlue, AppColors.mustBlueMedium],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ),
      body: _isUploading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(32),
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.mustBlue.withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 100,
                              height: 100,
                              child: CircularProgressIndicator(
                                value: _uploadProgress,
                                color: AppColors.mustBlue,
                                strokeWidth: 8,
                                backgroundColor: Colors.grey[200],
                              ),
                            ),
                            Text(
                              '${(_uploadProgress * 100).toInt()}%',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.mustBlue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
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
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                  // Header gradient
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.mustBlue, AppColors.mustBlueMedium],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(30),
                        bottomRight: Radius.circular(30),
                      ),
                    ),
                    child: const Column(
                      children: [
                        Icon(
                          Icons.security,
                          color: Colors.white,
                          size: 40,
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Your voice matters',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'All reports are confidential',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Incident Type Section
                          _buildSectionTitle('Type of Incident', Icons.category),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: _incidentTypes.map((type) {
                              final isSelected = _selectedIncidentTypes.contains(type['name']);
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    if (isSelected) {
                                      _selectedIncidentTypes.remove(type['name']);
                                    } else {
                                      _selectedIncidentTypes.add(type['name']);
                                    }
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.mustBlue
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? AppColors.mustBlue
                                          : Colors.grey[300]!,
                                      width: 2,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: AppColors.mustBlue.withOpacity(0.3),
                                              blurRadius: 8,
                                              offset: const Offset(0, 4),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isSelected
                                            ? Icons.check_circle_rounded
                                            : type['icon'],
                                        size: 20,
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.grey[600],
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        type['name'],
                                        style: TextStyle(
                                          color: isSelected
                                              ? Colors.white
                                              : Colors.grey[800],
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
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
                                    color: AppColors.mustBlue,
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
                              validator: (value) =>
                                  value?.isEmpty ?? true ? 'Please enter description' : null,
                            ),
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // Location & Date Row
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
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
                                          hintText: 'Where?',
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
                                        ),
                                        validator: (value) =>
                                            value?.isEmpty ?? true ? 'Required' : null,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // Date Section
                          _buildSectionTitle('Date of Incident', Icons.calendar_month),
                          const SizedBox(height: 12),
                          GestureDetector(
                            onTap: _selectDate,
                            child: Container(
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
                                      color: AppColors.mustBlue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      Icons.calendar_today,
                                      color: AppColors.mustBlue,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Text(
                                    _selectedDate == null
                                        ? 'Select date'
                                        : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: _selectedDate == null
                                          ? Colors.grey[400]
                                          : Colors.black87,
                                    ),
                                  ),
                                  const Spacer(),
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
                          
                          // Time Section (per MUST Policy Section 8.4)
                          _buildSectionTitle('Time of Incident', Icons.access_time),
                          const SizedBox(height: 12),
                          GestureDetector(
                            onTap: _selectTime,
                            child: Container(
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
                                      color: AppColors.mustBlue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      Icons.access_time,
                                      color: AppColors.mustBlue,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Text(
                                    _selectedTime == null
                                        ? 'Select time (optional)'
                                        : _selectedTime!.format(context),
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: _selectedTime == null
                                          ? Colors.grey[400]
                                          : Colors.black87,
                                    ),
                                  ),
                                  const Spacer(),
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
                          
                          // Perpetrator Information Section (per MUST Policy Section 8.4)
                          _buildSectionTitle('Person(s) Involved', Icons.person_outline),
                          const SizedBox(height: 8),
                          Text(
                            'Name or description of the alleged perpetrator (if known)',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
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
                              controller: _perpetratorController,
                              decoration: InputDecoration(
                                hintText: 'Name, position, or identifying details (optional)',
                                hintStyle: TextStyle(color: Colors.grey[400]),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.all(16),
                              ),
                              maxLines: 2,
                            ),
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // Witnesses Section (per MUST Policy Section 8.4)
                          _buildSectionTitle('Witnesses', Icons.groups),
                          const SizedBox(height: 8),
                          Text(
                            'Names of any witnesses who can support your account',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
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
                              controller: _witnessesController,
                              decoration: InputDecoration(
                                hintText: 'Witness names and contact info (optional)',
                                hintStyle: TextStyle(color: Colors.grey[400]),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.all(16),
                              ),
                              maxLines: 2,
                            ),
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // Your Response Section (per MUST Policy Section 8.4)
                          _buildSectionTitle('Your Response', Icons.reply),
                          const SizedBox(height: 8),
                          Text(
                            'How did you respond to the incident at the time?',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
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
                              controller: _responseController,
                              decoration: InputDecoration(
                                hintText: 'Describe your response to the incident (optional)',
                                hintStyle: TextStyle(color: Colors.grey[400]),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.all(16),
                              ),
                              maxLines: 3,
                            ),
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // Media Section
                          _buildSectionTitle('Evidence (Optional)', Icons.attach_file),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildMediaButton(
                                  icon: Icons.photo_library,
                                  label: 'Add Photos',
                                  onTap: _pickImages,
                                  count: _selectedImages.length,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildMediaButton(
                                  icon: Icons.videocam,
                                  label: 'Add Videos',
                                  onTap: _pickVideo,
                                  count: _selectedVideos.length,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Audio Recording Section
                          _buildAudioRecordingSection(),
                          
                          // Selected Images Preview
                          if (_selectedImages.isNotEmpty) ... [
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 100,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: _selectedImages.length,
                                itemBuilder: (context, index) {
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 10),
                                    child: Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
                                          child: Image.file(
                                            _selectedImages[index],
                                            width: 100,
                                            height: 100,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                        Positioned(
                                          top: 4,
                                          right: 4,
                                          child: GestureDetector(
                                            onTap: () => _removeImage(index),
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: const BoxDecoration(
                                                color: Colors.red,
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.close,
                                                color: Colors.white,
                                                size: 16,
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
                          
                          // Selected Videos Preview
                          if (_selectedVideos.isNotEmpty) ... [
                            const SizedBox(height: 16),
                            ...List.generate(_selectedVideos.length, (index) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppColors.mustBlue.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        Icons.videocam,
                                        color: AppColors.mustBlue,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Video ${index + 1}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () => _removeVideo(index),
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],

                          // Selected Audio Previews
                          if (_selectedAudios.isNotEmpty) ... [
                            const SizedBox(height: 16),
                            ...List.generate(_selectedAudios.length, (index) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.deepPurple.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.audiotrack,
                                        color: Colors.deepPurple,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Audio ${index + 1}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () => _removeAudio(index),
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                          
                          const SizedBox(height: 32),
                          
                          // Submit Button
                          Container(
                            width: double.infinity,
                            height: 56,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppColors.mustGold, AppColors.mustGoldLight],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.mustGold.withOpacity(0.4),
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
                                foregroundColor: AppColors.mustBlue,
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
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.mustBlue),
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

  Widget _buildMediaButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required int count,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: count > 0 ? AppColors.mustBlue : Colors.grey[300]!,
            width: 2,
            style: BorderStyle.solid,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Stack(
              children: [
                Icon(
                  icon,
                  size: 32,
                  color: count > 0 ? AppColors.mustBlue : Colors.grey[400],
                ),
                if (count > 0)
                  Positioned(
                    right: -8,
                    top: -8,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.mustBlue,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$count',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: count > 0 ? AppColors.mustBlue : Colors.grey[600],
                fontWeight: count > 0 ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioRecordingSection() {
    return GestureDetector(
      onTap: _toggleRecording,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _isRecording ? Colors.red.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isRecording
                ? Colors.red
                : _selectedAudios.isNotEmpty
                    ? Colors.deepPurple
                    : Colors.grey[300]!,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: _isRecording
                  ? Colors.red.withOpacity(0.15)
                  : Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Stack(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isRecording
                        ? Colors.red.withOpacity(0.15)
                        : _selectedAudios.isNotEmpty
                            ? Colors.deepPurple.withOpacity(0.1)
                            : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                    size: 28,
                    color: _isRecording
                        ? Colors.red
                        : _selectedAudios.isNotEmpty
                            ? Colors.deepPurple
                            : Colors.grey[400],
                  ),
                ),
                if (_selectedAudios.isNotEmpty && !_isRecording)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: const BoxDecoration(
                        color: Colors.deepPurple,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${_selectedAudios.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isRecording
                        ? 'Recording... Tap to stop'
                        : _selectedAudios.isNotEmpty
                            ? '${_selectedAudios.length} audio recording(s)'
                            : 'Record Audio',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _isRecording
                          ? Colors.red
                          : _selectedAudios.isNotEmpty
                              ? Colors.deepPurple
                              : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isRecording
                        ? _formatDuration(_recordingDuration)
                        : 'Tap to start recording audio evidence',
                    style: TextStyle(
                      fontSize: 12,
                      color: _isRecording ? Colors.red[400] : Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ),
            if (_isRecording)
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.5),
                      blurRadius: 6,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
