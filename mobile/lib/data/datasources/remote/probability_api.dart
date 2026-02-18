import 'package:dio/dio.dart';

import '../../../core/constants/api_constants.dart';

/// Dio-based API client for poker probability calculation endpoints.
///
/// All methods throw [DioException] on network / server errors; callers are
/// expected to handle those at the provider layer.
class ProbabilityApi {
  final Dio _dio;

  ProbabilityApi(this._dio);

  /// Calculate win/tie/loss probabilities for the given hole cards against
  /// [numOpponents] opponents, with the current [communityCards] on the board.
  ///
  /// [holeCards] - List of 2-char card codes (e.g. ["Ah", "Kd"]).
  /// [communityCards] - List of 0-5 community card codes.
  /// [numOpponents] - Number of opponent players still in the hand.
  ///
  /// Returns the probability payload from the server, which includes:
  ///   - winProbability (double)
  ///   - tieProbability (double)
  ///   - lossProbability (double)
  ///   - handDistribution (Map<String, double>)
  Future<Map<String, dynamic>> calculateProbability({
    required List<String> holeCards,
    required List<String> communityCards,
    required int numOpponents,
  }) async {
    final response = await _dio.post(
      ApiConstants.probabilityCalculate,
      data: {
        'holeCards': holeCards,
        'communityCards': communityCards,
        'numOpponents': numOpponents,
      },
    );
    return response.data['data'] as Map<String, dynamic>;
  }
}
