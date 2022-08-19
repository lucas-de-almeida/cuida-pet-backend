import 'package:cuidapet_api/application/helpers/request_mapping.dart';

class UpdateUrlAvatarViewModel extends RequestMapping {
  late String urlAvatar;
  int userId;

  UpdateUrlAvatarViewModel({
    required this.userId,
    required String dataRequest,
  }) : super(dataRequest);

  @override
  void map() {
    urlAvatar = data['url_avatar'];
  }
}
