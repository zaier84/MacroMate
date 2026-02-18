import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../services/api_service.dart';

class SnapMealScreen extends StatefulWidget {
  const SnapMealScreen({super.key});

  @override
  State<SnapMealScreen> createState() => _SnapMealScreenState();
}

class _SnapMealScreenState extends State<SnapMealScreen> {
  final ApiService _api = ApiService();

  File? snappedImage;
  bool isAnalyzing = false;
  bool isLogging = false;

  List<Map<String, dynamic>> detectedFoods = [];

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 300), () {
      openCamera();
    });
  }

  // ---------------- CAMERA ----------------

  Future<void> openCamera() async {
    try {
      final ImagePicker picker = ImagePicker();

      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 70,
      );

      if (!mounted) return;

      if (photo != null) {
        setState(() {
          snappedImage = File(photo.path);
          detectedFoods.clear();
        });

        await _analyzeMeal(photo.path);
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Camera cancelled')));
      }
    } catch (e) {
      debugPrint("Camera error: $e");
    }
  }

  // ---------------- AI ANALYSIS ----------------

  Future<void> _analyzeMeal(String imagePath) async {
    setState(() => isAnalyzing = true);

    try {
      final byteData = await rootBundle.load('assets/sample_meal.jpeg');
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/sample_meal.jpeg');
      await file.writeAsBytes(byteData.buffer.asUint8List());

      final multipartFile = await http.MultipartFile.fromPath(
        "file",
        file.path,
      );

      final res = await _api.postMultipart(
        "/api/ai/snap-meal",
        fields: {},
        files: [multipartFile],
      );

      final responseBody = await res.stream.bytesToString();

      if (res.statusCode != 200) {
        throw Exception(responseBody);
      }

      final decoded = jsonDecode(responseBody);

      setState(() {
        detectedFoods = List<Map<String, dynamic>>.from(decoded["foods"]);
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Meal analysis failed: $e")));
    } finally {
      if (mounted) setState(() => isAnalyzing = false);
    }
  }

  // ---------------- LOG MEAL ----------------

  Future<void> _logMeal() async {
    if (detectedFoods.isEmpty || isLogging) return;

    setState(() => isLogging = true);

    try {
      final payload = _buildMealPayload();
      final body = jsonEncode(payload);

      final res = await _api.post("/api/nutrition/log", body);

      if (res.statusCode == 200 || res.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Meal logged successfully.")),
        );

        setState(() {
          snappedImage = null;
          detectedFoods.clear();
        });
      } else {
        throw Exception("Failed to log meal");
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Failed to log meal.")));
    } finally {
      if (mounted) setState(() => isLogging = false);
    }
  }

  Map<String, dynamic> _buildMealPayload() {
    return {
      "foods": detectedFoods.map((f) {
        return {
          "name": f["name"],
          "quantity": f["quantity"],
          "unit": f["unit"],
          "calories": f["calories"],
          "protein_g": f["protein_g"],
          "carbs_g": f["carbs_g"],
          "fats_g": f["fats_g"],
          "food_api_id": f["food_api_id"],
        };
      }).toList(),
    };
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text("Snap Meal"),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Header
              _buildHeader(),

              const SizedBox(height: 16),

              // Snap Button
              _buildSnapButton(),

              const SizedBox(height: 16),

              // Main Content
              Expanded(child: _buildMainContent()),

              if (detectedFoods.isNotEmpty) _buildLogButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text(
          "AI Meal Scanner",
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 6),
        Text(
          "Snap your meal and let AI calculate your macros",
          style: TextStyle(color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildSnapButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: openCamera,
        icon: const Icon(Icons.camera_alt),
        label: const Text("Snap Meal"),
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    if (isAnalyzing) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text("Analyzing your meal..."),
          ],
        ),
      );
    }

    if (snappedImage == null) {
      return const Center(
        child: Text(
          "Snap a meal to get started",
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return Column(
      children: [
        _buildImageCard(),
        const SizedBox(height: 16),
        _buildDetectedFoods(),
      ],
    );
  }

  Widget _buildImageCard() {
    return Container(
      height: 220,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Image.asset("assets/sample_meal.jpeg", fit: BoxFit.cover),
      ),
    );
  }

  Widget _buildDetectedFoods() {
    if (detectedFoods.isEmpty) return const SizedBox();

    return Expanded(
      child: ListView.builder(
        itemCount: detectedFoods.length,
        itemBuilder: (_, i) {
          final f = detectedFoods[i];
          return _buildFoodCard(f);
        },
      ),
    );
  }

  Widget _buildFoodCard(Map<String, dynamic> food) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            food["name"],
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text("${food["quantity"]}${food["unit"]} • ${food["calories"]} kcal"),
          const SizedBox(height: 8),
          Row(
            children: [
              _macroChip("Protein", "${food["protein_g"]}g"),
              _macroChip("Carbs", "${food["carbs_g"]}g"),
              _macroChip("Fats", "${food["fats_g"]}g"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _macroChip(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        "$label $value",
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildLogButton() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: isLogging ? null : _logMeal,
          child: isLogging
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text("Log Meal"),
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

// import 'dart:convert';
// import 'dart:io';
//
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:http/http.dart' as http;
// import 'package:path_provider/path_provider.dart';
//
// import '../../services/api_service.dart';
//
// class SnapMealScreen extends StatefulWidget {
//   const SnapMealScreen({super.key});
//
//   @override
//   State<SnapMealScreen> createState() => _SnapMealScreenState();
// }
//
// class _SnapMealScreenState extends State<SnapMealScreen> {
//   final ApiService _api = ApiService();
//
//   File? snappedImage;
//   bool isAnalyzing = false;
//   bool isLogging = false;
//
//   List<Map<String, dynamic>> detectedFoods = [];
//
//   @override
//   void initState() {
//     super.initState();
//
//     // Auto open camera
//     Future.delayed(const Duration(milliseconds: 300), () {
//       openCamera();
//     });
//   }
//
//   // ---------------- CAMERA ----------------
//
//   Future<void> openCamera() async {
//     try {
//       final ImagePicker picker = ImagePicker();
//
//       final XFile? photo = await picker.pickImage(
//         source: ImageSource.camera,
//         preferredCameraDevice: CameraDevice.rear,
//         imageQuality: 70,
//       );
//
//       if (!mounted) return;
//
//       if (photo != null) {
//         setState(() {
//           snappedImage = File(photo.path);
//           detectedFoods.clear();
//         });
//
//         await _analyzeMeal(photo.path);
//       } else {
//         ScaffoldMessenger.of(
//           context,
//         ).showSnackBar(const SnackBar(content: Text('Camera cancelled')));
//       }
//     } on PlatformException catch (e) {
//       debugPrint('PlatformException: $e');
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Unable to open camera. Try on a real device.'),
//         ),
//       );
//     } catch (e) {
//       debugPrint('Camera error: $e');
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(SnackBar(content: Text('Error opening camera: $e')));
//     }
//   }
//
//   // ---------------- AI ANALYSIS ----------------
//   Future<void> _analyzeMeal(String imagePath) async {
//     setState(() => isAnalyzing = true);
//
//     try {
//       // Copy asset image to a temporary file so Multipart can upload it
//       final byteData = await rootBundle.load('assets/sample_meal.jpeg');
//       final tempDir = await getTemporaryDirectory();
//       debugPrint(tempDir.toString());
//       final file = File('${tempDir.path}/sample_meal.jpeg');
//
//       await file.writeAsBytes(byteData.buffer.asUint8List());
//
//       final multipartFile = await http.MultipartFile.fromPath(
//         "file", // backend field name
//         file.path,
//       );
//
//       final res = await _api.postMultipart(
//         "/api/ai/snap-meal",
//         fields: {},
//         files: [multipartFile],
//       );
//
//       debugPrint("Snap Meal Status: ${res.statusCode}");
//
//       final responseBody = await res.stream.bytesToString();
//       debugPrint("Snap Meal Response: $responseBody");
//
//       if (res.statusCode != 200) {
//         throw Exception("Backend error: $responseBody");
//       }
//
//       final decoded = jsonDecode(responseBody);
//
//       setState(() {
//         detectedFoods = List<Map<String, dynamic>>.from(decoded["foods"]);
//       });
//     } catch (e, st) {
//       debugPrint("Analyze error: $e\n$st");
//
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(SnackBar(content: Text("Meal analysis failed: $e")));
//     } finally {
//       if (mounted) setState(() => isAnalyzing = false);
//     }
//   }
//
//   // Future<void> _analyzeMeal(String imagePath) async {
//   //   setState(() => isAnalyzing = true);
//   //
//   //   try {
//   //     final file = await http.MultipartFile.fromPath(
//   //       "file", // MUST be exactly "file"
//   //       imagePath,
//   //     );
//   //
//   //     final res = await _api.postMultipart(
//   //       "/api/ai/snap-meal",
//   //       fields: {}, // no fields required
//   //       files: [file],
//   //     );
//   //
//   //     debugPrint("Snap Meal Status: ${res.statusCode}");
//   //
//   //     final responseBody = await res.stream.bytesToString();
//   //     debugPrint("Snap Meal Response: $responseBody");
//   //
//   //     if (res.statusCode != 200) {
//   //       throw Exception("Backend error: $responseBody");
//   //     }
//   //
//   //     final decoded = jsonDecode(responseBody);
//   //
//   //     final foods = decoded["foods"] as List;
//   //
//   //     setState(() {
//   //       detectedFoods = foods.cast<Map<String, dynamic>>();
//   //     });
//   //   } catch (e, st) {
//   //     debugPrint("Analyze error: $e\n$st");
//   //
//   //     ScaffoldMessenger.of(
//   //       context,
//   //     ).showSnackBar(SnackBar(content: Text("Meal analysis failed: $e")));
//   //   } finally {
//   //     if (mounted) setState(() => isAnalyzing = false);
//   //   }
//   // }
//
//   // ---------------- LOG MEAL ----------------
//
//   Future<void> _logMeal() async {
//     if (detectedFoods.isEmpty || isLogging) return;
//
//     setState(() => isLogging = true);
//
//     try {
//       final payload = _buildMealPayload();
//       final body = jsonEncode(payload);
//
//       debugPrint("Meal log payload: $body");
//
//       final res = await _api.post("/api/nutrition/log", body);
//
//       if (res.statusCode == 200 || res.statusCode == 201) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text("Meal logged successfully.")),
//         );
//
//         setState(() {
//           snappedImage = null;
//           detectedFoods.clear();
//         });
//       } else {
//         throw Exception("Failed to log meal (${res.statusCode})");
//       }
//     } catch (e, st) {
//       debugPrint("Log error: $e\n$st");
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(const SnackBar(content: Text("Failed to log meal.")));
//     } finally {
//       if (mounted) setState(() => isLogging = false);
//     }
//   }
//
//   Map<String, dynamic> _buildMealPayload() {
//     return {
//       "foods": detectedFoods.map((f) {
//         return {
//           "name": f["name"],
//           "quantity": f["quantity"],
//           "unit": f["unit"],
//           "calories": f["calories"],
//           "protein_g": f["protein_g"],
//           "carbs_g": f["carbs_g"],
//           "fats_g": f["fats_g"],
//           "food_api_id": f["food_api_id"],
//         };
//       }).toList(),
//     };
//   }
//
//   // ---------------- UI ----------------
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.grey.shade100,
//       appBar: AppBar(
//         title: const Text("Snap Meal"),
//         centerTitle: true,
//         elevation: 0,
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           children: [
//             SizedBox(
//               width: double.infinity,
//               height: 55,
//               child: ElevatedButton(
//                 onPressed: openCamera,
//                 child: const Text("Snap Meal"),
//               ),
//             ),
//             const SizedBox(height: 20),
//
//             if (isAnalyzing)
//               const Padding(
//                 padding: EdgeInsets.all(16),
//                 child: Column(
//                   children: [
//                     CircularProgressIndicator(),
//                     SizedBox(height: 12),
//                     Text("Analyzing meal..."),
//                   ],
//                 ),
//               ),
//
//             if (snappedImage != null)
//               Expanded(
//                 child: Column(
//                   children: [
//                     Expanded(
//                       // child: Image.file(snappedImage!, fit: BoxFit.cover),
//                       child: Image.asset(
//                         "assets/sample_meal.jpeg",
//                         fit: BoxFit.cover,
//                       ),
//                     ),
//                     const SizedBox(height: 16),
//
//                     if (detectedFoods.isNotEmpty) ...[
//                       const Text(
//                         "Detected Foods",
//                         style: TextStyle(
//                           fontSize: 18,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                       const SizedBox(height: 10),
//
//                       Expanded(
//                         child: ListView.builder(
//                           itemCount: detectedFoods.length,
//                           itemBuilder: (_, i) {
//                             final f = detectedFoods[i];
//                             return ListTile(
//                               title: Text(f["name"]),
//                               subtitle: Text(
//                                 "${f["quantity"]}${f["unit"]} • ${f["calories"]} kcal",
//                               ),
//                               trailing: Text(
//                                 "P ${f["protein_g"]}g  C ${f["carbs_g"]}g  F ${f["fats_g"]}g",
//                                 style: const TextStyle(fontSize: 12),
//                               ),
//                             );
//                           },
//                         ),
//                       ),
//
//                       const SizedBox(height: 10),
//
//                       SizedBox(
//                         width: double.infinity,
//                         height: 55,
//                         child: ElevatedButton(
//                           onPressed: isLogging ? null : _logMeal,
//                           child: isLogging
//                               ? const CircularProgressIndicator()
//                               : const Text("Log Meal"),
//                         ),
//                       ),
//                     ],
//                   ],
//                 ),
//               ),
//           ],
//         ),
//       ),
//     );
//   }
// }
