import 'dio_client.dart';

class GalleryApiService {
  static Future<List<dynamic>> getAllAlbums() async {
    final r = await DioClient.get('/gallery');
    return r.data as List;
  }

  static Future<List<dynamic>> getPublished() async {
    final r = await DioClient.get('/gallery/published');
    return r.data as List;
  }

  static Future<Map<String, dynamic>> getAlbum(String id) async {
    final r = await DioClient.get('/gallery/$id');
    return r.data as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> create(
      Map<String, dynamic> data) async {
    final r = await DioClient.post('/gallery', data: data);
    return r.data as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> update(
      String id, Map<String, dynamic> data) async {
    final r = await DioClient.put('/gallery/$id', data: data);
    return r.data as Map<String, dynamic>;
  }

  static Future<void> delete(String id) async {
    await DioClient.delete('/gallery/$id');
  }

  static Future<void> addImages(
      String id, List<Map<String, dynamic>> images) async {
    await DioClient.post('/gallery/$id/images', data: images);
  }

  static Future<void> removeImage(String id, String imageId) async {
    await DioClient.delete('/gallery/$id/images/$imageId');
  }

  static Future<List<dynamic>> getByCategory(String category) async {
    final r = await DioClient.get('/gallery/category/$category');
    return r.data as List;
  }

  static Future<Map<String, dynamic>> getStats() async {
    final r = await DioClient.get('/gallery/stats');
    return r.data as Map<String, dynamic>;
  }
}
