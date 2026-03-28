import '../models/bus_route.dart';

class StopTimeService {
  static Future<List<StopTime>> getStopTimes(BusRoute route, BusTrip trip) async {
    return estimateStopTimes(route, trip);
  }

  static List<StopTime> estimateStopTimes(BusRoute route, BusTrip trip) {
    if (route.stops.isEmpty) return [];
    final departureTime = _parseTime(trip.time);
    final stopCount = route.stops.length;
    final totalMinutes = _estimateTotalMinutes(route);
    final minPerStop = totalMinutes / (stopCount - 1);
    final stops = trip.type == "up" ? route.stops.reversed.toList() : route.stops;
    return List.generate(stopCount, (i) {
      final mins = (i * minPerStop).round();
      final arrival = departureTime.add(Duration(minutes: mins));
      return StopTime(stopName: stops[i], estimatedTime: _formatTime(arrival));
    });
  }

  static int _estimateTotalMinutes(BusRoute route) {
    const known = {
      'khonika': 120, 'hemonto': 90, 'wari_bateshwar': 150,
      'bikrampur': 120, 'maitree': 90, 'ishakha': 90,
      'idrakpur': 75, 'ananda': 75, 'falguni': 60,
      'choitaly': 60, 'boishakhi': 50, 'taranga': 45,
      'basanta': 45, 'srabon': 40, 'ullash': 40, 'kinchit': 50,
    };
    return known[route.id] ?? 60;
  }

  static DateTime _parseTime(String time) {
    final parts = time.split(' ');
    final hm = parts[0].split(':');
    int hour = int.parse(hm[0]);
    final min = int.parse(hm[1]);
    final isPm = parts[1] == 'PM';
    if (isPm && hour != 12) hour += 12;
    if (!isPm && hour == 12) hour = 0;
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, hour, min);
  }

  static String _formatTime(DateTime dt) {
    final hour = dt.hour;
    final min = dt.minute;
    final isPm = hour >= 12;
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '${displayHour.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')} ${isPm ? 'PM' : 'AM'}';
  }
}
