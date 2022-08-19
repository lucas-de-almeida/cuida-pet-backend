import 'package:cuidapet_api/application/database/i_database_conection.dart';
import 'package:cuidapet_api/application/exceptions/database_exception.dart';
import 'package:cuidapet_api/application/exceptions/user_exists_exception.dart';
import 'package:cuidapet_api/application/exceptions/user_not_found_exception.dart';
import 'package:cuidapet_api/application/helpers/cripty_helper.dart';
import 'package:cuidapet_api/application/logger/i_logger.dart';
import 'package:cuidapet_api/entities/user.dart';
import 'package:cuidapet_api/modules/user/view_models/platform.dart';
import 'package:injectable/injectable.dart';
import 'package:mysql1/mysql1.dart';

import './i_user_repository.dart';

@LazySingleton(as: IUserRepository)
class UserRepository implements IUserRepository {
  final IDatabaseConection connection;
  final ILogger log;

  UserRepository({required this.connection, required this.log});

  @override
  Future<User> createUser(User user) async {
    MySqlConnection? conn;

    try {
      conn = await connection.openConection();
      final query = '''
          insert usuario(email, tipo_cadastro, img_avatar, senha, fornecedor_id, social_id)
          values(?,?,?,?,?,?)
      ''';
      final result = await conn.query(query, [
        user.email,
        user.registerType,
        user.imageAvatar,
        CriptyHelper.generateSha256Hash(user.password ?? ''),
        user.supplierId,
        user.socialKey,
      ]);
      final userId = result.insertId;

      return user.copyWith(id: userId, password: null);
    } on MySqlException catch (e, s) {
      if (e.message.contains('usuario.email_UNIQUE')) {
        log.error('Usuario ja cadastradona base de dados', e, s);
        throw UserExistsException();
      }
      log.error('Erro ao criar usuario', e, s);
      throw DatabaseException(message: 'Erro ao criar usuario', exception: e);
    } finally {
      await conn?.close();
    }
  }

  @override
  Future<User> loginWithEmailPassword(
      String email, String password, bool isSupplierId) async {
    MySqlConnection? conn;

    try {
      conn = await connection.openConection();
      var query = '''
      select *
      from usuario 
      where
         email = ? and
         senha = ?
      ''';

      if (isSupplierId) {
        query += ' and fornecedor_id is not null';
      } else {
        query += ' and fornecedor_id is null';
      }

      final result = await conn.query(query, [
        email,
        CriptyHelper.generateSha256Hash(password),
      ]);

      if (result.isEmpty) {
        log.error(
          'Usuario ou senha invalido',
          throw UserNotFoundException(message: 'Usuario ou senha invalidos'),
        );
      } else {
        final userSqlData = result.first;
        return User(
          id: userSqlData['id'],
          email: userSqlData['email'],
          registerType: userSqlData['tipo_cadastro'],
          iosToken: (userSqlData['ios_token'] as Blob?)?.toString(),
          androidToken: (userSqlData['android_token'] as Blob?)?.toString(),
          imageAvatar: (userSqlData['img_avatar'] as Blob?)?.toString(),
          supplierId: userSqlData['fornecedor_id'],
        );
      }
    } on MySqlException catch (e, s) {
      log.error('Erro ao realizar login', e, s);
      throw DatabaseException(message: e.message);
    } finally {
      await conn?.close();
    }
  }

  @override
  Future<User> loginWithSocialKey(
      String email, String socialKey, String socialType) async {
    MySqlConnection? conn;

    try {
      conn = await connection.openConection();

      final result = await conn.query('''
      select *
      from usuario 
      where
         email = ?         
      ''', [
        email,
      ]);

      if (result.isEmpty) {
        throw UserNotFoundException(message: 'usuario nao encontrado');
      } else {
        final userSqlData = result.first;
        if (userSqlData['social_id'] == null ||
            userSqlData['social_id'] != socialKey) {
          await conn.query('''
          update usuario 
          set social_id = ?,tipo_cadastro = ?
          where id = ?
          ''', [
            socialKey,
            socialType,
            userSqlData['id'],
          ]);
        }
        return User(
          id: userSqlData['id'],
          email: userSqlData['email'],
          registerType: userSqlData['tipo_cadastro'],
          iosToken: (userSqlData['ios_token'] as Blob?)?.toString(),
          androidToken: (userSqlData['android_token'] as Blob?)?.toString(),
          imageAvatar: (userSqlData['img_avatar'] as Blob?)?.toString(),
          supplierId: userSqlData['fornecedor_id'],
        );
      }
    } on MySqlException catch (e, s) {
      log.error('Erro ao realizar login com rede social', e, s);
      throw DatabaseException();
    } finally {
      await conn?.close();
    }
  }

  @override
  Future<void> updateUserDeviceTokenAndRefreshToken(User user) async {
    MySqlConnection? conn;

    try {
      conn = await connection.openConection();
      final setParams = {};
      if (user.iosToken != null) {
        setParams.putIfAbsent('ios_token', () => user.iosToken);
      } else {
        setParams.putIfAbsent('android_token', () => user.androidToken);
      }
      final query = '''
        update usuario
        set
          ${setParams.keys.elementAt(0)} = ?,
          refresh_token = ?
        where 
          id = ?
    ''';
      await conn.query(query, [
        setParams.values.elementAt(0),
        user.refreshToken!,
        user.id!,
      ]);
    } on MySqlException catch (e, s) {
      log.error('Erro ao confirmar login', e, s);
      throw DatabaseException();
    } finally {
      await conn?.close();
    }
  }

  @override
  Future<void> updateRefreshToken(User user) async {
    MySqlConnection? conn;

    try {
      conn = await connection.openConection();
      await conn.query('update usuario set refresh_token = ? where id = ?', [
        user.refreshToken,
        user.id,
      ]);
    } on MySqlException catch (e, s) {
      log.error('Erro ao atualizar refresh token', e, s);
      throw DatabaseException();
    } finally {
      await conn?.close();
    }
  }

  @override
  Future<User> findById(int id) async {
    MySqlConnection? conn;

    try {
      conn = await connection.openConection();
      final result = await conn.query('''
        select 
          id ,email, tipo_cadastro, ios_token, android_token,
          refresh_token, img_avatar, fornecedor_id
        from usuario
        where id = ?
    ''', [id]);
      if (result.isEmpty) {
        log.error('Usuario nao encontrado com o id[$id]');
        throw UserNotFoundException(
            message: 'Usuario nao encontrado com o id[$id]');
      } else {
        final userSqlData = result.first;
        return User(
          id: userSqlData['id'],
          email: userSqlData['email'],
          registerType: userSqlData['tipo_cadastro'],
          iosToken: (userSqlData['ios_token'] as Blob?)?.toString(),
          androidToken: (userSqlData['android_token'] as Blob?)?.toString(),
          imageAvatar: (userSqlData['img_avatar'] as Blob?)?.toString(),
          supplierId: userSqlData['fornecedor_id'],
        );
      }
    } on MySqlException catch (e, s) {
      log.error('Erro ao buscar usuario por id', e, s);
      throw DatabaseException();
    } finally {
      await conn?.close();
    }
  }

  @override
  Future<void> updateUrlAvatar(int id, String urlAvatar) async {
    MySqlConnection? conn;

    try {
      conn = await connection.openConection();
      await conn.query('''
        update usuario set
          img_avatar= ?
        where id = ?
    ''', [urlAvatar, id]);
    } on MySqlException catch (e, s) {
      log.error('Erro ao atualizar url avatar', e, s);
      throw DatabaseException();
    } finally {
      await conn?.close();
    }
  }

  @override
  Future<void> updateDeviceToken(
      int id, String token, Platform platform) async {
    MySqlConnection? conn;

    try {
      conn = await connection.openConection();
      var set = '';
      if (platform == Platform.ios) {
        set = 'ios_token = ?';
      } else {
        set = 'android_token = ?';
      }
      final query = 'update usuario set $set where id = ?';

      await conn.query(query, [token, id]);
    } on MySqlException catch (e, s) {
      log.error('Erro ao atualizar token', e, s);
      throw DatabaseException();
    } finally {
      await conn?.close();
    }
  }
}
