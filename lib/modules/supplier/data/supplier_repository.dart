import 'package:cuidapet_api/application/database/i_database_conection.dart';
import 'package:cuidapet_api/application/exceptions/database_exception.dart';
import 'package:cuidapet_api/application/logger/i_logger.dart';
import 'package:cuidapet_api/dtos/supplier_near_by_me_dto.dart';
import 'package:cuidapet_api/entities/category.dart';
import 'package:cuidapet_api/entities/supplier.dart';
import 'package:cuidapet_api/entities/supplier_service.dart';
import 'package:injectable/injectable.dart';
import 'package:mysql1/mysql1.dart';

import './i_supplier_repository.dart';

@LazySingleton(as: ISupplierRepository)
class SupplierRepository implements ISupplierRepository {
  final IDatabaseConection conection;
  final ILogger log;
  SupplierRepository({
    required this.conection,
    required this.log,
  });
  @override
  Future<List<SupplierNearByMeDto>> findNearByPosition(
      double lat, double lng, int distance) async {
    MySqlConnection? conn;
    try {
      conn = await conection.openConection();
      final query = '''
          SELECT f.id, f.nome, f.logo, f.categorias_fornecedor_id,
          (6371 *
            acos(
                            cos(radians($lat)) *
                            cos(radians(ST_X(f.latlng))) *
                            cos(radians($lng) - radians(ST_Y(f.latlng))) +
                            sin(radians($lat)) *
                            sin(radians(ST_X(f.latlng)))
                )) AS distancia
            FROM fornecedor f
            HAVING distancia <= $distance
            Order by distancia;
    ''';

      final result = await conn.query(query);
      return result
          .map(
            (f) => SupplierNearByMeDto(
              id: f['id'],
              name: f['nome'],
              logo: (f['logo'] as Blob?)?.toString(),
              distance: f['distancia'],
              categoryId: f['categorias_fornecedor_id'],
            ),
          )
          .toList();
    } on MySqlException catch (e, s) {
      log.error('Erro ao buscar fornecedores perto de mim', e, s);
      throw DatabaseException();
    } finally {
      await conn?.close();
    }
  }

  @override
  Future<Supplier?> findById(int id) async {
    MySqlConnection? conn;
    try {
      conn = await conection.openConection();
      final query = '''
        select
           f.id, f.nome, f.logo, f.endereco, f.telefone, ST_X(f.latlng) as lat, ST_Y(f.latlng) as lng,
          f.categorias_fornecedor_id, c.nome_categoria, c.tipo_categoria
        from fornecedor as f
          inner join categorias_fornecedor as c on (f.categorias_fornecedor_id = c.id)
        where 
          f.id = ?
    ''';
      final result = await conn.query(query, [id]);
      if (result.isNotEmpty) {
        final dataMysql = result.first;
        return Supplier(
          id: dataMysql['id'],
          name: dataMysql['nome'],
          logo: (dataMysql['logo'] as Blob?)?.toString(),
          lat: dataMysql['lat'],
          lng: dataMysql['lng'],
          phone: dataMysql['telefone'],
          address: dataMysql['endereco'],
          category: Category(
            id: dataMysql['categorias_fornecedor_id'],
            name: dataMysql['nome_categoria'],
            type: dataMysql['tipo_categoria'],
          ),
        );
      }
    } on MySqlException catch (e, s) {
      log.error('Erro ao buscar fornecedor', e, s);
      throw DatabaseException();
    } finally {
      await conn?.close();
    }
  }

  @override
  Future<List<SupplierService>> findServiceBySupplierId(int supplierId) async {
    MySqlConnection? conn;
    try {
      conn = await conection.openConection();
      final query = '''
        select
          id, fornecedor_id, nome_servico, valor_servico
        from fornecedor_servicos
        where fornecedor_id = ?
    ''';
      final result = await conn.query(query, [supplierId]);
      if (result.isEmpty) {
        return [];
      }
      return result
          .map((s) => SupplierService(
                id: s['id'],
                supplierId: s['fornecedor_id'],
                name: s['nome_servico'],
                price: s['valor_servico'],
              ))
          .toList();
    } on MySqlException catch (e, s) {
      log.error('Erro ao buscar os servicos de um fornecedor', e, s);
      throw DatabaseException();
    } finally {
      await conn?.close();
    }
  }

  @override
  Future<bool> checkUserEmailExists(String email) async {
    MySqlConnection? conn;
    try {
      conn = await conection.openConection();
      final result = await conn
          .query('select Count(*) from usuario where email = ?', [email]);
      final dataMysql = result.first;
      return dataMysql[0] > 0;
    } on MySqlException catch (e, s) {
      log.error('Erro ao verificar se login existe', e, s);
      throw DatabaseException();
    } finally {
      await conn?.close();
    }
  }

  @override
  Future<int> saveSupplier(Supplier supplier) async {
    MySqlConnection? conn;
    try {
      conn = await conection.openConection();
      final result = await conn.query('''
            insert into fornecedor(nome, logo, endereco, telefone, latlng, categorias_fornecedor_id)
            values (?,?,?,?,ST_GeomFromText(?),?)
          ''', [
        supplier.name,
        supplier.logo,
        supplier.address,
        supplier.phone,
        'POINT(${supplier.lat ?? 0} ${supplier.lng ?? 0})',
        supplier.category?.id
      ]);

      return result.insertId ?? 0;
    } on MySqlException catch (e, s) {
      log.error('Erro ao cadastrar novo fornecedor', e, s);
      throw DatabaseException();
    } finally {
      await conn?.close();
    }
  }

  @override
  Future<Supplier> update(Supplier supplier) async {
    MySqlConnection? conn;
    try {
      conn = await conection.openConection();
      final result = await conn.query('''
            update fornecedor
              set
                nome = ?,
                logo = ?,
                endereco = ?,
                telefone = ?,
                latlng = ST_GeomFromText(?),
                categorias_fornecedor_id = ?
              where
                id = ?
          ''', [
        supplier.name,
        supplier.logo,
        supplier.address,
        supplier.phone,
        'POINT(${supplier.lat ?? 0} ${supplier.lng ?? 0})',
        supplier.category?.id,
        supplier.id
      ]);
      Category? category;
      if (supplier.category?.id != null) {
        final resultCategory = await conn
            .query('select * from categorias_fornecedor where id = ?', [
          supplier.category?.id,
        ]);
        var categoryData = resultCategory.first;
        category = Category(
          id: categoryData['id'],
          name: categoryData['nome_categoria'],
          type: categoryData['tipo_categoria'],
        );
      }
      return supplier.copyWith(category: category);
    } on MySqlException catch (e, s) {
      log.error('Erro ao atualizar dados do fornecedor', e, s);
      throw DatabaseException();
    } finally {
      await conn?.close();
    }
  }
}
