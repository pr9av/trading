class AnalyticsBehavior {
  final int totalDataPoints;
  final int symbolsTracked;
  final int activeUsers;
  final String status;
  final int uptime;

  AnalyticsBehavior({
    required this.totalDataPoints,
    required this.symbolsTracked,
    required this.activeUsers,
    required this.status,
    required this.uptime,
  });

  factory AnalyticsBehavior.fromJson(Map<String, dynamic> json) {
    return AnalyticsBehavior(
      totalDataPoints: int.parse(json['total_data_points'].toString()),
      symbolsTracked: int.parse(json['symbols_tracked'].toString()),
      activeUsers: int.parse(json['active_users'].toString()),
      status: json['status'] ?? 'OFFLINE',
      uptime: int.parse(json['uptime'].toString()),
    );
  }
}
