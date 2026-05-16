import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_markdown/flutter_markdown.dart';

class FoodScanScreen extends StatefulWidget {
  const FoodScanScreen({super.key});

  @override
  State<FoodScanScreen> createState() => _FoodScanScreenState();
}

class _FoodScanScreenState extends State<FoodScanScreen> {

  final String apiKey = "AIzaSyATZWbc4iHqWC2uPCkMbyZvwBrI-LgUc8I";

  File? image;
  String? result;
  bool loading = false;

  final picker = ImagePicker();

  Future pickImage(ImageSource source) async {
    final picked = await picker.pickImage(source: source);

    if (picked != null) {
      image = File(picked.path);
      setState(() {});
      scanFood();
    }
  }

  Future scanFood() async {

    if (image == null) return;

    setState(() {
      loading = true;
      result = null;
    });

    try {

      final bytes = await image!.readAsBytes();
      final base64Image = base64Encode(bytes);

      final url = Uri.parse(
          "https://generativelanguage.googleapis.com/v1/models/gemini-1.5-flash:generateContent?key=$apiKey");

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "contents": [
            {
              "parts": [
                {
                  "text":
                  "Đây là ảnh món ăn. Hãy cho biết tên món, calo, protein, fat, carbs. Trả lời tiếng Việt dạng markdown."
                },
                {
                  "inlineData": {
                    "mimeType": "image/jpeg",
                    "data": base64Image
                  }
                }
              ]
            }
          ]
        }),
      );

      final data = jsonDecode(response.body);

      setState(() {
        result = data["candidates"][0]["content"]["parts"][0]["text"];
      });

    } catch (e) {

      result = "Lỗi AI: $e";

    }

    setState(() {
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(title: const Text("AI Scan Calo")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [

            Container(
              height: 250,
              width: double.infinity,
              color: Colors.grey[200],
              child: image == null
                  ? const Icon(Icons.fastfood, size: 80)
                  : Image.file(image!, fit: BoxFit.cover),
            ),

            const SizedBox(height: 20),

            Row(
              children: [

                Expanded(
                  child: ElevatedButton(
                    onPressed: () => pickImage(ImageSource.camera),
                    child: const Text("Camera"),
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: ElevatedButton(
                    onPressed: () => pickImage(ImageSource.gallery),
                    child: const Text("Gallery"),
                  ),
                ),

              ],
            ),

            const SizedBox(height: 20),

            if (loading) const CircularProgressIndicator(),

            if (result != null)
              Expanded(
                child: Markdown(
                  data: result!,
                ),
              )

          ],
        ),
      ),
    );
  }
}
