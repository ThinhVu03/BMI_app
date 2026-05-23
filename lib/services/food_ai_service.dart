import 'dart:io';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img; // Dùng để resize ảnh về 224x224
import 'dart:typed_data';

class FoodAiService {
  Interpreter? _interpreter;
  List<String>? _labels;

  // 1. Nạp mô hình vào RAM
  Future<void> loadModel() async {
    _interpreter = await Interpreter.fromAsset('ai/food_model_final.tflite');
    final labelData = await File('assets/ai/labels.txt').readAsLines();
    _labels = labelData;
  }

  // 2. Dự đoán món ăn từ File ảnh
  Future<String> predict(File imageFile) async {
    if (_interpreter == null) await loadModel();

    // 1. Tiền xử lý ảnh (Cần thêm logic xử lý ảnh thành mảng bytes ở đây)
    var imageBytes = imageFile.readAsBytesSync();
    var decodedImage = img.decodeImage(imageBytes);
    var resizedImage = img.copyResize(decodedImage!, width: 224, height: 224);

    // Chuyển ảnh thành mảng Float32 (input)
    var input = _imageToByteListFloat32(resizedImage); // Định nghĩa hàm này bên dưới

    // 2. Chạy Inference
    var output = List.filled(111, 0.0).reshape([1, 111]);
    _interpreter!.run(input, output);

    // 3. Tìm TopIndex (Vị trí có xác suất cao nhất)
    List<double> probabilities = List<double>.from(output[0]);
    double maxProb = -1.0;
    int topIndex = 0;

    for (int i = 0; i < probabilities.length; i++) {
      if (probabilities[i] > maxProb) {
        maxProb = probabilities[i];
        topIndex = i;
      }
    }

    // 4. Trả về tên món (Dùng dấu ! để khẳng định _labels không null)
    return _labels![topIndex];
  }

// Hàm bổ trợ để chuyển ảnh sang mảng bytes cho AI
  Uint8List _imageToByteListFloat32(img.Image image) {
    var convertedBytes = Float32List(1 * 224 * 224 * 3);
    var buffer = Float32List.view(convertedBytes.buffer);
    int pixelIndex = 0;
    for (int i = 0; i < 224; i++) {
      for (int j = 0; j < 224; j++) {
        var pixel = image.getPixel(j, i);
        buffer[pixelIndex++] = (pixel.r / 127.5) - 1.0;
        buffer[pixelIndex++] = (pixel.g / 127.5) - 1.0;
        buffer[pixelIndex++] = (pixel.b / 127.5) - 1.0;
      }
    }
    return convertedBytes.buffer.asUint8List();
  }
}