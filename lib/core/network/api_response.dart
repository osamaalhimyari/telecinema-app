/// Generic API response wrapper. The backend answers every `/api` call with a
/// `{ success, message?, data? }` envelope (see `RoomsApiController`).
class ApiResponse {
  final bool success;
  final String? message;
  final dynamic data;
  final int? statusCode;

  const ApiResponse({
    required this.success,
    this.message,
    this.data,
    this.statusCode,
  });

  factory ApiResponse.fromJson(Map<String, dynamic> json) => ApiResponse(
    success: json['success'] as bool? ?? false,
    message: json['message'] as String?,
    data: json['data'],
    statusCode: json['statusCode'] as int?,
  );
}
