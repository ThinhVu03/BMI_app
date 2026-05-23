class NutritionService {
  // Bảng tra cứu: Key phải khớp 100% với tên trong labels.txt
  static const Map<String, Map<String, dynamic>> foodData = {
    'pho_bo': {
      'name': 'Phở bò',
      'calories': 450,
      'protein': 25.0,
      'carbs': 50.0,
      'fat': 15.0,
    },
    'com_tam': {
      'name': 'Cơm tấm',
      'calories': 527,
      'protein': 20.5,
      'carbs': 65.0,
      'fat': 18.0,
    },
    // Nhựt bổ sung thêm các món khác vào đây nhé...
  };

  static Map<String, dynamic>? getNutrition(String label) {
    return foodData[label];
  }
}