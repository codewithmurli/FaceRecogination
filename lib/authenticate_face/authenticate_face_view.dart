// import 'dart:async';
// import 'dart:convert';
// import 'dart:developer';
// import 'dart:math' as math;
// import 'dart:typed_data';
// import 'dart:isolate';
//
// import 'package:audioplayers/audioplayers.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:face_recogination/authenticate_face/scanning_animation/animated_view.dart';
// import 'package:face_recogination/common/utils/extensions/size_extension.dart';
// import 'package:flutter/services.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_face_api/flutter_face_api.dart' as regula;
// import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
//
// import '../common/utils/custom_snackbar.dart';
// import '../common/utils/extract_face_feature.dart';
// import '../common/views/camera_view.dart';
// import '../constants/theme.dart';
// import '../model/user_model.dart';
//
// class AuthenticateFaceView extends StatefulWidget {
//   const AuthenticateFaceView({Key? key}) : super(key: key);
//
//   @override
//   State<AuthenticateFaceView> createState() => _AuthenticateFaceViewState();
// }
//
// class _AuthenticateFaceViewState extends State<AuthenticateFaceView> {
//   final AudioPlayer _audioPlayer = AudioPlayer();
//   final FaceDetector _faceDetector = FaceDetector(
//     options: FaceDetectorOptions(
//       enableLandmarks: true,
//       performanceMode: FaceDetectorMode.accurate,
//     ),
//   );
//   FaceFeatures? _faceFeatures;
//
//   // Use FaceSDK singleton instance
//   final regula.FaceSDK _faceSDK = regula.FaceSDK.instance;
//
//   // Updated for new API
//   late regula.MatchFacesImage image1;
//   late regula.MatchFacesImage image2;
//
//   final TextEditingController _nameController = TextEditingController();
//   String _similarity = "";
//   bool _canAuthenticate = false;
//   List<dynamic> users = [];
//   bool userExists = false;
//   UserModel? loggingUser;
//   bool isMatching = false;
//   int trialNumber = 1;
//
//   // New variables for automatic authentication
//   bool _isAuthenticating = false;
//   bool _hasValidFace = false;
//   Timer? _authenticationTimer;
//   UserModel? _authenticatedUser;
//
//   // Cache for user data to avoid repeated Firebase calls
//   static List<UserModel>? _cachedUsers;
//   static DateTime? _lastCacheUpdate;
//   static const Duration _cacheValidDuration = Duration(minutes: 5);
//
//   @override
//   void initState() {
//     super.initState();
//     _initializeFaceSDK();
//     _preloadUsers(); // Preload users for faster authentication
//
//     // Initialize with dummy data - will be updated when images are set
//     image1 = regula.MatchFacesImage(
//         Uint8List(0),
//         regula.ImageType.PRINTED
//     );
//     image2 = regula.MatchFacesImage(
//         Uint8List(0),
//         regula.ImageType.PRINTED
//     );
//   }
//
//   // Preload users into cache
//   Future<void> _preloadUsers() async {
//     if (_shouldRefreshCache()) {
//       try {
//         final snap = await FirebaseFirestore.instance
//             .collection("users")
//             .limit(100) // Limit to prevent excessive data transfer
//             .get();
//
//         _cachedUsers = snap.docs
//             .map((doc) => UserModel.fromJson(doc.data()))
//             .where((user) => user.faceFeatures != null && user.image != null)
//             .toList();
//
//         _lastCacheUpdate = DateTime.now();
//         log("Preloaded ${_cachedUsers!.length} users");
//       } catch (e) {
//         log("Error preloading users: $e");
//       }
//     }
//   }
//
//   bool _shouldRefreshCache() {
//     return _cachedUsers == null ||
//         _lastCacheUpdate == null ||
//         DateTime.now().difference(_lastCacheUpdate!) > _cacheValidDuration;
//   }
//
//   // Initialize FaceSDK
//   Future<void> _initializeFaceSDK() async {
//     try {
//       final (success, exception) = await _faceSDK.initialize();
//       if (!success) {
//         log("FaceSDK initialization failed: ${exception?.message}");
//       } else {
//         log("FaceSDK initialized successfully");
//       }
//     } catch (e) {
//       log("FaceSDK initialization error: $e");
//     }
//   }
//
//   @override
//   void dispose() {
//     _faceDetector.close();
//     _audioPlayer.dispose();
//     _faceSDK.deinitialize();
//     _authenticationTimer?.cancel();
//     super.dispose();
//   }
//
//   get _playScanningAudio => _audioPlayer
//     ..setReleaseMode(ReleaseMode.loop)
//     ..play(AssetSource("scan_beep.wav"));
//
//   get _playSuccessAudio => _audioPlayer
//     ..stop()
//     ..setReleaseMode(ReleaseMode.release)
//     ..play(AssetSource("success.mp3"));
//
//   get _playFailedAudio => _audioPlayer
//     ..stop()
//     ..setReleaseMode(ReleaseMode.release)
//     ..play(AssetSource("failed.mp3"));
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       extendBodyBehindAppBar: true,
//       appBar: AppBar(
//         centerTitle: true,
//         backgroundColor: appBarColor,
//         title: const Text("Authenticate Face"),
//         elevation: 0,
//       ),
//       body: LayoutBuilder(
//         builder: (context, constrains) => Stack(
//           children: [
//             Container(
//               width: constrains.maxWidth,
//               height: constrains.maxHeight,
//               decoration: const BoxDecoration(
//                 gradient: LinearGradient(
//                   begin: Alignment.topCenter,
//                   end: Alignment.bottomCenter,
//                   colors: [
//                     scaffoldTopGradientClr,
//                     scaffoldBottomGradientClr,
//                   ],
//                 ),
//               ),
//             ),
//             Align(
//               alignment: Alignment.bottomCenter,
//               child: SingleChildScrollView(
//                 child: Column(
//                   mainAxisAlignment: MainAxisAlignment.end,
//                   children: [
//                     Container(
//                       height: 0.82.sh,
//                       width: double.infinity,
//                       padding:
//                       EdgeInsets.fromLTRB(0.05.sw, 0.025.sh, 0.05.sw, 0),
//                       decoration: BoxDecoration(
//                         color: overlayContainerClr,
//                         borderRadius: BorderRadius.only(
//                           topLeft: Radius.circular(0.03.sh),
//                           topRight: Radius.circular(0.03.sh),
//                         ),
//                       ),
//                       child: Column(
//                         children: [
//                           Stack(
//                             children: [
//                               CameraView(
//                                 onImage: (image) {
//                                   _setImage(image);
//                                 },
//                                 onInputImage: (inputImage) async {
//                                   if (!_isAuthenticating) {
//                                     setState(() => _isAuthenticating = true);
//                                     _faceFeatures = await extractFaceFeatures(
//                                         inputImage, _faceDetector);
//
//                                     // Check if face features are valid
//                                     if (_faceFeatures != null && _validateFaceFeatures(_faceFeatures!)) {
//                                       _hasValidFace = true;
//                                       _startAutoAuthentication();
//                                     } else {
//                                       _hasValidFace = false;
//                                       _stopAutoAuthentication();
//                                     }
//                                     setState(() => _isAuthenticating = false);
//                                   }
//                                 },
//                               ),
//                               if (_isAuthenticating || isMatching)
//                                 Align(
//                                   alignment: Alignment.center,
//                                   child: Padding(
//                                     padding: EdgeInsets.only(top: 0.064.sh),
//                                     child: const AnimatedView(),
//                                   ),
//                                 ),
//                               // Status indicator
//                               Positioned(
//                                 top: 20,
//                                 left: 20,
//                                 child: Container(
//                                   padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//                                   decoration: BoxDecoration(
//                                     color: _hasValidFace ? Colors.green.withOpacity(0.8) : Colors.orange.withOpacity(0.8),
//                                     borderRadius: BorderRadius.circular(20),
//                                   ),
//                                   child: Row(
//                                     mainAxisSize: MainAxisSize.min,
//                                     children: [
//                                       Icon(
//                                         _hasValidFace ? Icons.face : Icons.face_retouching_natural,
//                                         color: Colors.white,
//                                         size: 16,
//                                       ),
//                                       const SizedBox(width: 4),
//                                       Text(
//                                         _hasValidFace ? "Face Detected" : "Position Face",
//                                         style: const TextStyle(
//                                           color: Colors.white,
//                                           fontSize: 12,
//                                           fontWeight: FontWeight.w500,
//                                         ),
//                                       ),
//                                     ],
//                                   ),
//                                 ),
//                               ),
//                             ],
//                           ),
//                           const Spacer(),
//                           // Instruction text
//                           Container(
//                             padding: const EdgeInsets.all(16),
//                             child: Text(
//                               _hasValidFace
//                                   ? "Authentication in progress..."
//                                   : "Position your face in the camera frame",
//                               style: TextStyle(
//                                 color: textColor.withOpacity(0.7),
//                                 fontSize: 16,
//                                 fontWeight: FontWeight.w500,
//                               ),
//                               textAlign: TextAlign.center,
//                             ),
//                           ),
//                           SizedBox(height: 0.038.sh),
//                         ],
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             )
//           ],
//         ),
//       ),
//     );
//   }
//
//   // Validate if face features are sufficient for authentication
//   bool _validateFaceFeatures(FaceFeatures features) {
//     return features.rightEye != null &&
//         features.leftEye != null &&
//         features.rightEar != null &&
//         features.leftEar != null &&
//         features.noseBase != null &&
//         features.bottomMouth != null;
//   }
//
//   // Start automatic authentication process
//   void _startAutoAuthentication() {
//     _authenticationTimer?.cancel();
//     _authenticationTimer = Timer(const Duration(milliseconds: 1500), () {
//       if (_hasValidFace && _canAuthenticate && !isMatching) {
//         _performAuthentication();
//       }
//     });
//   }
//
//   // Stop automatic authentication
//   void _stopAutoAuthentication() {
//     _authenticationTimer?.cancel();
//   }
//
//   // Perform the authentication
//   void _performAuthentication() {
//     if (!mounted) return;
//
//     setState(() => isMatching = true);
//     _playScanningAudio;
//     _matchFaceOptimized();
//   }
//
//   Future _setImage(Uint8List imageToAuthenticate) async {
//     // Updated for new API
//     image2 = regula.MatchFacesImage(
//         imageToAuthenticate,
//         regula.ImageType.PRINTED
//     );
//
//     setState(() {
//       _canAuthenticate = true;
//     });
//   }
//
//   // OPTIMIZED: Fast face matching using cached data and parallel processing
//   Future<void> _matchFaceOptimized() async {
//     try {
//       // Ensure we have cached users
//       if (_shouldRefreshCache()) {
//         await _preloadUsers();
//       }
//
//       if (_cachedUsers == null || _cachedUsers!.isEmpty) {
//         _showFailureDialog(
//           title: "No Users Registered",
//           description: "Make sure users are registered first before Authenticating.",
//         );
//         return;
//       }
//
//       // Pre-filter users based on face features similarity (much faster than SDK matching)
//       final preFilteredUsers = await _preFilterUsers(_cachedUsers!);
//       log("Pre-filtered to ${preFilteredUsers.length} users");
//
//       if (preFilteredUsers.isEmpty) {
//         _showFailureDialog(
//           title: "Authentication Failed",
//           description: "No matching faces found. Please try again.",
//         );
//         return;
//       }
//
//       // Now use SDK matching only on pre-filtered users
//       UserModel? matchedUser = await _performSDKMatching(preFilteredUsers);
//
//       if (matchedUser != null) {
//         setState(() {
//           trialNumber = 1;
//           isMatching = false;
//           _authenticatedUser = matchedUser;
//         });
//
//         if (mounted) {
//           _showSuccessBottomSheet(matchedUser);
//         }
//       } else {
//         _handleMatchingFailure();
//       }
//
//     } catch (e) {
//       log("Optimized matching error: $e");
//       setState(() => isMatching = false);
//       _playFailedAudio;
//       CustomSnackBar.errorSnackBar("Something went wrong. Please try again.");
//     }
//   }
//
//   // Pre-filter users using lightweight face feature comparison
//   Future<List<UserModel>> _preFilterUsers(List<UserModel> allUsers) async {
//     if (_faceFeatures == null) return [];
//
//     final filteredUsers = <UserModel>[];
//
//     for (final user in allUsers) {
//       if (user.faceFeatures != null) {
//         final similarity = compareFaces(_faceFeatures!, user.faceFeatures!);
//         // Use a wider threshold for pre-filtering to avoid false negatives
//         if (similarity >= 0.7 && similarity <= 2.0) {
//           filteredUsers.add(user);
//         }
//       }
//     }
//
//     // Sort by similarity for better performance (most likely matches first)
//     filteredUsers.sort((a, b) {
//       final similarityA = compareFaces(_faceFeatures!, a.faceFeatures!);
//       final similarityB = compareFaces(_faceFeatures!, b.faceFeatures!);
//       return ((similarityA - 1).abs()).compareTo((similarityB - 1).abs());
//     });
//
//     return filteredUsers;
//   }
//
//   // Perform SDK matching on pre-filtered users
//   Future<UserModel?> _performSDKMatching(List<UserModel> users) async {
//     for (final user in users) {
//       try {
//         final imageBase64 = user.image;
//         if (imageBase64 == null) continue;
//
//         // Decode base64 efficiently
//         final userImageBytes = base64Decode(imageBase64);
//         image1 = regula.MatchFacesImage(
//             userImageBytes,
//             regula.ImageType.PRINTED
//         );
//
//         // Check if FaceSDK is initialized
//         bool isInitialized = await _faceSDK.isInitialized();
//         if (!isInitialized) {
//           await _initializeFaceSDK();
//         }
//
//         // Perform matching
//         var request = regula.MatchFacesRequest([image1, image2]);
//         var response = await _faceSDK.matchFaces(request);
//
//         if (response.results.isNotEmpty) {
//           double similarity = response.results.first.similarity ?? 0.0;
//
//           setState(() {
//             _similarity = (similarity * 100).toStringAsFixed(2);
//           });
//
//           log("SDK Similarity with ${user.name}: $_similarity%");
//
//           if (similarity > 0.90) { // 90% threshold
//             return user;
//           }
//         }
//       } catch (e) {
//         log("SDK matching error for user ${user.name}: $e");
//         continue; // Try next user
//       }
//     }
//
//     return null; // No match found
//   }
//
//   void _handleMatchingFailure() {
//     if (trialNumber == 4) {
//       setState(() => trialNumber = 1);
//       _showFailureDialog(
//         title: "Authentication Failed",
//         description: "Face doesn't match. Please try again.",
//       );
//     } else if (trialNumber == 3) {
//       _audioPlayer.stop();
//       setState(() {
//         isMatching = false;
//         trialNumber++;
//       });
//       _showNameInputDialog();
//     } else {
//       setState(() => trialNumber++);
//       _showFailureDialog(
//         title: "Authentication Failed",
//         description: "Face doesn't match. Please try again.",
//       );
//     }
//   }
//
//   void _showNameInputDialog() {
//     showDialog(
//         context: context,
//         builder: (context) {
//           return AlertDialog(
//             title: const Text("Enter Organization ID"),
//             content: TextFormField(
//               controller: _nameController,
//               cursorColor: accentColor,
//               decoration: InputDecoration(
//                 enabledBorder: OutlineInputBorder(
//                   borderSide: const BorderSide(
//                     width: 2,
//                     color: accentColor,
//                   ),
//                   borderRadius: BorderRadius.circular(4),
//                 ),
//                 focusedBorder: OutlineInputBorder(
//                   borderSide: const BorderSide(
//                     width: 2,
//                     color: accentColor,
//                   ),
//                   borderRadius: BorderRadius.circular(4),
//                 ),
//               ),
//             ),
//             actions: [
//               TextButton(
//                 onPressed: () {
//                   if (_nameController.text.trim().isEmpty) {
//                     CustomSnackBar.errorSnackBar("Enter an ID to proceed");
//                   } else {
//                     Navigator.of(context).pop();
//                     setState(() => isMatching = true);
//                     _playScanningAudio;
//                     _fetchUserByName(_nameController.text.trim());
//                   }
//                 },
//                 child: const Text(
//                   "Done",
//                   style: TextStyle(
//                     color: accentColor,
//                   ),
//                 ),
//               )
//             ],
//           );
//         });
//   }
//
//   // Show success bottom sheet
//   void _showSuccessBottomSheet(UserModel user) {
//     _playSuccessAudio;
//
//     showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       backgroundColor: Colors.transparent,
//       builder: (context) => Container(
//         height: MediaQuery.of(context).size.height * 0.4,
//         decoration: const BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.only(
//             topLeft: Radius.circular(25),
//             topRight: Radius.circular(25),
//           ),
//         ),
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             // Success animation
//             TweenAnimationBuilder<double>(
//               duration: const Duration(milliseconds: 600),
//               tween: Tween(begin: 0.0, end: 1.0),
//               builder: (context, value, child) {
//                 return Transform.scale(
//                   scale: value,
//                   child: const CircleAvatar(
//                     radius: 50,
//                     backgroundColor: Colors.green,
//                     child: Icon(
//                       Icons.check,
//                       color: Colors.white,
//                       size: 50,
//                     ),
//                   ),
//                 );
//               },
//             ),
//             const SizedBox(height: 24),
//             const Text(
//               "Authentication Successful!",
//               style: TextStyle(
//                 fontSize: 24,
//                 fontWeight: FontWeight.bold,
//                 color: Colors.green,
//               ),
//             ),
//             const SizedBox(height: 16),
//             Text(
//               "Welcome, ${user.name}!",
//               style: const TextStyle(
//                 fontSize: 20,
//                 fontWeight: FontWeight.w600,
//                 color: Colors.black87,
//               ),
//             ),
//             const SizedBox(height: 8),
//             Text(
//               "You have been successfully authenticated",
//               style: TextStyle(
//                 fontSize: 16,
//                 color: Colors.grey[600],
//               ),
//               textAlign: TextAlign.center,
//             ),
//             const SizedBox(height: 24),
//             Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 20),
//               child: ElevatedButton(
//                 onPressed: () {
//                   Navigator.of(context).pop();
//                   // Reset for next authentication
//                   _resetAuthentication();
//                 },
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.green,
//                   foregroundColor: Colors.white,
//                   minimumSize: const Size(double.infinity, 50),
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(25),
//                   ),
//                 ),
//                 child: const Text(
//                   "Continue",
//                   style: TextStyle(
//                     fontSize: 18,
//                     fontWeight: FontWeight.w600,
//                   ),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   // Reset authentication state
//   void _resetAuthentication() {
//     setState(() {
//       _hasValidFace = false;
//       _canAuthenticate = false;
//       isMatching = false;
//       trialNumber = 1;
//       _authenticatedUser = null;
//     });
//     _stopAutoAuthentication();
//   }
//
//   double compareFaces(FaceFeatures face1, FaceFeatures face2) {
//     double distEar1 = euclideanDistance(face1.rightEar!, face1.leftEar!);
//     double distEar2 = euclideanDistance(face2.rightEar!, face2.leftEar!);
//
//     double ratioEar = distEar1 / distEar2;
//
//     double distEye1 = euclideanDistance(face1.rightEye!, face1.leftEye!);
//     double distEye2 = euclideanDistance(face2.rightEye!, face2.leftEye!);
//
//     double ratioEye = distEye1 / distEye2;
//
//     double distCheek1 = euclideanDistance(face1.rightCheek!, face1.leftCheek!);
//     double distCheek2 = euclideanDistance(face2.rightCheek!, face2.leftCheek!);
//
//     double ratioCheek = distCheek1 / distCheek2;
//
//     double distMouth1 = euclideanDistance(face1.rightMouth!, face1.leftMouth!);
//     double distMouth2 = euclideanDistance(face2.rightMouth!, face2.leftMouth!);
//
//     double ratioMouth = distMouth1 / distMouth2;
//
//     double distNoseToMouth1 =
//     euclideanDistance(face1.noseBase!, face1.bottomMouth!);
//     double distNoseToMouth2 =
//     euclideanDistance(face2.noseBase!, face2.bottomMouth!);
//
//     double ratioNoseToMouth = distNoseToMouth1 / distNoseToMouth2;
//
//     double ratio =
//         (ratioEye + ratioEar + ratioCheek + ratioMouth + ratioNoseToMouth) / 5;
//
//     return ratio;
//   }
//
//   // A function to calculate the Euclidean distance between two points
//   double euclideanDistance(Points p1, Points p2) {
//     final sqr =
//     math.sqrt(math.pow((p1.x! - p2.x!), 2) + math.pow((p1.y! - p2.y!), 2));
//     return sqr;
//   }
//
//   _fetchUserByName(String orgID) {
//     FirebaseFirestore.instance
//         .collection("users")
//         .where("organizationId", isEqualTo: orgID)
//         .limit(1) // Optimization: limit to 1 result
//         .get()
//         .catchError((e) {
//       log("Getting User Error: $e");
//       setState(() => isMatching = false);
//       _playFailedAudio;
//       CustomSnackBar.errorSnackBar("Something went wrong. Please try again.");
//     }).then((snap) {
//       if (snap.docs.isNotEmpty) {
//         users.clear();
//         for (var doc in snap.docs) {
//           setState(() {
//             users.add([UserModel.fromJson(doc.data()), 1]);
//           });
//         }
//         _matchFaces();
//       } else {
//         setState(() => trialNumber = 1);
//         _showFailureDialog(
//           title: "User Not Found",
//           description:
//           "User is not registered yet. Register first to authenticate.",
//         );
//       }
//     });
//   }
//
//   // Legacy method for backward compatibility
//   _matchFaces() async {
//     bool faceMatched = false;
//     for (List user in users) {
//       String? imageBase64 = (user.first as UserModel).image;
//       if (imageBase64 == null) {
//         log("User image is null, skipping");
//         continue;
//       }
//
//       Uint8List userImageBytes = base64Decode(imageBase64);
//       image1 = regula.MatchFacesImage(
//           userImageBytes,
//           regula.ImageType.PRINTED
//       );
//
//       try {
//         bool isInitialized = await _faceSDK.isInitialized();
//         if (!isInitialized) {
//           log("FaceSDK not initialized, attempting to initialize...");
//           await _initializeFaceSDK();
//         }
//
//         var request = regula.MatchFacesRequest([image1, image2]);
//         var response = await _faceSDK.matchFaces(request);
//
//         if (response.results.isNotEmpty) {
//           double similarity = response.results.first.similarity ?? 0.0;
//
//           setState(() {
//             _similarity = (similarity * 100).toStringAsFixed(2);
//             log("similarity: $_similarity");
//
//             if (similarity > 0.90) {
//               faceMatched = true;
//               loggingUser = user.first;
//               _authenticatedUser = user.first;
//             } else {
//               faceMatched = false;
//             }
//           });
//         } else {
//           setState(() {
//             _similarity = "0.00";
//             faceMatched = false;
//           });
//         }
//       } catch (e) {
//         log("Face matching error: $e");
//         setState(() {
//           _similarity = "error";
//           faceMatched = false;
//         });
//       }
//
//       if (faceMatched) {
//         setState(() {
//           trialNumber = 1;
//           isMatching = false;
//         });
//
//         if (mounted) {
//           _showSuccessBottomSheet(_authenticatedUser!);
//         }
//         break;
//       }
//     }
//
//     if (!faceMatched) {
//       _handleMatchingFailure();
//     }
//   }
//
//   _showFailureDialog({
//     required String title,
//     required String description,
//   }) {
//     _playFailedAudio;
//     setState(() => isMatching = false);
//     showDialog(
//       context: context,
//       builder: (context) {
//         return AlertDialog(
//           title: Text(title),
//           content: Text(description),
//           actions: [
//             TextButton(
//               onPressed: () {
//                 Navigator.of(context).pop();
//                 _resetAuthentication();
//               },
//               child: const Text(
//                 "Ok",
//                 style: TextStyle(
//                   color: accentColor,
//                 ),
//               ),
//             )
//           ],
//         );
//       },
//     );
//   }
// }


import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:face_recogination/authenticate_face/scanning_animation/animated_view.dart';
import 'package:face_recogination/common/utils/extensions/size_extension.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_face_api/flutter_face_api.dart' as regula;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../common/utils/custom_snackbar.dart';
import '../common/utils/extract_face_feature.dart';
import '../common/views/camera_view.dart';
import '../constants/theme.dart';
import '../model/user_model.dart';

class AuthenticateFaceView extends StatefulWidget {
  const AuthenticateFaceView({Key? key}) : super(key: key);

  @override
  State<AuthenticateFaceView> createState() => _AuthenticateFaceViewState();
}

class _AuthenticateFaceViewState extends State<AuthenticateFaceView> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableLandmarks: true,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );
  FaceFeatures? _faceFeatures;

  // Use FaceSDK singleton instance
  final regula.FaceSDK _faceSDK = regula.FaceSDK.instance;

  // Updated for new API
  late regula.MatchFacesImage image1;
  late regula.MatchFacesImage image2;

  final TextEditingController _nameController = TextEditingController();
  String _similarity = "";
  bool _canAuthenticate = false;
  List<dynamic> users = [];
  bool userExists = false;
  UserModel? loggingUser;
  bool isMatching = false;
  int trialNumber = 1;

  // Updated variables - removed authentication timer
  bool _isAuthenticating = false;
  bool _hasValidFace = false;
  // Removed Timer? _authenticationTimer;
  UserModel? _authenticatedUser;

  // Cache for user data to avoid repeated Firebase calls
  static List<UserModel>? _cachedUsers;
  static DateTime? _lastCacheUpdate;
  static const Duration _cacheValidDuration = Duration(minutes: 5);

  @override
  void initState() {
    super.initState();
    _initializeFaceSDK();
    _preloadUsers(); // Preload users for faster authentication

    // Initialize with dummy data - will be updated when images are set
    image1 = regula.MatchFacesImage(
        Uint8List(0),
        regula.ImageType.PRINTED
    );
    image2 = regula.MatchFacesImage(
        Uint8List(0),
        regula.ImageType.PRINTED
    );
  }

  // Preload users into cache
  Future<void> _preloadUsers() async {
    if (_shouldRefreshCache()) {
      try {
        final snap = await FirebaseFirestore.instance
            .collection("users")
            .limit(100) // Limit to prevent excessive data transfer
            .get();

        _cachedUsers = snap.docs
            .map((doc) => UserModel.fromJson(doc.data()))
            .where((user) => user.faceFeatures != null && user.image != null)
            .toList();

        _lastCacheUpdate = DateTime.now();
        log("Preloaded ${_cachedUsers!.length} users");
      } catch (e) {
        log("Error preloading users: $e");
      }
    }
  }

  bool _shouldRefreshCache() {
    return _cachedUsers == null ||
        _lastCacheUpdate == null ||
        DateTime.now().difference(_lastCacheUpdate!) > _cacheValidDuration;
  }

  // Initialize FaceSDK
  Future<void> _initializeFaceSDK() async {
    try {
      final (success, exception) = await _faceSDK.initialize();
      if (!success) {
        log("FaceSDK initialization failed: ${exception?.message}");
      } else {
        log("FaceSDK initialized successfully");
      }
    } catch (e) {
      log("FaceSDK initialization error: $e");
    }
  }

  @override
  void dispose() {
    _faceDetector.close();
    _audioPlayer.dispose();
    _faceSDK.deinitialize();
    // Removed _authenticationTimer?.cancel();
    super.dispose();
  }

  get _playScanningAudio => _audioPlayer
    ..setReleaseMode(ReleaseMode.loop)
    ..play(AssetSource("scan_beep.wav"));

  get _playSuccessAudio => _audioPlayer
    ..stop()
    ..setReleaseMode(ReleaseMode.release)
    ..play(AssetSource("success.mp3"));

  get _playFailedAudio => _audioPlayer
    ..stop()
    ..setReleaseMode(ReleaseMode.release)
    ..play(AssetSource("failed.mp3"));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: appBarColor,
        title: const Text("Authenticate Face"),
        elevation: 0,
      ),
      body: LayoutBuilder(
        builder: (context, constrains) => Stack(
          children: [
            Container(
              width: constrains.maxWidth,
              height: constrains.maxHeight,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    scaffoldTopGradientClr,
                    scaffoldBottomGradientClr,
                  ],
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      height: 0.82.sh,
                      width: double.infinity,
                      padding:
                      EdgeInsets.fromLTRB(0.05.sw, 0.025.sh, 0.05.sw, 0),
                      decoration: BoxDecoration(
                        color: overlayContainerClr,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(0.03.sh),
                          topRight: Radius.circular(0.03.sh),
                        ),
                      ),
                      child: Column(
                        children: [
                          Stack(
                            children: [
                              CameraView(
                                onImage: (image) {
                                  _setImage(image);
                                },
                                onInputImage: (inputImage) async {
                                  if (!_isAuthenticating) {
                                    setState(() => _isAuthenticating = true);
                                    _faceFeatures = await extractFaceFeatures(
                                        inputImage, _faceDetector);

                                    // Check if face features are valid
                                    if (_faceFeatures != null && _validateFaceFeatures(_faceFeatures!)) {
                                      _hasValidFace = true;
                                      // CHANGED: Immediately start authentication (no delay)
                                      _performAuthentication();
                                    } else {
                                      _hasValidFace = false;
                                    }
                                    setState(() => _isAuthenticating = false);
                                  }
                                },
                              ),
                              if (_isAuthenticating || isMatching)
                                Align(
                                  alignment: Alignment.center,
                                  child: Padding(
                                    padding: EdgeInsets.only(top: 0.064.sh),
                                    child: const AnimatedView(),
                                  ),
                                ),
                              // Status indicator
                              Positioned(
                                top: 20,
                                left: 20,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: _hasValidFace ? Colors.green.withOpacity(0.8) : Colors.orange.withOpacity(0.8),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _hasValidFace ? Icons.face : Icons.face_retouching_natural,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _hasValidFace ? "Face Detected" : "Position Face",
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          // Instruction text
                          Container(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              _hasValidFace
                                  ? "Authentication in progress..."
                                  : "Position your face in the camera frame",
                              style: TextStyle(
                                color: textColor.withOpacity(0.7),
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          SizedBox(height: 0.038.sh),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  // Validate if face features are sufficient for authentication
  bool _validateFaceFeatures(FaceFeatures features) {
    return features.rightEye != null &&
        features.leftEye != null &&
        features.rightEar != null &&
        features.leftEar != null &&
        features.noseBase != null &&
        features.bottomMouth != null;
  }

  // Removed timer-based authentication methods
  // void _startAutoAuthentication() { ... }
  // void _stopAutoAuthentication() { ... }

  // Perform the authentication immediately
  void _performAuthentication() {
    if (!mounted) return;

    setState(() => isMatching = true);
    _playScanningAudio;
    _matchFaceOptimized();
  }

  Future _setImage(Uint8List imageToAuthenticate) async {
    // Updated for new API
    image2 = regula.MatchFacesImage(
        imageToAuthenticate,
        regula.ImageType.PRINTED
    );

    setState(() {
      _canAuthenticate = true;
    });
  }

  // OPTIMIZED: Fast face matching using cached data and parallel processing
  Future<void> _matchFaceOptimized() async {
    try {
      // Ensure we have cached users
      if (_shouldRefreshCache()) {
        await _preloadUsers();
      }

      if (_cachedUsers == null || _cachedUsers!.isEmpty) {
        _showFailureDialog(
          title: "No Users Registered",
          description: "Make sure users are registered first before Authenticating.",
        );
        return;
      }

      // Pre-filter users based on face features similarity (much faster than SDK matching)
      final preFilteredUsers = await _preFilterUsers(_cachedUsers!);
      log("Pre-filtered to ${preFilteredUsers.length} users");

      if (preFilteredUsers.isEmpty) {
        _showFailureDialog(
          title: "Authentication Failed",
          description: "No matching faces found. Please try again.",
        );
        return;
      }

      // Now use SDK matching only on pre-filtered users
      UserModel? matchedUser = await _performSDKMatching(preFilteredUsers);

      if (matchedUser != null) {
        setState(() {
          trialNumber = 1;
          isMatching = false;
          _authenticatedUser = matchedUser;
        });

        if (mounted) {
          _showSuccessBottomSheet(matchedUser);
        }
      } else {
        _handleMatchingFailure();
      }

    } catch (e) {
      log("Optimized matching error: $e");
      setState(() => isMatching = false);
      _playFailedAudio;
      CustomSnackBar.errorSnackBar("Something went wrong. Please try again.");
    }
  }

  // Pre-filter users using lightweight face feature comparison
  Future<List<UserModel>> _preFilterUsers(List<UserModel> allUsers) async {
    if (_faceFeatures == null) return [];

    final filteredUsers = <UserModel>[];

    for (final user in allUsers) {
      if (user.faceFeatures != null) {
        final similarity = compareFaces(_faceFeatures!, user.faceFeatures!);
        // Use a wider threshold for pre-filtering to avoid false negatives
        if (similarity >= 0.7 && similarity <= 2.0) {
          filteredUsers.add(user);
        }
      }
    }

    // Sort by similarity for better performance (most likely matches first)
    filteredUsers.sort((a, b) {
      final similarityA = compareFaces(_faceFeatures!, a.faceFeatures!);
      final similarityB = compareFaces(_faceFeatures!, b.faceFeatures!);
      return ((similarityA - 1).abs()).compareTo((similarityB - 1).abs());
    });

    return filteredUsers;
  }

  // Perform SDK matching on pre-filtered users
  Future<UserModel?> _performSDKMatching(List<UserModel> users) async {
    for (final user in users) {
      try {
        final imageBase64 = user.image;
        if (imageBase64 == null) continue;

        // Decode base64 efficiently
        final userImageBytes = base64Decode(imageBase64);
        image1 = regula.MatchFacesImage(
            userImageBytes,
            regula.ImageType.PRINTED
        );

        // Check if FaceSDK is initialized
        bool isInitialized = await _faceSDK.isInitialized();
        if (!isInitialized) {
          await _initializeFaceSDK();
        }

        // Perform matching
        var request = regula.MatchFacesRequest([image1, image2]);
        var response = await _faceSDK.matchFaces(request);

        if (response.results.isNotEmpty) {
          double similarity = response.results.first.similarity ?? 0.0;

          setState(() {
            _similarity = (similarity * 100).toStringAsFixed(2);
          });

          log("SDK Similarity with ${user.name}: $_similarity%");

          if (similarity > 0.90) { // 90% threshold
            return user;
          }
        }
      } catch (e) {
        log("SDK matching error for user ${user.name}: $e");
        continue; // Try next user
      }
    }

    return null; // No match found
  }

  void _handleMatchingFailure() {
    if (trialNumber == 4) {
      setState(() => trialNumber = 1);
      _showFailureDialog(
        title: "Authentication Failed",
        description: "Face doesn't match. Please try again.",
      );
    } else if (trialNumber == 3) {
      _audioPlayer.stop();
      setState(() {
        isMatching = false;
        trialNumber++;
      });
      _showNameInputDialog();
    } else {
      setState(() => trialNumber++);
      _showFailureDialog(
        title: "Authentication Failed",
        description: "Face doesn't match. Please try again.",
      );
    }
  }

  void _showNameInputDialog() {
    showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text("Enter Organization ID"),
            content: TextFormField(
              controller: _nameController,
              cursorColor: accentColor,
              decoration: InputDecoration(
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(
                    width: 2,
                    color: accentColor,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(
                    width: 2,
                    color: accentColor,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  if (_nameController.text.trim().isEmpty) {
                    CustomSnackBar.errorSnackBar("Enter an ID to proceed");
                  } else {
                    Navigator.of(context).pop();
                    setState(() => isMatching = true);
                    _playScanningAudio;
                    _fetchUserByName(_nameController.text.trim());
                  }
                },
                child: const Text(
                  "Done",
                  style: TextStyle(
                    color: accentColor,
                  ),
                ),
              )
            ],
          );
        });
  }

  // Show success bottom sheet
  void _showSuccessBottomSheet(UserModel user) {
    _playSuccessAudio;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.4,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(25),
            topRight: Radius.circular(25),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Success animation
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 600),
              tween: Tween(begin: 0.0, end: 1.0),
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: const CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.green,
                    child: Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 50,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            const Text(
              "Authentication Successful!",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "Welcome, ${user.name}!",
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "You have been successfully authenticated",
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  // Reset for next authentication
                  _resetAuthentication();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: const Text(
                  "Continue",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Reset authentication state
  void _resetAuthentication() {
    setState(() {
      _hasValidFace = false;
      _canAuthenticate = false;
      isMatching = false;
      trialNumber = 1;
      _authenticatedUser = null;
    });
    // Removed _stopAutoAuthentication();
  }

  double compareFaces(FaceFeatures face1, FaceFeatures face2) {
    double distEar1 = euclideanDistance(face1.rightEar!, face1.leftEar!);
    double distEar2 = euclideanDistance(face2.rightEar!, face2.leftEar!);

    double ratioEar = distEar1 / distEar2;

    double distEye1 = euclideanDistance(face1.rightEye!, face1.leftEye!);
    double distEye2 = euclideanDistance(face2.rightEye!, face2.leftEye!);

    double ratioEye = distEye1 / distEye2;

    double distCheek1 = euclideanDistance(face1.rightCheek!, face1.leftCheek!);
    double distCheek2 = euclideanDistance(face2.rightCheek!, face2.leftCheek!);

    double ratioCheek = distCheek1 / distCheek2;

    double distMouth1 = euclideanDistance(face1.rightMouth!, face1.leftMouth!);
    double distMouth2 = euclideanDistance(face2.rightMouth!, face2.leftMouth!);

    double ratioMouth = distMouth1 / distMouth2;

    double distNoseToMouth1 =
    euclideanDistance(face1.noseBase!, face1.bottomMouth!);
    double distNoseToMouth2 =
    euclideanDistance(face2.noseBase!, face2.bottomMouth!);

    double ratioNoseToMouth = distNoseToMouth1 / distNoseToMouth2;

    double ratio =
        (ratioEye + ratioEar + ratioCheek + ratioMouth + ratioNoseToMouth) / 5;

    return ratio;
  }

  // A function to calculate the Euclidean distance between two points
  double euclideanDistance(Points p1, Points p2) {
    final sqr =
    math.sqrt(math.pow((p1.x! - p2.x!), 2) + math.pow((p1.y! - p2.y!), 2));
    return sqr;
  }

  _fetchUserByName(String orgID) {
    FirebaseFirestore.instance
        .collection("users")
        .where("organizationId", isEqualTo: orgID)
        .limit(1) // Optimization: limit to 1 result
        .get()
        .catchError((e) {
      log("Getting User Error: $e");
      setState(() => isMatching = false);
      _playFailedAudio;
      CustomSnackBar.errorSnackBar("Something went wrong. Please try again.");
    }).then((snap) {
      if (snap.docs.isNotEmpty) {
        users.clear();
        for (var doc in snap.docs) {
          setState(() {
            users.add([UserModel.fromJson(doc.data()), 1]);
          });
        }
        _matchFaces();
      } else {
        setState(() => trialNumber = 1);
        _showFailureDialog(
          title: "User Not Found",
          description:
          "User is not registered yet. Register first to authenticate.",
        );
      }
    });
  }

  // Legacy method for backward compatibility
  _matchFaces() async {
    bool faceMatched = false;
    for (List user in users) {
      String? imageBase64 = (user.first as UserModel).image;
      if (imageBase64 == null) {
        log("User image is null, skipping");
        continue;
      }

      Uint8List userImageBytes = base64Decode(imageBase64);
      image1 = regula.MatchFacesImage(
          userImageBytes,
          regula.ImageType.PRINTED
      );

      try {
        bool isInitialized = await _faceSDK.isInitialized();
        if (!isInitialized) {
          log("FaceSDK not initialized, attempting to initialize...");
          await _initializeFaceSDK();
        }

        var request = regula.MatchFacesRequest([image1, image2]);
        var response = await _faceSDK.matchFaces(request);

        if (response.results.isNotEmpty) {
          double similarity = response.results.first.similarity ?? 0.0;

          setState(() {
            _similarity = (similarity * 100).toStringAsFixed(2);
            log("similarity: $_similarity");

            if (similarity > 0.90) {
              faceMatched = true;
              loggingUser = user.first;
              _authenticatedUser = user.first;
            } else {
              faceMatched = false;
            }
          });
        } else {
          setState(() {
            _similarity = "0.00";
            faceMatched = false;
          });
        }
      } catch (e) {
        log("Face matching error: $e");
        setState(() {
          _similarity = "error";
          faceMatched = false;
        });
      }

      if (faceMatched) {
        setState(() {
          trialNumber = 1;
          isMatching = false;
        });

        if (mounted) {
          _showSuccessBottomSheet(_authenticatedUser!);
        }
        break;
      }
    }

    if (!faceMatched) {
      _handleMatchingFailure();
    }
  }

  _showFailureDialog({
    required String title,
    required String description,
  }) {
    _playFailedAudio;
    setState(() => isMatching = false);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(description),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _resetAuthentication();
              },
              child: const Text(
                "Ok",
                style: TextStyle(
                  color: accentColor,
                ),
              ),
            )
          ],
        );
      },
    );
  }
}