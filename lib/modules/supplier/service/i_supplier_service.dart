import 'package:cuidapet_api/dtos/supplier_near_by_me_dto.dart';
import 'package:cuidapet_api/entities/supplier.dart';
import 'package:cuidapet_api/entities/supplier_service.dart';
import 'package:cuidapet_api/modules/supplier/view_models/create_supplier_user_view_model.dart';
import 'package:cuidapet_api/modules/supplier/view_models/update_supplier_input_model.dart';

abstract class ISupplierService {
  Future<List<SupplierNearByMeDto>> findNearByMe(double lat, double lng);
  Future<Supplier?> finById(int id);
  Future<List<SupplierService>> findServicesBySupplier(int supplierId);
  Future<bool> checkUserEmailExists(String email);
  Future<void> createUserSupplier(CreateSupplierUserViewModel model);
  Future<Supplier> update(UpdateSupplierInputModel model);
}
