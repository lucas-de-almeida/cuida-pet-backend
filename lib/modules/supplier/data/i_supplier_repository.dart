import 'package:cuidapet_api/dtos/supplier_near_by_me_dto.dart';
import 'package:cuidapet_api/entities/supplier.dart';
import 'package:cuidapet_api/entities/supplier_service.dart';

abstract class ISupplierRepository {
  Future<List<SupplierNearByMeDto>> findNearByPosition(
      double lat, double lng, int distance);

  Future<Supplier?> findById(int id);
  Future<List<SupplierService>> findServiceBySupplierId(int supplierId);
  Future<bool> checkUserEmailExists(String email);
  Future<int> saveSupplier(Supplier supplier);
  Future<Supplier> update(Supplier supplier);
}
