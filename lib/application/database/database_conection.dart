import 'package:cuidapet_api/application/config/database_conection_configuration.dart';
import 'package:injectable/injectable.dart';
import 'package:mysql1/mysql1.dart';

import './i_database_conection.dart';

@LazySingleton(as: IDatabaseConection)
class DatabaseConection implements IDatabaseConection {
  final DatabaseConnectionConfiguration _configuration;

  DatabaseConection(this._configuration);

  @override
  Future<MySqlConnection> openConection() {
    return MySqlConnection.connect(ConnectionSettings(
      host: _configuration.host,
      port: _configuration.port,
      user: _configuration.user,
      password: _configuration.password,
      db: _configuration.databaseName,
    ));
  }
}
