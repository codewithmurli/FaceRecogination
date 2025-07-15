// import 'dart:async';
// import 'dart:io';
// import 'dart:typed_data';
//
// import 'package:camera/camera.dart';
// import 'package:face_recogination/common/utils/extensions/size_extension.dart';
// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
// import 'package:image_picker/image_picker.dart';
//
// import '../../constants/theme.dart';
//
// class CameraView extends StatefulWidget {
//   const CameraView({
//     Key? key,
//     required this.onImage,
//     required this.onInputImage,
//     this.requireFaceDetection = false, // New parameter to control face detection requirement
//   }) : super(key: key);
//
//   final Function(Uint8List image) onImage;
//   final Function(InputImage inputImage) onInputImage;
//   final bool requireFaceDetection; // If true, only capture when face is detected
//
//   @override
//   State<CameraView> createState() => _CameraViewState();
// }
//
// class _CameraViewState extends State<CameraView> {
//   File? _image;
//   ImagePicker? _imagePicker;
//   bool _openedCameraOnce = false;
//
//   // Camera related variables
//   CameraController? _cameraController;
//   List<CameraDescription>? _cameras;
//   bool _isCameraInitialized = false;
//
//   // Face detection related variables
//   final FaceDetector _faceDetector = FaceDetector(
//     options: FaceDetectorOptions(
//       enableContours: true,
//       enableClassification: true,
//       enableLandmarks: true,
//       enableTracking: true,
//       minFaceSize: 0.1,
//       performanceMode: FaceDetectorMode.fast,
//     ),
//   );
//
//   bool _isDetecting = false;
//   bool _faceDetected = false;
//   Timer? _captureTimer;
//   int _countdown = 1;
//   bool _isCountingDown = false;
//
//   @override
//   void initState() {
//     super.initState();
//     _imagePicker = ImagePicker();
//     _initializeCamera();
//   }
//
//   @override
//   void dispose() {
//     _captureTimer?.cancel();
//     _cameraController?.dispose();
//     _faceDetector.close();
//     super.dispose();
//   }
//
//   Future<void> _initializeCamera() async {
//     _cameras = await availableCameras();
//     if (_cameras!.isNotEmpty) {
//       _cameraController = CameraController(
//         _cameras![1], // Front camera (index 1), use 0 for back camera
//         ResolutionPreset.medium,
//         enableAudio: false,
//       );
//
//       try {
//         await _cameraController!.initialize();
//         setState(() {
//           _isCameraInitialized = true;
//         });
//         _startFaceDetection();
//       } catch (e) {
//         print('Error initializing camera: $e');
//       }
//     }
//   }
//
//   void _startFaceDetection() {
//     // Use periodic detection instead of image stream to avoid format issues
//     Timer.periodic(const Duration(milliseconds: 500), (timer) {
//       if (!mounted) {
//         timer.cancel();
//         return;
//       }
//
//       if (_image == null && _cameraController != null &&
//           _cameraController!.value.isInitialized && !_isDetecting) {
//         _detectFacesFromCapture();
//       }
//     });
//   }
//
//   Future<void> _detectFacesFromCapture() async {
//     if (_isDetecting || _cameraController == null || !_cameraController!.value.isInitialized) {
//       return;
//     }
//
//     try {
//       _isDetecting = true;
//
//       // Take a temporary photo for face detection
//       final XFile tempPhoto = await _cameraController!.takePicture();
//       final inputImage = InputImage.fromFilePath(tempPhoto.path);
//
//       final faces = await _faceDetector.processImage(inputImage);
//
//       // Clean up temporary file
//       final tempFile = File(tempPhoto.path);
//       if (await tempFile.exists()) {
//         await tempFile.delete();
//       }
//
//       setState(() {
//         _faceDetected = faces.isNotEmpty;
//       });
//
//       if (_faceDetected && !_isCountingDown) {
//         _startCountdown();
//       } else if (!_faceDetected && _isCountingDown) {
//         _cancelCountdown();
//       }
//     } catch (e) {
//       print('Error detecting faces: $e');
//     } finally {
//       _isDetecting = false;
//     }
//   }
//
//   void _startCountdown() {
//     _isCountingDown = true;
//     _countdown = 1;
//
//     _captureTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
//       _countdown--;
//
//       if (_countdown <= 0) {
//         _capturePhoto();
//         _cancelCountdown();
//       }
//     });
//   }
//
//   void _cancelCountdown() {
//     _captureTimer?.cancel();
//     _isCountingDown = false;
//     _countdown = 1;
//   }
//
//   Future<void> _capturePhoto() async {
//     if (_cameraController == null || !_cameraController!.value.isInitialized) {
//       return;
//     }
//
//     // Check if face detection is required and if face is detected
//     if (widget.requireFaceDetection && !_faceDetected) {
//       _showFaceNotDetectedMessage();
//       return;
//     }
//
//     try {
//       final XFile photo = await _cameraController!.takePicture();
//       await _setPickedFile(photo);
//     } catch (e) {
//       print('Error capturing photo: $e');
//     }
//   }
//
//   void _showFaceNotDetectedMessage() {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(
//           'Please position your face in the camera before capturing',
//           style: TextStyle(color: Colors.white),
//         ),
//         backgroundColor: Colors.red,
//         duration: Duration(seconds: 2),
//       ),
//     );
//   }
//
//   // Method to reset camera view (can be called from parent)
//   void resetCamera() {
//     if (mounted) {
//       setState(() {
//         _image = null;
//         _faceDetected = false;
//         _isCountingDown = false;
//       });
//       _cancelCountdown();
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       children: [
//         Row(
//           mainAxisAlignment: MainAxisAlignment.end,
//           children: [
//             Icon(
//               Icons.camera_alt_outlined,
//               color: primaryWhite,
//               size: 0.038.sh,
//             ),
//           ],
//         ),
//         SizedBox(height: 0.025.sh),
//
//         // Camera preview or captured image
//         Stack(
//           alignment: Alignment.center,
//           children: [
//             _image != null
//                 ? CircleAvatar(
//               radius: 0.15.sh,
//               backgroundColor: const Color(0xffD9D9D9),
//               backgroundImage: FileImage(_image!),
//             )
//                 : _isCameraInitialized
//                 ? ClipOval(
//               child: SizedBox(
//                 width: 0.3.sh,
//                 height: 0.3.sh,
//                 child: CameraPreview(_cameraController!),
//               ),
//             )
//                 : CircleAvatar(
//               radius: 0.15.sh,
//               backgroundColor: const Color(0xffD9D9D9),
//               child: Icon(
//                 Icons.camera_alt,
//                 size: 0.09.sh,
//                 color: const Color(0xff2E2E2E),
//               ),
//             ),
//
//             // Face detection indicator
//             if (_isCameraInitialized && _image == null)
//               Positioned(
//                 top: 10,
//                 right: 10,
//                 child: Container(
//                   padding: const EdgeInsets.all(8),
//                   decoration: BoxDecoration(
//                     color: _faceDetected ? Colors.green : Colors.red,
//                     shape: BoxShape.circle,
//                   ),
//                   child: Icon(
//                     _faceDetected ? Icons.face : Icons.face_unlock_outlined,
//                     color: Colors.white,
//                     size: 20,
//                   ),
//                 ),
//               ),
//           ],
//         ),
//
//         // Status text
//         if (_isCameraInitialized && _image == null)
//           Padding(
//             padding: const EdgeInsets.symmetric(vertical: 10),
//             child: Text(
//               widget.requireFaceDetection
//                   ? (_faceDetected
//                   ? 'Face detected! Ready to capture.'
//                   : 'Please position your face in the camera.')
//                   : 'Ready to capture',
//               style: TextStyle(
//                 color: primaryWhite,
//                 fontSize: 14,
//               ),
//               textAlign: TextAlign.center,
//             ),
//           ),
//
//         GestureDetector(
//           onTap: _image == null ? _manualCapture : _retakePhoto,
//           child: Opacity(
//             opacity: (widget.requireFaceDetection && !_faceDetected && _image == null) ? 0.5 : 1.0,
//             child: Container(
//               width: 60,
//               height: 60,
//               margin: const EdgeInsets.only(top: 20, bottom: 20),
//               decoration: BoxDecoration(
//                 gradient: RadialGradient(
//                   stops: [0.4, 0.65, 1],
//                   colors: [
//                     Color(0xffD9D9D9),
//                     primaryWhite,
//                     Color(0xffD9D9D9),
//                   ],
//                 ),
//                 shape: BoxShape.circle,
//               ),
//               child: Icon(
//                 _image == null ? Icons.camera_alt : Icons.refresh,
//                 color: const Color(0xff2E2E2E),
//               ),
//             ),
//           ),
//         ),
//
//       ],
//     );
//   }
//
//   Future<void> _manualCapture() async {
//     if (_isCameraInitialized) {
//       await _capturePhoto();
//     } else {
//       _getImageFromGallery();
//     }
//   }
//
//   Future<void> _retakePhoto() async {
//     setState(() {
//       _image = null;
//     });
//     // Face detection will automatically resume via the periodic timer
//   }
//
//   Future<void> _getImageFromGallery() async {
//     setState(() {
//       _image = null;
//     });
//
//     final pickedFile = await _imagePicker?.pickImage(
//       source: ImageSource.camera,
//       maxWidth: 400,
//       maxHeight: 400,
//     );
//
//     if (pickedFile != null) {
//       await _setPickedFile(pickedFile);
//     }
//
//     setState(() {});
//   }
//
//   Future<void> _setPickedFile(XFile? pickedFile) async {
//     final path = pickedFile?.path;
//     if (path == null) return;
//
//     setState(() {
//       _image = File(path);
//     });
//
//     final Uint8List imageBytes = await _image!.readAsBytes();
//     widget.onImage(imageBytes);
//
//     final inputImage = InputImage.fromFilePath(path);
//     widget.onInputImage(inputImage);
//   }
// }

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:face_recogination/common/utils/extensions/size_extension.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image_picker/image_picker.dart';

import '../../constants/theme.dart';

class CameraView extends StatefulWidget {
  const CameraView({
    Key? key,
    required this.onImage,
    required this.onInputImage,
    this.requireFaceDetection = false, // New parameter to control face detection requirement
  }) : super(key: key);

  final Function(Uint8List image) onImage;
  final Function(InputImage inputImage) onInputImage;
  final bool requireFaceDetection; // If true, only capture when face is detected

  @override
  State<CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> {
  File? _image;
  ImagePicker? _imagePicker;
  bool _openedCameraOnce = false;

  // Camera related variables
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;

  // Face detection related variables
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: true,
      enableClassification: true,
      enableLandmarks: true,
      enableTracking: true,
      minFaceSize: 0.1,
      performanceMode: FaceDetectorMode.fast,
    ),
  );

  bool _isDetecting = false;
  bool _faceDetected = false;
  // Removed Timer? _captureTimer;
  // Removed int _countdown = 1;
  // Removed bool _isCountingDown = false;

  @override
  void initState() {
    super.initState();
    _imagePicker = ImagePicker();
    _initializeCamera();
  }

  @override
  void dispose() {
    // Removed _captureTimer?.cancel();
    _cameraController?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    _cameras = await availableCameras();
    if (_cameras!.isNotEmpty) {
      _cameraController = CameraController(
        _cameras![1], // Front camera (index 1), use 0 for back camera
        ResolutionPreset.medium,
        enableAudio: false,
      );

      try {
        await _cameraController!.initialize();
        setState(() {
          _isCameraInitialized = true;
        });
        _startFaceDetection();
      } catch (e) {
        print('Error initializing camera: $e');
      }
    }
  }

  void _startFaceDetection() {
    // Use periodic detection instead of image stream to avoid format issues
    Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_image == null && _cameraController != null &&
          _cameraController!.value.isInitialized && !_isDetecting) {
        _detectFacesFromCapture();
      }
    });
  }

  Future<void> _detectFacesFromCapture() async {
    if (_isDetecting || _cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    try {
      _isDetecting = true;

      // Take a temporary photo for face detection
      final XFile tempPhoto = await _cameraController!.takePicture();
      final inputImage = InputImage.fromFilePath(tempPhoto.path);

      final faces = await _faceDetector.processImage(inputImage);

      // Clean up temporary file
      final tempFile = File(tempPhoto.path);
      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      setState(() {
        _faceDetected = faces.isNotEmpty;
      });

      // CHANGED: Immediately capture when face is detected (no countdown)
      if (_faceDetected) {
        _capturePhoto();
      }
    } catch (e) {
      print('Error detecting faces: $e');
    } finally {
      _isDetecting = false;
    }
  }

  // Removed countdown methods
  // void _startCountdown() { ... }
  // void _cancelCountdown() { ... }

  Future<void> _capturePhoto() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    // Check if face detection is required and if face is detected
    if (widget.requireFaceDetection && !_faceDetected) {
      _showFaceNotDetectedMessage();
      return;
    }

    try {
      final XFile photo = await _cameraController!.takePicture();
      await _setPickedFile(photo);
    } catch (e) {
      print('Error capturing photo: $e');
    }
  }

  void _showFaceNotDetectedMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Please position your face in the camera before capturing',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 2),
      ),
    );
  }

  // Method to reset camera view (can be called from parent)
  void resetCamera() {
    if (mounted) {
      setState(() {
        _image = null;
        _faceDetected = false;
        // Removed _isCountingDown = false;
      });
      // Removed _cancelCountdown();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(
              Icons.camera_alt_outlined,
              color: primaryWhite,
              size: 0.038.sh,
            ),
          ],
        ),
        SizedBox(height: 0.025.sh),

        // Camera preview or captured image
        Stack(
          alignment: Alignment.center,
          children: [
            _image != null
                ? CircleAvatar(
              radius: 0.15.sh,
              backgroundColor: const Color(0xffD9D9D9),
              backgroundImage: FileImage(_image!),
            )
                : _isCameraInitialized
                ? ClipOval(
              child: SizedBox(
                width: 0.3.sh,
                height: 0.3.sh,
                child: CameraPreview(_cameraController!),
              ),
            )
                : CircleAvatar(
              radius: 0.15.sh,
              backgroundColor: const Color(0xffD9D9D9),
              child: Icon(
                Icons.camera_alt,
                size: 0.09.sh,
                color: const Color(0xff2E2E2E),
              ),
            ),

            // Face detection indicator
            if (_isCameraInitialized && _image == null)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _faceDetected ? Colors.green : Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _faceDetected ? Icons.face : Icons.face_unlock_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
          ],
        ),

        // Status text
        if (_isCameraInitialized && _image == null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              widget.requireFaceDetection
                  ? (_faceDetected
                  ? 'Face detected! Capturing...'
                  : 'Please position your face in the camera.')
                  : 'Ready to capture',
              style: TextStyle(
                color: primaryWhite,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ),

        GestureDetector(
          onTap: _image == null ? _manualCapture : _retakePhoto,
          child: Opacity(
            opacity: (widget.requireFaceDetection && !_faceDetected && _image == null) ? 0.5 : 1.0,
            child: Container(
              width: 60,
              height: 60,
              margin: const EdgeInsets.only(top: 20, bottom: 20),
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  stops: [0.4, 0.65, 1],
                  colors: [
                    Color(0xffD9D9D9),
                    primaryWhite,
                    Color(0xffD9D9D9),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _image == null ? Icons.camera_alt : Icons.refresh,
                color: const Color(0xff2E2E2E),
              ),
            ),
          ),
        ),

      ],
    );
  }

  Future<void> _manualCapture() async {
    if (_isCameraInitialized) {
      await _capturePhoto();
    } else {
      _getImageFromGallery();
    }
  }

  Future<void> _retakePhoto() async {
    setState(() {
      _image = null;
    });
    // Face detection will automatically resume via the periodic timer
  }

  Future<void> _getImageFromGallery() async {
    setState(() {
      _image = null;
    });

    final pickedFile = await _imagePicker?.pickImage(
      source: ImageSource.camera,
      maxWidth: 400,
      maxHeight: 400,
    );

    if (pickedFile != null) {
      await _setPickedFile(pickedFile);
    }

    setState(() {});
  }

  Future<void> _setPickedFile(XFile? pickedFile) async {
    final path = pickedFile?.path;
    if (path == null) return;

    setState(() {
      _image = File(path);
    });

    final Uint8List imageBytes = await _image!.readAsBytes();
    widget.onImage(imageBytes);

    final inputImage = InputImage.fromFilePath(path);
    widget.onInputImage(inputImage);
  }
}