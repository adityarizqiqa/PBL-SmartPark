/// Seluruh path dan kunci query yang dipakai aplikasi.
///
/// Nilai harus sama persis dengan `backend/app/api/routes/*.py`.
class Endpoints {
  const Endpoints._();

  // Auth
  static const String signIn = '/api/auth/sign-in';
  static const String signOut = '/api/auth/sign-out';
  static const String me = '/api/auth/me';

  // Areas
  static const String areas = '/api/areas';
  static String area(int id) => '/api/areas/$id';

  // Officers
  static const String officers = '/api/officers';
  static String officer(int id) => '/api/officers/$id';

  // Shifts
  static const String shifts = '/api/shifts';
  static const String currentShift = '/api/shifts/current';
  static const String openShift = '/api/shifts/open';
  static const String joinShift = '/api/shifts/join';
  static const String leaveShift = '/api/shifts/leave';
  static String closeShift(int id) => '/api/shifts/$id/close';
  static String assignment(int id) => '/api/shifts/assignments/$id';

  // Sessions
  static const String checkIn = '/api/sessions/check-in';
  static const String dashboard = '/api/sessions/dashboard';
  static const String activeSessions = '/api/sessions/active';
  static const String history = '/api/sessions/history';
  static const String historyMeta = '/api/sessions/history/meta';
  static const String lookup = '/api/sessions/lookup';
  static String session(int id) => '/api/sessions/$id';
  static String checkOut(int id) => '/api/sessions/$id/check-out';
  static String reject(int id) => '/api/sessions/$id/reject';
  static String voidSession(int id) => '/api/sessions/$id/void';
  static String sessionPhoto(int id, String side) =>
      '/api/sessions/$id/photo/$side';
}

/// Kunci query yang dipakai di lebih dari satu tempat.
class QueryKeys {
  const QueryKeys._();

  static const String plate = 'plate';
  static const String nim = 'nim';
  static const String status = 'status';
  static const String from = 'from';
  static const String to = 'to';
  static const String limit = 'limit';
  static const String offset = 'offset';
  static const String q = 'q';
  static const String includeInactive = 'include_inactive';
  static const String openOnly = 'open_only';
}
