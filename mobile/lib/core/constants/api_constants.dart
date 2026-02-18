class ApiConstants {
  ApiConstants._();

  static const baseUrl = 'http://localhost:8080';
  static const wsUrl = 'ws://localhost:8080';

  // Auth
  static const authRegister = '/api/v1/auth/register';
  static const authLogin = '/api/v1/auth/login';
  static const authRefresh = '/api/v1/auth/refresh';
  static const authLogout = '/api/v1/auth/logout';

  // Users
  static const usersMe = '/api/v1/users/me';

  // Rooms
  static const rooms = '/api/v1/rooms';
  static String room(String id) => '/api/v1/rooms/$id';
  static String roomJoin(String id) => '/api/v1/rooms/$id/join';
  static String roomLeave(String id) => '/api/v1/rooms/$id/leave';
  static const roomJoinByCode = '/api/v1/rooms/join-by-code';

  // Hands
  static String handsStart(String roomId) => '/api/v1/rooms/$roomId/hands/start';
  static String hand(String handId) => '/api/v1/hands/$handId';
  static String handActions(String handId) => '/api/v1/hands/$handId/actions';
  static String roomHands(String roomId) => '/api/v1/rooms/$roomId/hands';

  // Wallet
  static const walletBalance = '/api/v1/wallet/balance';
  static const walletDailyReward = '/api/v1/wallet/daily-reward';
  static const walletTransactions = '/api/v1/wallet/transactions';

  // Chat
  static String chatMessages(String roomId) => '/api/v1/chat/$roomId/messages';

  // Probability
  static const probabilityCalculate = '/api/v1/probability/calculate';

  // Notifications
  static const notificationToken = '/api/v1/notifications/token';
  static String notificationTokenDelete(String token) =>
      '/api/v1/notifications/token/$token';
}
