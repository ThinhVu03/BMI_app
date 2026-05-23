import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/firestore_service.dart';

// ==========================================
// 1. DỊCH VỤ AI - SỬ DỤNG OPENROUTER (MIỄN PHÍ, KHÔNG GIỚI HẠN VÙNG)
// ==========================================
class OpenRouterFoodService {
  // DÁN API KEY TỪ OPENROUTER CỦA BẠN VÀO ĐÂY (Bắt đầu bằng sk-or-v1-...)
  static const String _apiKey = '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';

  // Cơ sở dữ liệu calo món ăn Việt Nam nội bộ để tra cứu tức thì
  static const Map<String, Map<String, String>> _localCalorieDb = {
    "phở bò": {"calo": "550", "dinh_duong": "Cung cấp đạm từ thịt bò và carbohydrate từ bánh phở. Nên ăn thêm rau sống để bổ sung chất xơ."},
    "phở gà": {"calo": "480", "dinh_duong": "Cung cấp đạm ít béo từ thịt gà. Món ăn nhẹ nhàng, bổ dưỡng và dễ tiêu hóa."},
    "bún chả": {"calo": "590", "dinh_duong": "Thịt viên nướng chứa nhiều đạm và chất béo. Nước mắm chua ngọt chứa đường, hạn chế húp hết."},
    "bún bò huế": {"calo": "650", "dinh_duong": "Giàu đạm từ nạm bò, móng giò, mọc. Nước dùng nhiều dầu mỡ và muối, nên ăn vừa phải."},
    "bún riêu": {"calo": "480", "dinh_duong": "Cung cấp canxi từ gạch cua đồng, đạm từ đậu hũ và giò luộc. Vị thanh mát, tốt cho sức khỏe."},
    "cơm tấm": {"calo": "700", "dinh_duong": "Năng lượng rất cao từ sườn nướng, bì, chả trứng và cơm gạo tấm. Hạn chế mỡ hành nếu muốn giảm cân."},
    "cơm sườn": {"calo": "650", "dinh_duong": "Cung cấp lượng đạm cao và nhiều tinh bột. Ăn kèm cà chua và dưa leo để bổ sung vitamin."},
    "bánh mì": {"calo": "350", "dinh_duong": "Bao gồm tinh bột từ vỏ bánh, đạm và chất béo từ pate, chả, bơ. Khá tiện lợi nhưng ít chất xơ."},
    "bánh mì kẹp thịt": {"calo": "420", "dinh_duong": "Giàu năng lượng, đạm và chất béo. Nên ăn thêm dưa chua và rau thơm."},
    "bánh mì trứng": {"calo": "380", "dinh_duong": "Cung cấp chất béo và chất đạm chất lượng cao từ trứng ốp la hoặc trứng rán."},
    "xôi xéo": {"calo": "500", "dinh_duong": "Tinh bột từ gạo nếp và chất béo từ dầu hành cùng đạm đậu xanh. Cung cấp năng lượng rất lâu."},
    "xôi gấc": {"calo": "600", "dinh_duong": "Giàu tinh bột và vitamin A, beta-carotene từ màng đỏ quả gấc. Rất thích hợp cho bữa sáng."},
    "gỏi cuốn": {"calo": "120", "dinh_duong": "Món ăn cực kỳ lành mạnh (healthy). Rất giàu chất xơ, vitamin từ rau xanh và đạm tinh khiết từ tôm thịt."},
    "nem rán": {"calo": "150", "dinh_duong": "Nem chứa nhân thịt tôm giàu đạm, nhưng nhiều dầu mỡ béo do chiên ngập dầu. Nên ăn kèm rau sống."},
    "chả giò": {"calo": "150", "dinh_duong": "Chứa lượng chất béo cao từ dầu mỡ chiên. Thích hợp ăn kèm bún và nhiều rau sống."},
    "bánh xèo": {"calo": "350", "dinh_duong": "Vỏ bánh nhiều chất béo từ nước cốt dừa và bột nghệ, nhân tôm thịt. Nên ăn kèm thật nhiều rau xanh."},
    "bánh cuốn": {"calo": "350", "dinh_duong": "Món ăn sáng nhẹ bụng, tinh bột vừa phải. Có mộc nhĩ tốt cho tim mạch. Nên giảm bớt hành phi."},
    "hủ tiếu": {"calo": "500", "dinh_duong": "Giàu tinh bột và đạm heo. Nước lèo có hàm lượng muối và mỡ khá cao."},
    "bánh bao": {"calo": "350", "dinh_duong": "Tinh bột từ vỏ bột mì, nhân trứng cút và thịt heo băm cung cấp đạm và béo."},
    "trứng ốp la": {"calo": "160", "dinh_duong": "Chứa protein chất lượng cao và chất béo tốt. Lựa chọn tuyệt vời cho bữa sáng nhanh."},
    "trứng luộc": {"calo": "78", "dinh_duong": "Nguồn protein tinh khiết hàng đầu, chứa rất ít carbohydrate, phù hợp cho chế độ ăn kiêng."},
    "ức gà": {"calo": "165", "dinh_duong": "Nguồn đạm lý tưởng cho người tập thể thao vì hàm lượng protein cao và cực kỳ ít chất béo bão hòa."},
    "khoai lang": {"calo": "86", "dinh_duong": "Tinh bột hấp thu chậm, giàu chất xơ và vitamin A. Giúp kiểm soát đường huyết rất tốt."},
    "táo": {"calo": "52", "dinh_duong": "Giàu pectin (chất xơ hòa tan) giúp no lâu, chứa nhiều vitamin C và chất chống oxy hóa bảo vệ cơ thể."},
    "chuối": {"calo": "89", "dinh_duong": "Cung cấp kali, magie giúp chống chuột rút và vitamin B6. Thích hợp ăn trước khi tập luyện."},
    "bơ": {"calo": "160", "dinh_duong": "Giàu chất béo không bão hòa đơn có lợi cho tim mạch, vitamin E và lượng chất xơ dồi dào."},
    "cam": {"calo": "47", "dinh_duong": "Chứa rất nhiều vitamin C, chất xơ và nước, giúp tăng cường hệ miễn dịch và dưỡng da tốt."},
    "xoài": {"calo": "60", "dinh_duong": "Chứa vitamin C, A. Xoài chín chứa lượng đường ngọt tự nhiên khá cao, nên hạn chế ăn quá nhiều."},
    "xoài xanh": {"calo": "50", "dinh_duong": "Giàu vitamin C và chất xơ, vị chua thanh, chứa ít đường hơn xoài chín. Ăn vừa phải để tránh xót ruột."},
    "dưa hấu": {"calo": "30", "dinh_duong": "Chứa 92% là nước và lycopene tốt cho tim mạch. Giải nhiệt rất tốt và lượng calo cực thấp."},
    "sữa tươi": {"calo": "150", "dinh_duong": "Cung cấp canxi, vitamin D và protein xây dựng cơ bắp và hỗ trợ phát triển hệ xương vững chắc."},
    "sữa chua": {"calo": "100", "dinh_duong": "Chứa lợi khuẩn tốt cho hệ tiêu hóa, canxi hỗ trợ xương, protein dễ hấp thụ."},
    "bún đậu mắm tôm": {"calo": "700", "dinh_duong": "Đậm đà hương vị với bún, thịt heo luộc, đậu chiên và chả cốm. Có nhiều chất béo do chiên ngập dầu."},
    "salad": {"calo": "100", "dinh_duong": "Rất giàu chất xơ, vitamin và khoáng chất. Nên hạn chế các loại nước sốt kem béo như mayonnaise."},
    "cà phê sữa đá": {"calo": "180", "dinh_duong": "Caffeine giúp tỉnh táo đầu óc. Tuy nhiên chứa nhiều đường ngọt từ sữa đặc."},
    "trà sữa": {"calo": "450", "dinh_duong": "Calo rất cao từ sữa béo, trân châu tinh bột và đường ngọt. Hạn chế uống thường xuyên."},
    "bún cá": {"calo": "450", "dinh_duong": "Cá chiên giòn cung cấp đạm. Ăn kèm nhiều rau sống như hoa chuối, dọc mùng để bù chất xơ."},
    "bún mọc": {"calo": "400", "dinh_duong": "Đạm từ mọc viên heo, giò lụa. Món ăn sáng thanh đạm, ít dầu mỡ."},
    "mì tôm": {"calo": "350", "dinh_duong": "Tinh bột tinh chế và chất béo trans do chiên dầu mỡ, nghèo dinh dưỡng khác. Hạn chế sử dụng."},
    "thịt kho hột vịt": {"calo": "600", "dinh_duong": "Món ăn giàu đạm từ trứng và thịt heo kho. Lượng mỡ từ ba chỉ khá cao."},
    "rau muống xào tỏi": {"calo": "120", "dinh_duong": "Cung cấp sắt và chất xơ chất lượng từ rau muống. Chú ý lượng dầu ăn khi chế biến."},
    "canh chua": {"calo": "150", "dinh_duong": "Vitamin từ dứa, cà chua, giá đỗ và đạm từ tôm/cá. Món canh lành mạnh giải nhiệt tốt."},
    "cơm chiên": {"calo": "600", "dinh_duong": "Cơm chiên chứa nhiều tinh bột và chất béo do xào qua dầu mỡ. Nên bổ sung thêm dưa leo, cà chua để tăng chất xơ."},
    "cơm gà": {"calo": "650", "dinh_duong": "Cơm gà xối mỡ có lượng đạm cao nhưng cũng nhiều chất béo bão hòa từ mỡ gà. Hạn chế da gà nếu muốn giảm cân."},
    "hủ tiếu nam vang": {"calo": "550", "dinh_duong": "Nguồn protein dồi dào từ tôm, thịt băm, gan heo. Nước dùng chứa nhiều muối và dầu mỡ béo."},
    "cháo lòng": {"calo": "400", "dinh_duong": "Cung cấp sắt tốt từ huyết và các loại nội tạng heo. Tuy nhiên chứa lượng cholesterol khá cao."},
    "lẩu thái": {"calo": "800", "dinh_duong": "Giàu đạm từ hải sản, thịt bò, rau xanh. Nước lẩu có nhiều natri và gia vị cay nóng, tránh húp quá nhiều."},
    "gà rán": {"calo": "400", "dinh_duong": "Năng lượng và chất béo cao do chiên ngập dầu với lớp bột. Nên hạn chế ăn lớp da bột giòn."},
    "pizza": {"calo": "250", "dinh_duong": "Giàu tinh bột tinh chế, phô mai béo và các loại thịt chế biến sẵn. Ăn kèm nhiều rau củ xơ."},
    "hamburger": {"calo": "450", "dinh_duong": "Cung cấp đạm từ thịt bò băm béo, chất béo từ phô mai và tinh bột từ bánh mì. Lượng calo tương đối cao."},
    "khoai tây chiên": {"calo": "300", "dinh_duong": "Chứa nhiều tinh bột hấp thu nhanh và chất béo từ dầu chiên. Giá trị dinh dưỡng thấp, hạn chế ăn."},
    "trà xanh": {"calo": "0", "dinh_duong": "Thức uống giải nhiệt không calo, chứa chất chống oxy hóa EGCG rất tốt cho tim mạch và đốt mỡ."},
    "nước cam": {"calo": "120", "dinh_duong": "Chứa nhiều vitamin C tự nhiên giúp tăng đề kháng, tuy nhiên lượng đường quả khá cao và ít xơ hơn cam quả."},
    "nước ngọt": {"calo": "140", "dinh_duong": "Calo rỗng từ đường hóa học, không có vitamin hay xơ. Dễ làm tăng đường huyết nhanh chóng."},
    "coca": {"calo": "140", "dinh_duong": "Nước ngọt có ga chứa nhiều đường và calo rỗng, gây tích mỡ bụng nếu uống thường xuyên."},
    "pepsi": {"calo": "140", "dinh_duong": "Đồ uống có ga nhiều đường tinh luyện, không có chất dinh dưỡng bổ ích cho cơ thể."},
    "bia": {"calo": "150", "dinh_duong": "Chứa cồn dễ gây tích mỡ vùng bụng và tạo gánh nặng giải độc cho gan. Nên uống có chừng mực."},
    "sữa đậu nành": {"calo": "130", "dinh_duong": "Cung cấp nguồn đạm thực vật chất lượng cao, các isoflavone tốt cho nội tiết và hệ tim mạch."}
  };

  // Tra cứu nhanh trong cơ sở dữ liệu nội bộ
  static Map<String, String>? lookupLocalCalorie(String foodName) {
    String normalized = foodName.toLowerCase().trim();
    
    // Xử lý các từ đồng nghĩa/viết tắt thông dụng trước khi tra cứu
    if (normalized.contains("cơm rang")) normalized = "cơm chiên";
    if (normalized.contains("cơm chiên")) normalized = "cơm chiên";
    if (normalized.contains("cơm gà xối mỡ")) normalized = "cơm gà";
    if (normalized.contains("cơm sườn")) normalized = "cơm sườn";
    if (normalized.contains("cơm tấm")) normalized = "cơm tấm";
    if (normalized.contains("trứng chiên") || normalized.contains("trứng rán") || normalized.contains("trứng ốp")) {
      normalized = "trứng ốp la";
    }
    if (normalized.contains("trứng luộc")) normalized = "trứng luộc";
    if (normalized.contains("ức gà")) normalized = "ức gà";
    if (normalized.contains("khoai lang")) normalized = "khoai lang";
    if (normalized.contains("táo")) normalized = "táo";
    if (normalized.contains("chuối")) normalized = "chuối";
    if (normalized.contains("sữa chua")) normalized = "sữa chua";
    if (normalized.contains("sữa tươi")) normalized = "sữa tươi";
    if (normalized.contains("mì gói") || normalized.contains("mì ăn liền") || normalized.contains("hảo hảo")) {
      normalized = "mì tôm";
    }
    if (normalized.contains("coca") || normalized.contains("coke")) normalized = "coca";
    if (normalized.contains("pepsi")) normalized = "pepsi";
    if (normalized.contains("nước ngọt") || normalized.contains("nước ga")) normalized = "nước ngọt";
    if (normalized.contains("nem rán") || normalized.contains("chả giò")) normalized = "nem rán";
    if (normalized.contains("bánh mì kẹp") || normalized.contains("bánh mì thịt") || normalized.contains("bánh mì pate")) {
      normalized = "bánh mì kẹp thịt";
    }
    if (normalized.contains("thịt kho tàu") || normalized.contains("thịt kho hột vịt")) {
      normalized = "thịt kho hột vịt";
    }
    if (normalized.contains("rau muống")) normalized = "rau muống xào tỏi";

    // 1. Khớp chính xác sau chuẩn hóa
    if (_localCalorieDb.containsKey(normalized)) {
      return _localCalorieDb[normalized];
    }
    
    // 2. Khớp một phần (Chứa từ khóa hoặc là từ khóa con)
    for (var key in _localCalorieDb.keys) {
      if (normalized.contains(key) || key.contains(normalized)) {
        return _localCalorieDb[key];
      }
    }
    return null;
  }

  static Future<String> analyzeFoodImage(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      String base64Image = base64Encode(bytes).replaceAll('\n', '').replaceAll('\r', '');

      // Tự động nhận diện MIME type từ phần mở rộng file
      String mimeType = 'image/jpeg';
      final pathLower = imageFile.path.toLowerCase();
      if (pathLower.endsWith('.png')) {
        mimeType = 'image/png';
      } else if (pathLower.endsWith('.gif')) {
        mimeType = 'image/gif';
      } else if (pathLower.endsWith('.webp')) {
        mimeType = 'image/webp';
      }

      final url = Uri.parse('https://openrouter.ai/api/v1/chat/completions');

      final headers = {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json; charset=utf-8',
        'HTTP-Referer': 'https://foodscan.app', // Yêu cầu bắt buộc của OpenRouter
        'X-Title': 'Food Scanner',              // Yêu cầu bắt buộc của OpenRouter
      };

      final body = jsonEncode({
        // Sử dụng model Vision chất lượng cao, phản hồi nhanh và ổn định
        "model": "google/gemini-2.5-flash",
        "messages": [
          {
            "role": "user",
            "content": [
              {
                "type": "text",
                "text": "Bạn là chuyên gia dinh dưỡng Việt Nam. Hãy nhìn vào bức ảnh món ăn này và ước tính lượng dinh dưỡng của nó. Trả về kết quả dưới dạng JSON duy nhất, không thêm chữ nào khác ngoài JSON, theo cấu trúc sau: {\"ten_mon\": \"Tên món ăn bằng tiếng Việt\", \"calo\": \"Số calo ước tính (chỉ điền số, không ghi chữ kcal)\", \"dinh_duong\": \"Nhận xét ngắn gọn về giá trị dinh dưỡng của món này\"}"
              },
              {
                "type": "image_url",
                "image_url": {
                  "url": "data:$mimeType;base64,$base64Image"
                }
              }
            ]
          }
        ],
        "temperature": 0.1,
        "max_tokens": 1000
      });

      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        final responseData = jsonDecode(utf8.decode(response.bodyBytes));
        
        if (responseData == null) {
          return jsonEncode({"error": "Không nhận được phản hồi từ AI."});
        }
        
        if (responseData['error'] != null) {
          final err = responseData['error'];
          final code = err['code'];
          if (code == 429 || err['message']?.toString().contains('rate-limited') == true) {
            return jsonEncode({"error": "⚠️ Hệ thống AI miễn phí đang tạm thời quá tải hoặc giới hạn lượt gửi. Vui lòng đợi 5-10 giây rồi thử lại!"});
          }
          final errMessage = err['message'] ?? "Lỗi không xác định";
          return jsonEncode({"error": "Lỗi AI: $errMessage"});
        }
        
        final choices = responseData['choices'];
        if (choices == null || choices.isEmpty) {
          return jsonEncode({"error": "AI không trả về kết quả lựa chọn (choices trống)."});
        }
        
        final message = choices[0]['message'];
        if (message == null || message['content'] == null) {
          return jsonEncode({"error": "Nội dung trả về từ AI trống."});
        }
        
        String jsonResult = message['content'];
        return jsonResult;
      } else if (response.statusCode == 429) {
        return jsonEncode({
          "error": "⚠️ Server AI miễn phí đang bận hoặc quá tải. Vui lòng đợi 5-10 giây rồi nhấn thử lại!"
        });
      } else {
        return jsonEncode({
          "error": "Lỗi OpenRouter: Mã ${response.statusCode}\n${response.body}"
        });
      }
    } catch (e) {
      return jsonEncode({"error": "Lỗi kết nối mạng: $e"});
    }
  }

  // Tính toán lại lượng calo khi người dùng sửa tên món ăn
  static Future<String> recalculateFoodNutrition(String correctFoodName) async {
    // 1. Kiểm tra cơ sở dữ liệu cục bộ trước (Tra cứu tức thời)
    final local = lookupLocalCalorie(correctFoodName);
    if (local != null) {
      return jsonEncode({
        "ten_mon": correctFoodName,
        "calo": local["calo"],
        "dinh_duong": local["dinh_duong"]
      });
    }

    // 2. Nếu không tìm thấy trong database cục bộ, gọi AI nhanh qua openrouter/free
    try {
      final url = Uri.parse('https://openrouter.ai/api/v1/chat/completions');
      final headers = {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json; charset=utf-8',
        'HTTP-Referer': 'https://foodscan.app',
        'X-Title': 'Food Scanner',
      };

      final body = jsonEncode({
        "model": "google/gemini-2.5-flash", // Sử dụng model chất lượng cao và ổn định
        "messages": [
          {
            "role": "user",
            "content": "Bạn là chuyên gia dinh dưỡng Việt Nam. Người dùng cho biết món ăn thực tế là '$correctFoodName'. Hãy tính toán lượng calo và đưa ra nhận xét dinh dưỡng cho món ăn này. Trả về kết quả dưới dạng JSON duy nhất, không thêm chữ nào khác ngoài JSON, theo cấu trúc: {\"ten_mon\": \"$correctFoodName\", \"calo\": \"Số calo ước tính (chỉ ghi số)\", \"dinh_duong\": \"Nhận xét ngắn về dinh dưỡng\"}"
          }
        ],
        "temperature": 0.1,
        "max_tokens": 1000
      });

      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        final responseData = jsonDecode(utf8.decode(response.bodyBytes));
        
        if (responseData == null) {
          return jsonEncode({"error": "Không nhận được phản hồi từ AI."});
        }
        
        if (responseData['error'] != null) {
          final err = responseData['error'];
          final code = err['code'];
          if (code == 429 || err['message']?.toString().contains('rate-limited') == true) {
            return jsonEncode({"error": "⚠️ Hệ thống AI miễn phí đang tạm thời quá tải hoặc giới hạn lượt gửi. Vui lòng đợi 5-10 giây rồi thử lại!"});
          }
          final errMessage = err['message'] ?? "Lỗi không xác định";
          return jsonEncode({"error": "Lỗi AI: $errMessage"});
        }
        
        final choices = responseData['choices'];
        if (choices == null || choices.isEmpty) {
          return jsonEncode({"error": "AI không trả về kết quả (choices trống)."});
        }
        
        final message = choices[0]['message'];
        if (message == null || message['content'] == null) {
          return jsonEncode({"error": "Nội dung trả về từ AI trống."});
        }
        
        return message['content'];
      } else if (response.statusCode == 429) {
        return jsonEncode({
          "error": "⚠️ Server AI miễn phí đang bận hoặc quá tải. Vui lòng đợi 5-10 giây rồi nhấn thử lại!"
        });
      } else {
        return jsonEncode({
          "error": "Lỗi OpenRouter: Mã ${response.statusCode}\n${response.body}"
        });
      }
    } catch (e) {
      return jsonEncode({"error": "Lỗi kết nối: $e"});
    }
  }
}

// ==========================================
// 2. GIAO DIỆN UI
// ==========================================
class FoodScanScreen extends StatefulWidget {
  const FoodScanScreen({super.key});

  @override
  State<FoodScanScreen> createState() => _FoodScanScreenState();
}

class _FoodScanScreenState extends State<FoodScanScreen> {
  File? image;
  String result = "Hệ thống AI OpenRouter đã sẵn sàng!";
  bool loading = false;
  final picker = ImagePicker();

  // State variables for food details
  String? _foodName;
  String? _calories;
  String? _nutrition;
  bool _isEditing = false;
  final TextEditingController _editController = TextEditingController();

  Future<void> _pickImage(ImageSource source) async {
    final picked = await picker.pickImage(
      source: source,
      imageQuality: 25, // Nén ảnh mạnh để giảm dung lượng file xuống cực nhỏ giúp truyền mạng nhanh
      maxWidth: 320,    // Giảm chiều rộng xuống 320px (đủ để AI nhận diện thức ăn tốt và tối ưu tốc độ)
    );
    if (picked != null) {
      setState(() {
        image = File(picked.path);
        result = "Đang gửi ảnh lên Cloud AI phân tích...";
      });
      _scanFood();
    }
  }

  Future<void> _scanFood() async {
    if (image == null) return;

    setState(() {
      loading = true;
      _foodName = null;
      _calories = null;
      _nutrition = null;
      _isEditing = false;
    });

    try {
      String jsonResponse = await OpenRouterFoodService.analyzeFoodImage(image!);

      // Bóc tách JSON an toàn (Lấy nội dung từ dấu { đầu tiên đến } cuối cùng)
      String cleanJson = jsonResponse.trim();
      int startIndex = cleanJson.indexOf('{');
      int endIndex = cleanJson.lastIndexOf('}');
      if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
        cleanJson = cleanJson.substring(startIndex, endIndex + 1);
      }

      try {
        Map<String, dynamic> data = jsonDecode(cleanJson);

        if (data.containsKey('error')) {
          setState(() {
            result = "${data['error']}";
          });
        } else {
          setState(() {
            _foodName = data['ten_mon']?.toString();
            _calories = data['calo']?.toString();
            _nutrition = data['dinh_duong']?.toString();
            _editController.text = _foodName ?? "";
            result = ""; // Clear raw result to show structured UI
          });
        }
      } catch (decodeError) {
        setState(() {
          result = cleanJson;
        });
      }

    } catch (e) {
      setState(() => result = "Lỗi xử lý luồng hệ thống. Vui lòng thử lại!");
    } finally {
      setState(() => loading = false);
    }
  }

  // Gửi lại câu lệnh tính toán calo khi sửa tên
  Future<void> _recalculateNutrition() async {
    final text = _editController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      loading = true;
      _isEditing = false;
    });

    try {
      String jsonResponse = await OpenRouterFoodService.recalculateFoodNutrition(text);

      String cleanJson = jsonResponse.trim();
      int startIndex = cleanJson.indexOf('{');
      int endIndex = cleanJson.lastIndexOf('}');
      if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
        cleanJson = cleanJson.substring(startIndex, endIndex + 1);
      }

      try {
        Map<String, dynamic> data = jsonDecode(cleanJson);

        if (data.containsKey('error')) {
          setState(() {
            result = "${data['error']}";
            _foodName = null;
          });
        } else {
          setState(() {
            _foodName = data['ten_mon']?.toString() ?? text;
            _calories = data['calo']?.toString();
            _nutrition = data['dinh_duong']?.toString();
            result = "";
          });
        }
      } catch (decodeError) {
        setState(() {
          result = cleanJson;
          _foodName = null;
        });
      }

    } catch (e) {
      setState(() {
        result = "Lỗi xử lý hệ thống. Vui lòng thử lại!";
        _foodName = null;
      });
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> _addMealToDiary() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Vui lòng đăng nhập để thực hiện chức năng này!")),
      );
      return;
    }

    final double caloriesVal = double.tryParse(_calories ?? '0') ?? 0.0;
    if (caloriesVal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lượng calo không hợp lệ!")),
      );
      return;
    }

    // Xác định loại bữa ăn dựa trên giờ hiện tại
    final hour = DateTime.now().hour;
    String initialMealType = "Bữa phụ";
    if (hour >= 5 && hour < 10) {
      initialMealType = "Bữa sáng";
    } else if (hour >= 10 && hour < 15) {
      initialMealType = "Bữa trưa";
    } else if (hour >= 17 && hour < 22) {
      initialMealType = "Bữa tối";
    }

    String selectedType = initialMealType;
    final List<String> mealTypes = ["Bữa sáng", "Bữa trưa", "Bữa tối", "Bữa phụ"];

    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.bookmark_add_outlined, color: Colors.blue),
                  SizedBox(width: 10),
                  Text("Ghi nhận bữa ăn", style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Tên món: $_foodName", style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text("Calo: $_calories kcal", style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.deepOrange)),
                  const SizedBox(height: 16),
                  const Text("Chọn loại bữa ăn:", style: TextStyle(fontSize: 14, color: Colors.grey)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedType,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    items: mealTypes.map((type) {
                      return DropdownMenuItem<String>(
                        value: type,
                        child: Text(type),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setStateDialog(() {
                          selectedType = val;
                        });
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text("Hủy", style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text("Lưu"),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true) {
      setState(() {
        loading = true;
      });
      try {
        final firestoreService = FirestoreService(uid: uid);
        await firestoreService.addMeal(_foodName!, caloriesVal, selectedType);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 10),
                  Text("Đã thêm '$selectedType' vào nhật ký calo!"),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Lỗi lưu bữa ăn: $e"), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            loading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold( 
      appBar: AppBar(
        title: const Text("AI Phân Tích Dinh Dưỡng"),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              height: 280,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: image == null
                  ? const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.fastfood_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 8),
                  Text("Chưa có ảnh món ăn", style: TextStyle(color: Colors.grey)),
                ],
              )
                  : ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.file(image!, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text("Chụp ảnh"),
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text("Thư viện"),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            if (loading)
              const CircularProgressIndicator()
            else ...[
              if (_foodName != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.blue[100]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "🍲 Món ăn: ${_foodName!.toUpperCase()}",
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "🔥 Lượng calo: $_calories kcal",
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.deepOrange),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "📝 Thành phần dinh dưỡng: $_nutrition",
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87, height: 1.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF52BE80), Color(0xFF27AE60)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF52BE80).withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _addMealToDiary,
                    icon: const Icon(Icons.playlist_add_circle_rounded, color: Colors.white),
                    label: const Text(
                      "Thêm vào Nhật ký Ăn uống",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (!_isEditing)
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _isEditing = true;
                      });
                    },
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text("Tên món bị sai? Nhấn để sửa và tính lại"),
                    style: TextButton.styleFrom(foregroundColor: Colors.blue),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Column(
                      children: [
                        TextField(
                          controller: _editController,
                          decoration: InputDecoration(
                            labelText: "Tên món ăn đúng",
                            hintText: "Ví dụ: Xoài xanh, Bún chả...",
                            fillColor: Colors.white,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _isEditing = false;
                                  _editController.text = _foodName ?? "";
                                });
                              },
                              child: const Text("Hủy"),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: _recalculateNutrition,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF667eea),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Text("Tính lại"),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
              ] else if (result.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.blue[100]!),
                  ),
                  child: Text(
                    result,
                    textAlign: TextAlign.left,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.blueGrey,
                      height: 1.6,
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}