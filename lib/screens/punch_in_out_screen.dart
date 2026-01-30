import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_fonts/google_fonts.dart'; // Added for modern typography
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:location/location.dart' as loc;
import 'package:image_picker/image_picker.dart';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:image/image.dart' as img;
import 'package:mime/mime.dart';
import 'package:path_provider/path_provider.dart';

import '../services/api_services.dart';

// --- Design Constants ---
const Color primaryColor = Color(0xFF4169E1); // Royal Blue
const Color accentColor = Color(0xFF00C6FF); // Bright Cyan
const Color cardColor = Colors.white;
const double cardRadius = 18.0;

class PunchInOutScreen extends StatefulWidget {
  final bool isPunchIn;

  const PunchInOutScreen({Key? key, required this.isPunchIn}) : super(key: key);

  @override
  State<PunchInOutScreen> createState() => _PunchInOutScreenState();
}

class _PunchInOutScreenState extends State<PunchInOutScreen> {
  // --- Functionality Preserved: State Variables ---
  String currentTime = '';
  String currentDate = '';
  String currentLocation = 'Fetching location...';
  CameraController? _cameraController;
  bool _isLoading = false;
  bool _isTodayCompleted = false;

  Timer? _timer;

  final CropController _cropController = CropController();
  Uint8List? _originalImageBytes;
  Uint8List? _croppedImageBytes;
  File? _imageFile;

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
    _cameraController?.dispose(); // Added camera controller disposal
    super.dispose();
  }

  // --- Functionality Preserved: Core Logic ---

  Future<void> _checkPunchStatus() async {
    // Check if the screen is still mounted before accessing context or calling setState
    if (!mounted) return;
    final box = Hive.box('myBox');
    final punchData = box.get('punchStatus');
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
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateDateTime());
  }

  void _updateDateTime() {
    if (!mounted) return; // Safety check before setState
    final now = DateTime.now();
    setState(() {
      currentTime = DateFormat('hh:mm:ss a').format(now);
      currentDate = DateFormat('EEEE, MMMM d, yyyy').format(now);
    });
  }

  Future<void> _getLocation() async {
    final location = loc.Location();

    // Permission and service logic preserved
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

      if (mounted) {
        setState(() {
          currentLocation =
          '${place.street ?? ''}, ${place.subLocality ?? ''}, ${place.locality ?? ''} ${place.postalCode ?? ''}';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          currentLocation = "Unable to fetch location details.";
        });
      }
    }
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    final frontCamera = cameras.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.front,
    );
    _cameraController = CameraController(frontCamera, ResolutionPreset.medium);
    await _cameraController!.initialize();
    if (mounted) setState(() {});
  }

  // Image processing logic preserved (compression/conversion)
  Future<Uint8List> _convertAndCompressToJpg(Uint8List inputBytes, int maxBytes) async {
    final decoded = img.decodeImage(inputBytes);
    if (decoded == null) {
      throw Exception('Could not decode image bytes');
    }

    img.Image working = decoded;
    const int maxDimension = 2000;
    if (working.width > maxDimension || working.height > maxDimension) {
      working = img.copyResize(working, width: maxDimension);
    }

    int quality = 95;
    Uint8List jpg = Uint8List.fromList(img.encodeJpg(working, quality: quality));

    while (jpg.lengthInBytes > maxBytes && quality > 10) {
      quality -= 10;
      jpg = Uint8List.fromList(img.encodeJpg(working, quality: quality));
    }

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
            title: Text('Crop Image', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
            contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: Crop(
                image: _originalImageBytes!,
                controller: _cropController,
                aspectRatio: 1,
                onCropped: (Uint8List croppedBytes) async {
                  try {
                    final Uint8List jpegBytes = await _convertAndCompressToJpg(
                      croppedBytes,
                      2 * 1024 * 1024,
                    );

                    final dir = await getTemporaryDirectory();
                    final filePath = '${dir.path}/selfie_${DateTime.now().millisecondsSinceEpoch}.jpg';
                    final File jpgFile = File(filePath);
                    await jpgFile.writeAsBytes(jpegBytes);

                    setState(() {
                      _croppedImageBytes = jpegBytes;
                      _imageFile = jpgFile;
                    });
                  } catch (e) {
                    debugPrint('Image conversion failed: $e');
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to process image: $e')),
                      );
                    }
                  } finally {
                    if (mounted) Navigator.of(context).pop();
                  }
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => _cropController.crop(),
                child: Text('Crop', style: GoogleFonts.poppins(color: primaryColor)),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.redAccent)),
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

    if (_croppedImageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Please take a selfie before punching ${widget.isPunchIn ? 'in' : 'out'}'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    // API call logic preserved
    final result = widget.isPunchIn ? await PunchService.punchIn(
      userId: staffInfo["staffid"],
      location: currentLocation,
      imageBytes: _croppedImageBytes!,
    ) : await PunchService.punchOut(
      userId: staffInfo["staffid"],
      location: currentLocation,
      imageBytes: _croppedImageBytes!,
    );

    setState(() => _isLoading = false);

    if (!mounted) return;

    final body = jsonDecode(result['body']);

    if (result['statusCode'] == 200 && body['message'] != null) {
      // Hive status update logic preserved
      final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
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
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(body['message'] ?? 'Punch failed due to server error.')),
      );
    }
  }

  // --- REDESIGNED WIDGETS ---

  Widget _buildDateTimeLocationCard() {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(cardRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Time (Largest, Boldest)
            Row(
              children: [
                Icon(Icons.access_time_filled, color: primaryColor, size: 28),
                const SizedBox(width: 10),
                Text(
                  currentTime.split(' ')[0], // hh:mm:ss
                  style: GoogleFonts.poppins(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 10.0, left: 4),
                  child: Text(
                    currentTime.split(' ')[1], // AM/PM
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: primaryColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Date
            Row(
              children: [
                Icon(Icons.calendar_today, color: Colors.grey, size: 18),
                const SizedBox(width: 10),
                Text(currentDate,
                    style: GoogleFonts.poppins(
                        fontSize: 16, color: Colors.black54, fontWeight: FontWeight.w500)),
              ],
            ),
            const Divider(height: 25),

            // Location
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.location_on, color: Colors.redAccent, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(currentLocation,
                      style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    final bool isImageLoaded = _croppedImageBytes != null;
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(cardRadius)),
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(cardRadius),
            child: Container(
              height: 250, // Increased height for better visualization
              width: double.infinity,
              color: isImageLoaded ? Colors.transparent : primaryColor.withOpacity(0.05),
              child: isImageLoaded
                  ? Image.memory(
                _croppedImageBytes!,
                fit: BoxFit.cover,
              )
                  : Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.camera_alt, size: 60, color: primaryColor),
                    const SizedBox(height: 10),
                    Text(
                      "Tap to Capture Selfie",
                      style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: primaryColor,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Action Buttons Overlay
          Positioned.fill(
            child: GestureDetector(
              onTap: _pickImage,
              child: Container(
                color: Colors.black.withOpacity(isImageLoaded ? 0.0 : 0.0), // Invisible tap area
              ),
            ),
          ),

          if (isImageLoaded)
            Positioned(
              top: 10,
              right: 10,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildGlassIconButton(
                          icon: Icons.refresh,
                          onPressed: _pickImage,
                          iconColor: Colors.white,
                          tooltip: 'Retake Selfie',
                        ),
                        const SizedBox(width: 8),
                        _buildGlassIconButton(
                          icon: Icons.delete,
                          onPressed: _deleteImage,
                          iconColor: Colors.redAccent,
                          tooltip: 'Delete Selfie',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGlassIconButton({
    required IconData icon,
    required VoidCallback onPressed,
    required Color iconColor,
    required String tooltip,
  }) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
      ),
      child: IconButton(
        icon: Icon(icon, color: iconColor, size: 20),
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        tooltip: tooltip,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final actionText = widget.isPunchIn ? "Punch In" : "Punch Out";
    final actionColor = widget.isPunchIn ? primaryColor : Colors.redAccent;
    final bool isDisabled = _croppedImageBytes == null || _isTodayCompleted;

    return Stack(
      children: [
        Scaffold(
          backgroundColor: Colors.grey[50],
          appBar: AppBar(
            backgroundColor: primaryColor,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              "$actionText Confirmation",
              style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
            ),
          ),

          body: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. Date, Time, Location Card
                      _buildDateTimeLocationCard(),
                      const SizedBox(height: 24),

                      // 2. Selfie Section Header
                      Text(
                        "Step 1: Capture Your Selfie",
                        style: GoogleFonts.poppins(
                            fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      const SizedBox(height: 12),

                      // 3. Image Widget
                      _buildImageSection(),
                      const SizedBox(height: 16),

                      // 4. Status Message
                      if (_isTodayCompleted)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            "Attendance already completed for today (Punch In & Out done).",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.orange.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // 5. Action Button
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton.icon(
                    onPressed: isDisabled ? null : _handlePunchInOut,
                    icon: Icon(Icons.fingerprint_rounded, color: Colors.white, size: 24),
                    label: Text(
                      actionText,
                      style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: actionColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 8,
                      disabledBackgroundColor: actionColor.withOpacity(0.3),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Loader overlay
        if (_isLoading)
          Positioned.fill(
            child: Container(
              color: Colors.black54,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Colors.white),
                    const SizedBox(height: 15),
                    Text("Processing $actionText...", style: GoogleFonts.poppins(color: Colors.white, fontSize: 16))
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}