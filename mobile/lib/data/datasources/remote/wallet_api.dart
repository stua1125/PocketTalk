import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';

class WalletApi {
  final Dio _dio;

  WalletApi(this._dio);

  Future<Map<String, dynamic>> getBalance() async {
    final response = await _dio.get(ApiConstants.walletBalance);
    return response.data['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> claimDailyReward() async {
    final response = await _dio.post(ApiConstants.walletDailyReward);
    return response.data['data'] as Map<String, dynamic>;
  }

  Future<List<dynamic>> getTransactions({int page = 0, int size = 20}) async {
    final response = await _dio.get(
      ApiConstants.walletTransactions,
      queryParameters: {'page': page, 'size': size},
    );
    return response.data['data'] as List<dynamic>;
  }
}
