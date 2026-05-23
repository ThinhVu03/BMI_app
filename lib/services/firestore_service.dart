import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/bmi_record.dart';

class FirestoreService {
  final String uid;
  FirestoreService({required this.uid});

  // Reference tới user document
  DocumentReference get _userDocRef {
    return FirebaseFirestore.instance.collection('users').doc(uid);
  }

  // Reference tới collection 'records' (QUAN TRỌNG: Tên này phải thống nhất)
  CollectionReference get _recordsRef {
    return _userDocRef.collection('records');
  }

  // ============ PHẦN USER PROFILE ============

  /// 1. Lưu/Cập nhật thông tin Hồ sơ người dùng
  Future<void> updateUserProfile({
    required String displayName,
    required int age,
    required String gender,
    required double height,
    required double weight,
    String? photoUrl,
  }) async {
    try {
      final data = {
        'displayName': displayName,
        'age': age,
        'gender': gender,
        'height': height,
        'weight': weight,
        'lastUpdate': FieldValue.serverTimestamp(),
      };

      if (photoUrl != null) {
        data['photoUrl'] = photoUrl;
      }

      await _userDocRef.set(data, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw _handleFirestoreException(e);
    } catch (e) {
      throw Exception('Lỗi lưu profile: $e');
    }
  }

  /// 2. Lấy thông tin Hồ sơ người dùng
  Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      DocumentSnapshot doc = await _userDocRef.get();
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }
      return null;
    } on FirebaseException catch (e) {
      throw _handleFirestoreException(e);
    } catch (e) {
      throw Exception('Lỗi lấy profile: $e');
    }
  }

  /// 2b. Lấy stream thông tin Hồ sơ người dùng
  Stream<Map<String, dynamic>?> getUserProfileStream() {
    return _userDocRef.snapshots().map((snapshot) {
      if (snapshot.exists) {
        return snapshot.data() as Map<String, dynamic>;
      }
      return null;
    });
  }

  // ============ PHẦN BMI RECORDS ============

  /// Thêm lượt đo mới
  Future<void> addRecord(BmiRecord record) async {
    try {
      await _recordsRef.add(record.toMap());
      await _updateUserStats(record);
    } on FirebaseException catch (e) {
      throw _handleFirestoreException(e);
    } catch (e) {
      throw Exception('Không thể lưu dữ liệu: $e');
    }
  }

  /// Lấy danh sách records (Stream)
  Stream<List<BmiRecord>> getRecordsStream({int? limit}) {
    Query query = _recordsRef.orderBy('date', descending: true);
    if (limit != null) query = query.limit(limit);

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => BmiRecord.fromSnapshot(doc)).toList();
    });
  }

  /// Xóa 1 record
  Future<void> deleteRecord(String recordId) async {
    try {
      await _recordsRef.doc(recordId).delete();
    } on FirebaseException catch (e) {
      throw _handleFirestoreException(e);
    }
  }

  /// [ĐÃ SỬA LỖI] Xóa toàn bộ records
  Future<void> deleteAllRecords() async {
    try {
      // 1. Dùng _recordsRef để đảm bảo đúng đường dẫn collection 'records'
      final snapshot = await _recordsRef.get();

      // 2. Kiểm tra nếu không có gì thì dừng
      if (snapshot.docs.isEmpty) return;

      // 3. Dùng FirebaseFirestore.instance để tạo batch
      final batch = FirebaseFirestore.instance.batch();

      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      // 4. Thực thi xóa
      await batch.commit();

      // (Tùy chọn) Reset các chỉ số thống kê trong profile về 0 hoặc null
      await _userDocRef.update({
        'latestBMI': FieldValue.delete(),
        'totalRecords': 0,
      });

    } catch (e) {
      print("Lỗi xóa dữ liệu: $e");
      throw Exception('Lỗi khi xóa toàn bộ dữ liệu: $e');
    }
  }

  // ============ PHẦN QUẢN LÝ CALO & BỮA ĂN ============

  // Reference tới collection 'meals'
  CollectionReference get _mealsRef {
    return _userDocRef.collection('meals');
  }

  /// 1. Thêm một bữa ăn mới
  Future<void> addMeal(String name, double calories, String mealType) async {
    try {
      await _mealsRef.add({
        'name': name,
        'calories': calories,
        'mealType': mealType,
        'dateTime': Timestamp.now(),
      });
    } on FirebaseException catch (e) {
      throw _handleFirestoreException(e);
    } catch (e) {
      throw Exception('Lỗi thêm bữa ăn: $e');
    }
  }

  /// 2. Lấy stream danh sách bữa ăn trong ngày
  Stream<List<Map<String, dynamic>>> getDailyMealsStream(DateTime date) {
    DateTime start = DateTime(date.year, date.month, date.day);
    DateTime end = DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
    
    return _mealsRef
        .where('dateTime', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('dateTime', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id; // Lưu id tài liệu để phục vụ việc xóa
        return data;
      }).toList();
    });
  }

  /// 3. Xóa một bữa ăn
  Future<void> deleteMeal(String mealId) async {
    try {
      await _mealsRef.doc(mealId).delete();
    } on FirebaseException catch (e) {
      throw _handleFirestoreException(e);
    } catch (e) {
      throw Exception('Lỗi xóa bữa ăn: $e');
    }
  }

  /// 4. Cập nhật cấu hình mục tiêu calo
  Future<void> updateCalorieGoal(double goal, String activityLevel, String weightGoal) async {
    try {
      await _userDocRef.set({
        'calorieGoal': goal,
        'activityLevel': activityLevel,
        'weightGoal': weightGoal,
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw _handleFirestoreException(e);
    } catch (e) {
      throw Exception('Lỗi cập nhật mục tiêu calo: $e');
    }
  }

  // ============ PRIVATE HELPERS ============

  Future<void> _updateUserStats(BmiRecord record) async {
    try {
      await _userDocRef.set({
        'latestBMI': record.bmi,
        'latestWeight': record.weight,
        'latestHeight': record.height,
        'totalRecords': FieldValue.increment(1),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Warning: Không thể cập nhật stats: $e');
    }
  }

  Exception _handleFirestoreException(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied': return Exception('Không có quyền truy cập');
      case 'unavailable': return Exception('Mất kết nối server');
      case 'not-found': return Exception('Không tìm thấy dữ liệu');
      default: return Exception('Lỗi: ${e.message ?? e.code}');
    }
  }
}