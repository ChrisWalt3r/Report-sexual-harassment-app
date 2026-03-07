import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../constants/app_colors.dart';
import '../services/imgbb_service.dart';
import '../services/cloudinary_service.dart';

class ReportEditScreen extends StatefulWidget {
  final String reportId;
  final Map<String, dynamic> reportData;
  final bool evidenceOnly;

  const ReportEditScreen({
    super.key,
    required this.reportId,
    required this.reportData,
    this.evidenceOnly = false,
  });

  @override
  State<ReportEditScreen> createState() => _ReportEditScreenState();
}

class _ReportEditScreenState extends State<ReportEditScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late TextEditingController _descriptionController;
  late TextEditingController _locationController;
  late TextEditingController _perpetratorController;
  late TextEditingController _witnessesController;
  late TextEditingController _responseController;
  bool _isSaving = false;

  // Existing attachments from the report
  late List<String> _existingImageUrls;
  late List<String> _existingVideoUrls;
  late List<String> _existingAudioUrls;
  
  // New attachments to upload
  final List<File> _newImages = [];
  final List<File> _newVideos = [];
  final List<File> _newAudios = [];
  
  // URLs marked for removal
  final List<String> _removedImageUrls = [];
  final List<String> _removedVideoUrls = [];
  final List<String> _removedAudioUrls = [];

  // Audio recording state
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController(
      text: widget.reportData['description'] ?? '',
    );
    _locationController = TextEditingController(
      text: widget.reportData['location'] ?? '',
    );
    _perpetratorController = TextEditingController(
      text: widget.reportData['perpetratorInfo'] ?? '',
    );
    _witnessesController = TextEditingController(
      text: widget.reportData['witnesses'] ?? '',
    );
    _responseController = TextEditingController(
      text: widget.reportData['complainantResponse'] ?? '',
    );
    
    // Initialize existing attachments
    _existingImageUrls = List<String>.from(widget.reportData['imageUrls'] ?? []);
    _existingVideoUrls = List<String>.from(widget.reportData['videoUrls'] ?? []);
    _existingAudioUrls = List<String>.from(widget.reportData['audioUrls'] ?? []);
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _locationController.dispose();
    _audioRecorder.dispose();
    _recordingTimer?.cancel();
    _perpetratorController.dispose();
    _witnessesController.dispose();
    _responseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          widget.evidenceOnly ? 'Add Evidence' : 'Edit Report',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.mustBlue, AppColors.mustBlueMedium],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Report Info Card
                _buildSectionCard(
                  title: 'Report Information',
                  icon: Icons.info_outline,
                  child: Column(
                    children: [
                      _buildInfoRow(
                        icon: Icons.category,
                        label: 'Category',
                        value: widget.reportData['category'] ?? 'N/A',
                      ),
                      const Divider(height: 24),
                      _buildStatusRow(
                        widget.reportData['status'] ?? 'Pending',
                      ),
                      const Divider(height: 24),
                      _buildInfoRow(
                        icon: Icons.calendar_today,
                        label: 'Date',
                        value: _formatDate(widget.reportData['date']),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Editable Fields Card (hidden in evidence-only mode)
                if (!widget.evidenceOnly) ...[
                  _buildSectionCard(
                    title: 'Edit Details',
                    icon: Icons.edit_note,
                    child: Column(
                      children: [
                        _buildEditableField(
                          'Location',
                          _locationController,
                          icon: Icons.location_on,
                          hintText: 'Enter location details',
                        ),
                        const SizedBox(height: 20),
                        _buildEditableField(
                          'Description',
                          _descriptionController,
                          maxLines: 5,
                          icon: Icons.description,
                          hintText: 'Describe what happened...',
                        ),
                        const SizedBox(height: 20),
                        _buildEditableField(
                          'Person(s) Involved',
                          _perpetratorController,
                          maxLines: 2,
                          icon: Icons.person_outline,
                          hintText: 'Name, position, or identifying details (optional)',
                        ),
                        const SizedBox(height: 20),
                        _buildEditableField(
                          'Witnesses',
                          _witnessesController,
                          maxLines: 2,
                          icon: Icons.groups,
                          hintText: 'Witness names and contact info (optional)',
                        ),
                        const SizedBox(height: 20),
                        _buildEditableField(
                          'Your Response to Incident',
                          _responseController,
                          maxLines: 3,
                          icon: Icons.reply,
                          hintText: 'How did you respond at the time? (optional)',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                
                if (widget.evidenceOnly)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.mustBlue.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.mustBlue.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: AppColors.mustBlue, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'This report is under review. You can add more evidence but cannot edit other details or remove existing evidence.',
                            style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                          ),
                        ),
                      ],
                    ),
                  ),
                
                // Attachments Card
                _buildSectionCard(
                  title: 'Attachments',
                  icon: Icons.attach_file,
                  child: _buildAttachmentsSection(),
                ),
                
                const SizedBox(height: 24),
                
                // Action Buttons
                _buildActionButtons(),
                
                const SizedBox(height: 16),
              ],
            ),
          ),
          
          // Loading Overlay
          if (_isSaving)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.mustBlue),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Saving changes...',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Please wait',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.mustBlue.withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
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
                    icon,
                    color: AppColors.mustBlue,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.grey[600], size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusRow(String status) {
    Color statusColor;
    IconData statusIcon;
    
    switch (status.toLowerCase()) {
      case 'pending':
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
        break;
      case 'in progress':
      case 'investigating':
        statusColor = AppColors.mustBlue;
        statusIcon = Icons.hourglass_empty;
        break;
      case 'resolved':
        statusColor = AppColors.mustGreen;
        statusIcon = Icons.check_circle;
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.info;
    }

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(statusIcon, color: statusColor, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Status',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withOpacity(0.3)),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 54,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300, width: 2),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _isSaving ? null : () => Navigator.pop(context),
                child: Center(
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: Container(
            height: 54,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(
                colors: [
                  AppColors.mustGold,
                  AppColors.mustGoldLight,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.mustGold.withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _isSaving ? null : _saveChanges,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.save_rounded, color: AppColors.mustBlue, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      widget.evidenceOnly ? 'Save Evidence' : 'Save Changes',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.mustBlue,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEditableField(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
    IconData? icon,
    String? hintText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: AppColors.mustBlue),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            style: const TextStyle(fontSize: 15),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.mustBlue, width: 2),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _saveChanges() async {
    final String description = _descriptionController.text.trim();
    final String location = _locationController.text.trim();

    if (!widget.evidenceOnly && (description.isEmpty || location.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Description and location cannot be empty.'),
        ),
      );
      return;
    }

    // Verify ownership before allowing edit
    final currentUser = _auth.currentUser;
    final reportOwnerId = widget.reportData['userId'] as String?;

    if (currentUser == null || reportOwnerId != currentUser.uid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can only edit your own reports.')),
      );
      return;
    }

    // In evidence-only mode, ensure new evidence is actually being added
    if (widget.evidenceOnly && _newImages.isEmpty && _newVideos.isEmpty && _newAudios.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one image, video, or audio as evidence.'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Upload new images to ImgBB
      List<String> newImageUrls = [];
      if (_newImages.isNotEmpty) {
        newImageUrls = await _uploadImages(_newImages);
      }

      // Upload new videos
      List<String> newVideoUrls = [];
      if (_newVideos.isNotEmpty) {
        newVideoUrls = await _uploadVideos(_newVideos);
      }

      // Upload new audio files
      List<String> newAudioUrls = [];
      if (_newAudios.isNotEmpty) {
        newAudioUrls = await _uploadAudios(_newAudios);
      }

      // Combine existing (minus removed) with new URLs
      final List<String> finalImageUrls = [..._existingImageUrls, ...newImageUrls];
      final List<String> finalVideoUrls = [..._existingVideoUrls, ...newVideoUrls];
      final List<String> finalAudioUrls = [..._existingAudioUrls, ...newAudioUrls];

      // In evidence-only mode, only update evidence fields
      final Map<String, dynamic> updateData = {
        'imageUrls': finalImageUrls,
        'videoUrls': finalVideoUrls,
        'audioUrls': finalAudioUrls,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (!widget.evidenceOnly) {
        updateData['description'] = description;
        updateData['location'] = location;
        updateData['perpetratorInfo'] = _perpetratorController.text.trim().isNotEmpty 
            ? _perpetratorController.text.trim() 
            : null;
        updateData['witnesses'] = _witnessesController.text.trim().isNotEmpty 
            ? _witnessesController.text.trim() 
            : null;
        updateData['complainantResponse'] = _responseController.text.trim().isNotEmpty 
            ? _responseController.text.trim() 
            : null;
      }

      await _firestore.collection('reports').doc(widget.reportId).update(updateData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report updated successfully')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating report: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    if (date is Timestamp) {
      final dateTime = date.toDate();
      return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year}';
    }
    return 'N/A';
  }

  // Attachment methods
  Future<void> _pickImages() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage();
    setState(() {
      _newImages.addAll(images.map((xfile) => File(xfile.path)));
    });
  }

  Future<void> _pickVideo() async {
    final ImagePicker picker = ImagePicker();
    final XFile? video = await picker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      setState(() {
        _newVideos.add(File(video.path));
      });
    }
  }

  void _removeNewImage(int index) {
    setState(() {
      _newImages.removeAt(index);
    });
  }

  void _removeNewVideo(int index) {
    setState(() {
      _newVideos.removeAt(index);
    });
  }

  void _removeExistingImage(int index) {
    setState(() {
      _removedImageUrls.add(_existingImageUrls[index]);
      _existingImageUrls.removeAt(index);
    });
  }

  void _removeExistingVideo(int index) {
    setState(() {
      _removedVideoUrls.add(_existingVideoUrls[index]);
      _existingVideoUrls.removeAt(index);
    });
  }

  void _removeNewAudio(int index) {
    setState(() {
      _newAudios.removeAt(index);
    });
  }

  void _removeExistingAudio(int index) {
    setState(() {
      _removedAudioUrls.add(_existingAudioUrls[index]);
      _existingAudioUrls.removeAt(index);
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
          _newAudios.add(File(path));
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

  String _formatRecordingDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
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
      final url = await CloudinaryService.uploadVideo(file.path);
      if (url != null) {
        urls.add(url);
      }
    }
    
    return urls;
  }

  /// Upload audio files to Cloudinary
  Future<List<String>> _uploadAudios(List<File> files) async {
    List<String> urls = [];
    
    for (var file in files) {
      final url = await CloudinaryService.uploadAudio(file.path);
      if (url != null) {
        urls.add(url);
      }
    }
    
    return urls;
  }

  Widget _buildAttachmentsSection() {
    final int existingImageCount = _existingImageUrls.length;
    final int existingVideoCount = _existingVideoUrls.length;
    final int existingAudioCount = _existingAudioUrls.length;
    final int newImageCount = _newImages.length;
    final int newVideoCount = _newVideos.length;
    final int newAudioCount = _newAudios.length;
    final int totalImages = existingImageCount + newImageCount;
    final int totalVideos = existingVideoCount + newVideoCount;
    final int totalAudios = existingAudioCount + newAudioCount;
    final bool hasAttachments = totalImages > 0 || totalVideos > 0 || totalAudios > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Add buttons
        Row(
          children: [
            Expanded(
              child: _buildMediaButton(
                icon: Icons.photo_library_rounded,
                label: 'Add Photos (evidence)',
                onTap: _pickImages,
                count: totalImages,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMediaButton(
                icon: Icons.videocam_rounded,
                label: 'Add Videos (evidence)',
                onTap: _pickVideo,
                count: totalVideos,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Audio Recording Button
        _buildAudioRecordingButton(totalAudios),
        
        if (!hasAttachments) ...[
          const SizedBox(height: 16),
          Center(
            child: Column(
              children: [
                Icon(Icons.cloud_upload_outlined, size: 40, color: Colors.grey[300]),
                const SizedBox(height: 8),
                Text(
                  'No attachments yet',
                  style: TextStyle(color: Colors.grey[400], fontSize: 14),
                ),
              ],
            ),
          ),
        ],
        
        // Existing Images Preview
        if (_existingImageUrls.isNotEmpty) ...[
          const SizedBox(height: 20),
          _buildSubsectionHeader('Existing Images', Icons.photo, AppColors.mustBlue),
          const SizedBox(height: 10),
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _existingImageUrls.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          _existingImageUrls[index],
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              width: 100,
                              height: 100,
                              color: Colors.grey[200],
                              child: const Center(
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 100,
                              height: 100,
                              color: Colors.grey[200],
                              child: const Icon(Icons.broken_image),
                            );
                          },
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: widget.evidenceOnly
                            ? const SizedBox.shrink()
                            : GestureDetector(
                                onTap: () => _removeExistingImage(index),
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
        
        // New Images Preview
        if (_newImages.isNotEmpty) ...[
          const SizedBox(height: 20),
          _buildSubsectionHeader('New Images', Icons.add_photo_alternate, AppColors.mustGreen),
          const SizedBox(height: 10),
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _newImages.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          _newImages[index],
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => _removeNewImage(index),
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
        
        // Existing Videos Preview
        if (_existingVideoUrls.isNotEmpty) ...[
          const SizedBox(height: 20),
          _buildSubsectionHeader('Existing Videos', Icons.video_library, AppColors.mustBlue),
          const SizedBox(height: 10),
          ...List.generate(_existingVideoUrls.length, (index) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.mustBlue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.mustBlue.withOpacity(0.2)),
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
                      style: const TextStyle(fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (!widget.evidenceOnly)
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red, size: 20),
                      onPressed: () => _removeExistingVideo(index),
                    ),
                ],
              ),
            );
          }),
        ],
        
        // New Videos Preview
        if (_newVideos.isNotEmpty) ...[
          const SizedBox(height: 20),
          _buildSubsectionHeader('New Videos', Icons.video_call, AppColors.mustGreen),
          const SizedBox(height: 10),
          ...List.generate(_newVideos.length, (index) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.mustGreen.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.mustGreen.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.mustGreen.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.videocam,
                      color: AppColors.mustGreen,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _newVideos[index].path.split(Platform.pathSeparator).last,
                      style: const TextStyle(fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red, size: 20),
                    onPressed: () => _removeNewVideo(index),
                  ),
                ],
              ),
            );
          }),
        ],
        
        // Existing Audio Preview
        if (_existingAudioUrls.isNotEmpty) ...[
          const SizedBox(height: 20),
          _buildSubsectionHeader('Existing Audio', Icons.audiotrack, Colors.deepPurple),
          const SizedBox(height: 10),
          ...List.generate(_existingAudioUrls.length, (index) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.deepPurple.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.deepPurple.withOpacity(0.2)),
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
                      style: const TextStyle(fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (!widget.evidenceOnly)
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red, size: 20),
                      onPressed: () => _removeExistingAudio(index),
                    ),
                ],
              ),
            );
          }),
        ],

        // New Audio Preview
        if (_newAudios.isNotEmpty) ...[
          const SizedBox(height: 20),
          _buildSubsectionHeader('New Audio', Icons.mic, AppColors.mustGreen),
          const SizedBox(height: 10),
          ...List.generate(_newAudios.length, (index) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.mustGreen.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.mustGreen.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.mustGreen.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.audiotrack,
                      color: AppColors.mustGreen,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _newAudios[index].path.split(Platform.pathSeparator).last,
                      style: const TextStyle(fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red, size: 20),
                    onPressed: () => _removeNewAudio(index),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildSubsectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color,
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
    final bool hasItems = count > 0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          decoration: BoxDecoration(
            color: hasItems ? AppColors.mustBlue.withOpacity(0.05) : Colors.grey[50],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasItems ? AppColors.mustBlue.withOpacity(0.3) : Colors.grey.shade200,
              width: hasItems ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: hasItems ? AppColors.mustBlue.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon,
                      size: 28,
                      color: hasItems ? AppColors.mustBlue : Colors.grey[400],
                    ),
                  ),
                  if (hasItems)
                    Positioned(
                      right: -8,
                      top: -8,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.mustBlue, AppColors.mustBlue.withOpacity(0.8)],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.mustBlue.withOpacity(0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
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
              const SizedBox(height: 12),
              Text(
                label,
                style: TextStyle(
                  color: hasItems ? AppColors.mustBlue : Colors.grey[600],
                  fontWeight: hasItems ? FontWeight.bold : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAudioRecordingButton(int totalAudios) {
    return GestureDetector(
      onTap: _toggleRecording,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: _isRecording ? Colors.red.shade50 : (totalAudios > 0 ? Colors.deepPurple.withOpacity(0.05) : Colors.grey[50]),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isRecording
                ? Colors.red
                : totalAudios > 0
                    ? Colors.deepPurple.withOpacity(0.3)
                    : Colors.grey.shade200,
            width: _isRecording || totalAudios > 0 ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isRecording
                        ? Colors.red.withOpacity(0.15)
                        : totalAudios > 0
                            ? Colors.deepPurple.withOpacity(0.1)
                            : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                    size: 28,
                    color: _isRecording
                        ? Colors.red
                        : totalAudios > 0
                            ? Colors.deepPurple
                            : Colors.grey[400],
                  ),
                ),
                if (totalAudios > 0 && !_isRecording)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.deepPurple, Colors.deepPurple.withOpacity(0.8)],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.deepPurple.withOpacity(0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        '$totalAudios',
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
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isRecording
                        ? 'Recording... Tap to stop'
                        : 'Record Audio (evidence)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _isRecording
                          ? Colors.red
                          : totalAudios > 0
                              ? Colors.deepPurple
                              : Colors.grey[600],
                    ),
                  ),
                  if (_isRecording)
                    Text(
                      _formatRecordingDuration(_recordingDuration),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red[400],
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
