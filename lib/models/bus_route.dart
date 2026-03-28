class BusTrip {
  final String time;
  final String busNo;
  final String type;
  final String? busType;
  const BusTrip({required this.time, required this.busNo, required this.type, this.busType});
}

class StopTime {
  final String stopName;
  final String estimatedTime;
  final String? firebaseTime;
  String get displayTime => firebaseTime ?? estimatedTime;
  const StopTime({required this.stopName, required this.estimatedTime, this.firebaseTime});
}

class BusRoute {
  final String id;
  final String nameEn;
  final String nameBn;
  final List<String> stops;
  final List<BusTrip> schedule;
  final String fbGroup;
  const BusRoute({required this.id, required this.nameEn, required this.nameBn, required this.stops, required this.schedule, required this.fbGroup});
}
