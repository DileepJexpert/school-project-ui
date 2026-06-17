import 'dio_client.dart';

class AssetApiService {
  static const _base = '/assets';

  // Assets
  static Future<List<Map<String, dynamic>>> getAllAssets() async {
    final response = await DioClient.get(_base);
    return (response.data as List).cast<Map<String, dynamic>>();
  }

  static Future<Map<String, dynamic>> addAsset(
      Map<String, dynamic> data) async {
    final response = await DioClient.post(_base, data: data);
    return response.data as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> updateAsset(
      String id, Map<String, dynamic> data) async {
    final response = await DioClient.put('$_base/$id', data: data);
    return response.data as Map<String, dynamic>;
  }

  static Future<void> deleteAsset(String id) async {
    await DioClient.delete('$_base/$id');
  }

  static Future<Map<String, dynamic>> getAssetStats() async {
    final response = await DioClient.get('$_base/stats');
    return response.data as Map<String, dynamic>;
  }

  static Future<List<Map<String, dynamic>>> getAssetsByCategory(
      String category) async {
    final response = await DioClient.get('$_base/category/$category');
    return (response.data as List).cast<Map<String, dynamic>>();
  }

  // Maintenance
  static Future<Map<String, dynamic>> addMaintenance(
      Map<String, dynamic> data) async {
    final response = await DioClient.post('$_base/maintenance', data: data);
    return response.data as Map<String, dynamic>;
  }

  static Future<void> completeMaintenance(String id) async {
    await DioClient.put('$_base/maintenance/$id/complete');
  }

  static Future<List<Map<String, dynamic>>> getMaintenanceHistory(
      String assetId) async {
    final response = await DioClient.get('$_base/maintenance/asset/$assetId');
    return (response.data as List).cast<Map<String, dynamic>>();
  }

  static Future<List<Map<String, dynamic>>> getUpcomingMaintenance() async {
    final response = await DioClient.get('$_base/maintenance/upcoming');
    return (response.data as List).cast<Map<String, dynamic>>();
  }
}
