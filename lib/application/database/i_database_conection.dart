import 'package:mysql1/mysql1.dart';

abstract class IDatabaseConection {
  Future<MySqlConnection> openConection();
}
