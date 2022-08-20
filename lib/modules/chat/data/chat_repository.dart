import 'package:cuidapet_api/application/exceptions/database_exception.dart';
import 'package:cuidapet_api/application/logger/i_logger.dart';
import 'package:cuidapet_api/entities/chat.dart';
import 'package:cuidapet_api/entities/device_token.dart';
import 'package:cuidapet_api/entities/supplier.dart';
import 'package:injectable/injectable.dart';

import 'package:cuidapet_api/application/database/i_database_conection.dart';
import 'package:mysql1/mysql1.dart';

import './i_chat_repository.dart';

@LazySingleton(as: IChatRepository)
class ChatRepository implements IChatRepository {
  final IDatabaseConection conection;
  final ILogger log;
  ChatRepository({
    required this.conection,
    required this.log,
  });
  @override
  Future<int> startChat(int scheduleId) async {
    MySqlConnection? conn;

    try {
      conn = await conection.openConection();
      final result = await conn.query('''
      insert into chats(agendamento_id, status, data_criacao)
      values (?, ?, ?)
      ''', [
        scheduleId,
        'A',
        DateTime.now().toIso8601String(),
      ]);
      return result.insertId!;
    } on MySqlException catch (e, s) {
      log.error('Erro ao iniciar chat', e, s);
      throw DatabaseException();
    } finally {
      await conn?.close();
    }
  }

  @override
  Future<Chat?> findChatById(int chatId) async {
    MySqlConnection? conn;

    try {
      conn = await conection.openConection();
      final query = '''
      select 
        c.id,
        c.data_criacao,
        c.status,
        a.nome as agendamento_nome,
        a.nome_pet as agendamento_nome_pet,
        a.fornecedor_id,
        f.nome as fornec_nome,
        f.logo,
        a.usuario_id,
        u.android_token as user_android_token,
        u.ios_token as user_ios_token,
        uf.android_token as fornec_android_token,
        uf.ios_token as fornec_ios_token
      from chats as c 
      inner join agendamento a on a.id = c.agendamento_id
      inner join fornecedor f on f.id = a.fornecedor_id
      inner join usuario u on u.id = a.usuario_id
      inner join usuario uf on uf.fornecedor_id = f.id
      where c.id=?
      ''';

      final result = await conn.query(query, [chatId]);
      if (result.isNotEmpty) {
        final resultMysql = result.first;
        return Chat(
          id: resultMysql['id'],
          status: resultMysql['status'],
          name: resultMysql['agendamento_nome'],
          petName: resultMysql['agendamento_nome_pet'],
          supplier: Supplier(
              id: resultMysql['fornecedor_id'],
              name: resultMysql['fornec_nome']),
          user: resultMysql['usuario_id'],
          userDeviceToken: DeviceToken(
            android: (resultMysql['user_android_token'] as Blob?)?.toString(),
            ios: (resultMysql['user_ios_token'] as Blob?)?.toString(),
          ),
          supplierDeviceToken: DeviceToken(
            android: (resultMysql['fornec_android_token'] as Blob?)?.toString(),
            ios: (resultMysql['fornec_ios_token'] as Blob?)?.toString(),
          ),
        );
      }
    } on MySqlException catch (e, s) {
      log.error('Erro ao buscar dados do chat', e, s);
      throw DatabaseException();
    } finally {
      await conn?.close();
    }
  }
}
