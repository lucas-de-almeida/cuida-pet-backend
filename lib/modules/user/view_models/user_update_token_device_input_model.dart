import 'package:cuidapet_api/application/helpers/request_mapping.dart';
import 'package:cuidapet_api/modules/user/view_models/platform.dart';

class UserUpdateTokenDeviceInputModel extends RequestMapping {
  int userId;
  late String token;
  late Platform platform;
  UserUpdateTokenDeviceInputModel({
    required this.userId,
    required String dataRequest,
  }) : super(dataRequest);

  @override
  void map() {
    token = data['token'];
    if (data['platform'].toString().toLowerCase() == 'ios') {
      platform = Platform.ios;
    } else {
      platform = Platform.android;
    }
  }
}
