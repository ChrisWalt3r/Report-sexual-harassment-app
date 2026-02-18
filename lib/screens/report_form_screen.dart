import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/imgbb_service.dart';
import '../services/cloudinary_service.dart';

class ReportFormScreen extends StatefulWidget {
  const ReportFormScreen({super.key});

  @override
  State<ReportFormScreen> createState() => _ReportFormScreenState();
}

class _ReportFormScreenState extends State<ReportFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  DateTime? _selectedDate;
  final Set<String> _selectedIncidentTypes = {};
  final TextEditingController _otherTypeController = TextEditingController();
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String _uploadStatus = '';
  final List<File> _selectedImages = [];
  final List<File> _selectedVideos = [];

  final List<Map<String, dynamic>> _incidentTypes = [
    {'name': 'Verbal Harassment', 'icon': Icons.record_voice_over},
    {'name': 'Physical Harassment', 'icon': Icons.front_hand},
    {'name': 'Online Harassment', 'icon': Icons.computer},
    {'name': 'Stalking', 'icon': Icons.visibility},
    {'name': 'Other', 'icon': Icons.more_horiz},
  ];

  @override
  void dispose() {
    _descriptionController.dispose();
    _locationController.dispose();
    _otherTypeController.dispose();
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
            colorScheme: ColorScheme.light(
              primary: Colors.blue[700]!,
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
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Your Tracking Token',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SelectableText(
                          token,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900,
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
                        foregroundColor: copied ? Colors.green : Colors.blue.shade700,
                        side: BorderSide(
                          color: copied ? Colors.green : Colors.blue.shade300,
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
                      backgroundColor: Colors.blue[700],
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
      final url = await CloudinaryService.uploadVideo(file.path);
      if (url != null) {
        urls.add(url);
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
          setState(() {
            _uploadProgress = 0.4;
          });
        }

        List<String> videoUrls = [];
        if (_selectedVideos.isNotEmpty) {
          setState(() {
            _uploadStatus = 'Uploading videos...';
          });
          videoUrls = await _uploadVideos(_selectedVideos);
          setState(() {
            _uploadProgress = 0.7;
          });
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
          'incidentType': incidentTypeString,
          'incidentTypes': incidentTypes, // Store as list for structured access
          'category': incidentTypeString, // Combined category string
          'imageUrls': imageUrls,
          'videoUrls': videoUrls,
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
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        elevation: 0,
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
                          color: Colors.blue.withOpacity(0.2),
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
                                color: Colors.blue[700],
                                strokeWidth: 8,
                                backgroundColor: Colors.grey[200],
                              ),
                            ),
                            Text(
                              '${(_uploadProgress * 100).toInt()}%',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[700],
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
                      gradient: LinearGradient(
                        colors: [Colors.blue[700]!, Colors.blue[500]!],
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
                                        ? Colors.blue[700]
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? Colors.blue[700]!
                                          : Colors.grey[300]!,
                                      width: 2,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: Colors.blue.withOpacity(0.3),
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
                                    color: Colors.blue[700],
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
                                      color: Colors.blue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      Icons.calendar_today,
                                      color: Colors.blue[700],
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
                                        color: Colors.blue.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        Icons.videocam,
                                        color: Colors.blue[700],
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
                          
                          const SizedBox(height: 32),
                          
                          // Submit Button
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _submitReport,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue[700],
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 4,
                                shadowColor: Colors.blue.withOpacity(0.4),
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
        Icon(icon, size: 20, color: Colors.blue[700]),
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
            color: count > 0 ? Colors.blue[700]! : Colors.grey[300]!,
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
                  color: count > 0 ? Colors.blue[700] : Colors.grey[400],
                ),
                if (count > 0)
                  Positioned(
                    right: -8,
                    top: -8,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.blue[700],
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
                color: count > 0 ? Colors.blue[700] : Colors.grey[600],
                fontWeight: count > 0 ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
