import 'package:cuidapet_api/entities/schedule.dart';

abstract class IChatService {
  Future<int> startChat(int scheduleId);
}
