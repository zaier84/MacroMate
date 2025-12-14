import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class SnapMealScreen extends StatefulWidget {
  const SnapMealScreen({super.key});

  @override
  State<SnapMealScreen> createState() => _SnapMealScreenState();
}

class _SnapMealScreenState extends State<SnapMealScreen> {
  File? snappedImage;

  // Future<void> openCamera() async {
  //   final ImagePicker picker = ImagePicker();
  //
  //   final XFile? photo = await picker.pickImage(
  //     source: ImageSource.camera,
  //     preferredCameraDevice: CameraDevice.rear,
  //     imageQuality: 70,
  //   );
  //
  //   if (photo != null) {
  //     setState(() {
  //       snappedImage = File(photo.path);
  //     });
  //   }
  // }

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
        });
      } else {
        // user canceled
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Camera cancelled')));
      }
    } on PlatformException catch (e) {
      debugPrint('PlatformException while opening camera: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to open camera (platform error). Try on a real device.',
          ),
        ),
      );
    } catch (e, st) {
      debugPrint('Unexpected error opening camera: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unexpected error when opening camera: ${e.toString()}',
          ),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();

    // Automatically open camera as soon as screen opens
    Future.delayed(const Duration(milliseconds: 300), () {
      openCamera();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          "Snap Meal",
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          children: [
            // SNAP BUTTON
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: openCamera,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  "Snap Meal",
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 30),

            // Display image if snapped
            if (snappedImage != null)
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.file(snappedImage!, fit: BoxFit.cover),
                  ),
                ),
              )
            else
              Expanded(
                child: Center(
                  child: Text(
                    "No meal snapped yet.\nTap the button above.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
