import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart';
import 'package:location/location.dart' as loc;
import 'package:image_picker/image_picker.dart';
import 'package:crop_your_image/crop_your_image.dart';

class PunchInOutScreen extends StatefulWidget {
  final bool isPunchIn;

  const PunchInOutScreen({Key? key, required this.isPunchIn}) : super(key: key);

  @override
  State<PunchInOutScreen> createState() => _PunchInOutScreenState();
}

class _PunchInOutScreenState extends State<PunchInOutScreen> {
  String currentTime = '';
  String currentDate = '';
  String currentLocation = 'Fetching location...';
  CameraController? _cameraController;

  Timer? _timer;

  // For cropping:
  final CropController _cropController = CropController();
  Uint8List? _originalImageBytes;
  Uint8List? _croppedImageBytes;
  File? _imageFile; // Keep for consistency, not used for display after cropping

  @override
  void initState() {
    super.initState();
    _updateDateTime();
    _getLocation();
    _startClock();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startClock() {
    _timer = Timer.periodic(Duration(seconds: 1), (_) => _updateDateTime());
  }

  void _updateDateTime() {
    final now = DateTime.now();
    setState(() {
      currentTime = DateFormat('hh:mm:ss a').format(now);
      currentDate = DateFormat('EEEE, MMMM d, yyyy').format(now);
    });
  }

  Future<void> _getLocation() async {
    final location = loc.Location();

    bool serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) return;
    }

    loc.PermissionStatus permissionGranted = await location.hasPermission();
    if (permissionGranted == loc.PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != loc.PermissionStatus.granted) return;
    }

    final locData = await location.getLocation();

    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        locData.latitude ?? 0.0,
        locData.longitude ?? 0.0,
      );

      final Placemark place = placemarks.first;

      setState(() {
        currentLocation =
        '${place.subLocality}, ${place.locality} – ${place.postalCode}';
      });
    } catch (e) {
      setState(() {
        currentLocation = "Unable to fetch location details.";
      });
    }
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    final frontCamera = cameras.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.front,
    );
    _cameraController = CameraController(frontCamera, ResolutionPreset.medium);
    await _cameraController!.initialize();
    setState(() {});
  }


  Future<void> _pickImage() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      await _initCamera();
    }

    final picker = ImagePicker();
    final pickedImage = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 70,
    );

    if (pickedImage != null) {
      _originalImageBytes = await pickedImage.readAsBytes();
      _croppedImageBytes = null;

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            contentPadding: EdgeInsets.zero,
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: Crop(
                image: _originalImageBytes!,
                controller: _cropController,
                aspectRatio: 1,
                onCropped: (Uint8List croppedBytes) {
                  setState(() {
                    _croppedImageBytes = croppedBytes;
                    _imageFile = null;
                  });
                  Navigator.of(context).pop();
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => _cropController.crop(),
                child: Text('Crop'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Cancel'),
              ),
            ],
          );
        },
      );
    }
  }

  void _deleteImage() {
    setState(() {
      _croppedImageBytes = null;
      _originalImageBytes = null;
      _imageFile = null;
    });
  }

  void _handlePunchInOut() {
    if (_croppedImageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Please take a selfie before punching ${widget.isPunchIn ? 'in' : 'out'}'),
        ),
      );
      return;
    }

    final DateTime punchTime = DateTime.now();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(widget.isPunchIn
            ? 'Punched In successfully!'
            : 'Punched Out successfully!'),
      ),
    );

    Navigator.pop(context, punchTime); // return punch time to dashboard
  }

  Widget _buildGlassIconButton({
    required IconData icon,
    required VoidCallback onPressed,
    required Color iconColor,
  }) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.3)),
          ),
          child: IconButton(
            icon: Icon(icon, color: iconColor, size: 20),
            onPressed: onPressed,
            padding: EdgeInsets.zero,
          ),
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    if (_croppedImageBytes == null) {
      return GestureDetector(
        onTap: _pickImage,
        child: Container(
          height: 180,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.camera_alt, size: 40, color: Colors.grey[600]),
                SizedBox(height: 8),
                Text(
                  "Upload Selfie",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                _croppedImageBytes!,
                height: 200,
                width: double.infinity,
                fit: BoxFit.fitWidth,
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: Row(
                children: [
                  _buildGlassIconButton(
                    icon: Icons.refresh,
                    onPressed: _pickImage,
                    iconColor: Colors.white,
                  ),
                  SizedBox(width: 8),
                  _buildGlassIconButton(
                    icon: Icons.delete,
                    onPressed: _deleteImage,
                    iconColor: Colors.redAccent,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Punch In / Out",
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.chevron_left),
          iconSize: 32,
          onPressed: () => Navigator.pop(context),
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          padding: const EdgeInsets.all(8),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        foregroundColor: Colors.black,
        titleSpacing: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Date: $currentDate",
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w500)),
                            SizedBox(height: 8),
                            Text("Time: $currentTime",
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w500)),
                            SizedBox(height: 8),
                            Text("Location: $currentLocation",
                                style:
                                TextStyle(fontSize: 14, color: Colors.grey[700])),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 24),
                    Text(
                      widget.isPunchIn
                          ? "Take Selfie to Punch In"
                          : "Take Selfie to Punch Out",
                      style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 12),
                    _buildImageSection(),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed:
                  _croppedImageBytes == null ? null : _handlePunchInOut,
                  icon: Icon(Icons.how_to_reg, color: Colors.white),
                  label: Text(
                    widget.isPunchIn ? "Punch In" : "Punch Out",
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                    widget.isPunchIn ? Colors.deepPurple : Colors.red,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    textStyle:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
