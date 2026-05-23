import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiFoodService {
  static const String _apiKey = 'AIzaSyDAuTLFTrQYEGycBBk198WVU6heL-3SQ3s';

  static Future<String> analyzeFoodImage(File imageFile) async {
    try {
      // 1. Khởi tạo model Gemini Vision (Dùng bản 1.5 Flash cực nhanh và nhẹ)
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: _apiKey,
      );

      // 2. Chuyển đổi file ảnh từ điện thoại sang dạng bytes cho API
      final imageBytes = await imageFile.readAsBytes();
      final prompt = DataPart('image/jpeg', imageBytes);

      // 3. Viết yêu cầu rõ ràng bằng tiếng Việt (Ép AI trả về JSON sạch)
      final textPrompt = TextPart(
          'Bạn là một chuyên gia dinh dưỡng Việt Nam. Hãy nhìn vào bức ảnh món ăn này và trả về kết quả dưới dạng JSON duy nhất, không thêm chữ nào khác ngoài JSON, theo cấu trúc sau: '
              '{"ten_mon": "Tên món ăn bằng tiếng Việt", "calo": "Số calorie ước tính (chỉ ghi số)", "dinh_duong": "Nhận xét ngắn về dinh dưỡng"}'
      );

      // 4. Gửi lên Cloud của Google và nhận phản hồi
      final response = await model.generateContent([
        Content.multi([textPrompt, prompt])
      ]);

      // Trả về chuỗi JSON kết quả
      return response.text ?? '{"error": "Không thể phân tích ảnh"}';
    } catch (e) {
      return '{"error": "Lỗi kết nối API: $e"}';
    }
  }
}