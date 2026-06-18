import 'package:get/get.dart';
import 'package:dio/dio.dart';
import '../models/turf_model.dart';

class FavoritesViewModel extends GetxController {
  final favorites = <TurfModel>[].obs;
  final isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    fetchFavorites();
  }

  Future<void> fetchFavorites() async {
    isLoading.value = true;
    try {
      final dio = Get.find<Dio>();
      final response = await dio.get('/user/favorites/');
      if (response.data['result'] == 'success') {
        final List<dynamic> data = response.data['data'];
        favorites.value = data.map((json) => TurfModel.fromJson(json)).toList();
      }
    } catch (e) {
      print('Error fetching favorites: $e');
    } finally {
      isLoading.value = false;
    }
  }
}