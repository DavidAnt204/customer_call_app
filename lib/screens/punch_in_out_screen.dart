import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:geocoding/geocoding.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:location/location.dart' as loc;
import 'package:image_picker/image_picker.dart';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:image/image.dart' as img;
import 'package:mime/mime.dart';
import 'package:path_provider/path_provider.dart';

import '../services/api_services.dart';

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
  bool _isLoading = false;
  bool _isTodayCompleted = false; // when both punch in & out done

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
    _checkPunchStatus();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _checkPunchStatus() async {
    final box = Hive.box('myBox');
    final punchData = box.get('punchStatus');
    // Example format stored in Hive:
    // { "2025-08-10": {"punchIn": true, "punchOut": true} }

    final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());

    if (punchData != null && punchData[todayKey] != null) {
      bool inDone = punchData[todayKey]['punchIn'] ?? false;
      bool outDone = punchData[todayKey]['punchOut'] ?? false;
      setState(() {
        _isTodayCompleted = inDone && outDone;
      });
    }
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
        '${place.thoroughfare} ${place.subLocality}, ${place.locality} – ${place.postalCode}';
        print('current location ${place.name} ${place.postalCode} ${place.administrativeArea}');
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

  Future<Uint8List> _compressToMaxSize(Uint8List imageBytes, int maxBytes) async {
    int quality = 90;
    Uint8List compressed = imageBytes;

    // Reduce quality until under limit
    while (compressed.lengthInBytes > maxBytes && quality > 10) {
      compressed = await FlutterImageCompress.compressWithList(
        compressed,
        quality: quality,
        format: CompressFormat.jpeg, // Force JPG
      );
      quality -= 10;
    }
    return compressed;
  }

  // Convert any image bytes -> JPEG bytes and compress/resize until under maxBytes
  Future<Uint8List> _convertAndCompressToJpg(Uint8List inputBytes, int maxBytes) async {
    // decode (auto-detect format)
    final decoded = img.decodeImage(inputBytes);
    if (decoded == null) {
      throw Exception('Could not decode image bytes');
    }

    // start with original (but limit max dimension to avoid huge images)
    img.Image working = decoded;
    const int maxDimension = 2000;
    if (working.width > maxDimension || working.height > maxDimension) {
      working = img.copyResize(working, width: maxDimension);
    }

    // Try encoding with decreasing quality
    int quality = 95;
    Uint8List jpg = Uint8List.fromList(img.encodeJpg(working, quality: quality));

    while (jpg.lengthInBytes > maxBytes && quality > 10) {
      quality -= 10;
      jpg = Uint8List.fromList(img.encodeJpg(working, quality: quality));
    }

    // If still too large, progressively downscale until fits
    int currentWidth = working.width;
    int currentHeight = working.height;
    while (jpg.lengthInBytes > maxBytes && (currentWidth > 200 || currentHeight > 200)) {
      currentWidth = (currentWidth * 0.85).round();
      currentHeight = (currentHeight * 0.85).round();
      working = img.copyResize(working, width: currentWidth, height: currentHeight);
      jpg = Uint8List.fromList(img.encodeJpg(working, quality: quality));
    }

    return jpg;
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
                onCropped: (Uint8List croppedBytes) async {
                  try {
                    // Convert+compress to JPEG under 2MB
                    final Uint8List jpegBytes = await _convertAndCompressToJpg(
                      croppedBytes,
                      2 * 1024 * 1024,
                    );

                    // Save to temp file with .jpg extension (so server-side extension checks pass)
                    final dir = await getTemporaryDirectory();
                    final filePath = '${dir.path}/selfie_${DateTime.now().millisecondsSinceEpoch}.jpg';
                    final File jpgFile = File(filePath);
                    await jpgFile.writeAsBytes(jpegBytes);

                    // Optionally check mime
                    final mimeType = lookupMimeType(jpgFile.path, headerBytes: jpegBytes);
                    debugPrint('Saved file: $filePath, mime: $mimeType, size: ${jpegBytes.lengthInBytes}');

                    setState(() {
                      _croppedImageBytes = jpegBytes;
                      _imageFile = jpgFile; // if you keep this field
                    });
                  } catch (e) {
                    debugPrint('Image conversion failed: $e');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to process image: $e')),
                    );
                  } finally {
                    if (mounted) Navigator.of(context).pop();
                  }
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

  Future<void> _handlePunchInOut() async {
    final box = Hive.box('myBox');
    final dynamic rawData = box.get('staffinfo');
    final Map<String, dynamic> staffInfo = rawData is String
        ? Map<String, dynamic>.from(jsonDecode(rawData))
        : Map<String, dynamic>.from(rawData);

    print(staffInfo);

    if (_croppedImageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Please take a selfie before punching ${widget.isPunchIn ? 'in' : 'out'}'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true); // 🔹 Show loader

    final result = widget.isPunchIn ? await PunchService.punchIn(
      userId: staffInfo["staffid"],
      location: currentLocation,
      imageBytes: _croppedImageBytes!,
    ) : await PunchService.punchOut(
    userId: staffInfo["staffid"],
    location: currentLocation,
    imageBytes: _croppedImageBytes!,
    );

    setState(() => _isLoading = false); // 🔹 Hide loader

    if (!mounted) return;

    final body = jsonDecode(result['body']);

    if (result['statusCode'] == 200 && body['message'] != null) {
      final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final box = Hive.box('myBox');
      Map<String, dynamic> punchData = box.get('punchStatus', defaultValue: {}) as Map<String, dynamic>;

      punchData[todayKey] ??= {"punchIn": false, "punchOut": false};
      if (widget.isPunchIn) {
        punchData[todayKey]['punchIn'] = true;
      } else {
        punchData[todayKey]['punchOut'] = true;
      }

      box.put('punchStatus', punchData);

      setState(() {
        _isTodayCompleted = punchData[todayKey]['punchIn'] && punchData[todayKey]['punchOut'];
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(body['message'])),
      );
      Navigator.pop(context, DateTime.now());
    }
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
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: Text(
              "Punch In / Out",
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
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
                      crossAxisAlignment: CrossAxisAlignment.stretch,
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
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500)),
                                SizedBox(height: 8),
                                Text("Time: $currentTime",
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500)),
                                SizedBox(height: 8),
                                Text("Location: $currentLocation",
                                    style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[700])),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: 24),
                        Text(
                          widget.isPunchIn
                              ? "Take Selfie to Punch In"
                              : "Take Selfie to Punch Out",
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
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
                      onPressed: (_croppedImageBytes == null || _isTodayCompleted)
                          ? null
                          : _handlePunchInOut,
                      icon: Icon(Icons.how_to_reg, color: Colors.white),
                      label: Text(
                        widget.isPunchIn ? "Punch In" : "Punch Out",
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.isPunchIn
                            ? Colors.deepPurple
                            : Colors.red,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // 🔹 Loader overlay
        if (_isLoading)
          Positioned.fill(
            child: Container(
              color: Colors.black45,
              child: const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
