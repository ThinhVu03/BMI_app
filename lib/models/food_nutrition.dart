class FoodNutrition {
  final String name;
  final double calories; // kcal trên 100g hoặc 1 tô/đĩa
  final double protein;
  final double carbs;
  final double fat;

  FoodNutrition({
    required this.name,
    required this.calories,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
  });

  // Có thể dùng để nạp từ Firestore sau này
  factory FoodNutrition.fromMap(Map<String, dynamic> map) {
    return FoodNutrition(
      name: map['name'] ?? '',
      calories: (map['calories'] ?? 0).toDouble(),
      protein: (map['protein'] ?? 0).toDouble(),
    );
  }
}