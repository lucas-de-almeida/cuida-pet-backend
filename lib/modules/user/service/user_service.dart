import 'package:cuidapet_api/application/exceptions/service_exception.dart';
import 'package:cuidapet_api/application/exceptions/user_not_found_exception.dart';
import 'package:cuidapet_api/application/helpers/jwt_helper.dart';
import 'package:cuidapet_api/application/logger/i_logger.dart';
import 'package:cuidapet_api/entities/user.dart';
import 'package:cuidapet_api/modules/user/data/i_user_repository.dart';
import 'package:cuidapet_api/modules/user/view_models/refresh_token_view_model.dart';
import 'package:cuidapet_api/modules/user/view_models/update_url_avatar_view_model.dart';
import 'package:cuidapet_api/modules/user/view_models/user_confirm_input_model.dart';
import 'package:cuidapet_api/modules/user/view_models/user_refresh_token_input_model.dart';
import 'package:cuidapet_api/modules/user/view_models/user_save_input_model.dart';
import 'package:cuidapet_api/modules/user/view_models/user_update_token_device_input_model.dart';
import 'package:injectable/injectable.dart';
import 'package:jaguar_jwt/jaguar_jwt.dart';

import './i_user_service.dart';

@LazySingleton(as: IUserService)
class UserService implements IUserService {
  IUserRepository userRepository;
  ILogger log;

  UserService({
    required this.userRepository,
    required this.log,
  });
  @override
  Future<User> createUser(UserSaveInputModel user) {
    final userEntity = User(
        email: user.email,
        password: user.password,
        registerType: 'App',
        supplierId: user.supplierId);
    return userRepository.createUser(userEntity);
  }

  @override
  Future<User> loginWithEmailPassword(
          String email, String password, bool isSupplierId) =>
      userRepository.loginWithEmailPassword(email, password, isSupplierId);

  @override
  Future<User> loginWithSocialKey(
      String email, String avatar, String socialType, String socialKey) async {
    try {
      return await userRepository.loginWithSocialKey(
          email, socialKey, socialType);
    } on UserNotFoundException catch (e, s) {
      log.error('usuario nao encontrado, criando um usuario', e, s);
      final user = User(
          email: email,
          imageAvatar: avatar,
          registerType: socialType,
          socialKey: socialKey,
          password: DateTime.now().toString());
      return await userRepository.createUser(user);
    }
  }

  @override
  Future<String> confirmLogin(UserConfirmInputModel InputModel) async {
    final refreshToken = JwtHelper.refreshToken(InputModel.accesToken);
    final user = User(
      id: InputModel.userId,
      refreshToken: refreshToken,
      iosToken: InputModel.iosDeviceToken,
      androidToken: InputModel.androidDeviceToken,
    );
    await userRepository.updateUserDeviceTokenAndRefreshToken(user);
    return refreshToken;
  }

  @override
  Future<RefreshTokenViewModel> refreshToken(
      UserRefreshTokenInputModel model) async {
    _validadeRefreshToken(model);
    final newAccessToken = JwtHelper.generateJWT(model.user, model.supplier);
    final newRefreshToken =
        JwtHelper.refreshToken(newAccessToken).replaceAll('Bearer ', '');
    final user = User(id: model.user, refreshToken: newRefreshToken);
    await userRepository.updateRefreshToken(user);
    return RefreshTokenViewModel(
        accessToken: newAccessToken, refreshToken: newRefreshToken);
  }

  void _validadeRefreshToken(UserRefreshTokenInputModel model) {
    try {
      final refreshToen = model.refreshToken.split(' ');
      if (refreshToen.length != 2 || refreshToen.first != 'Bearer') {
        log.error('Refresh token invalido');
        throw ServiceException('Refresh token invalido');
      }
      final refreshTokenClaim = JwtHelper.getClaims(refreshToen.last);
      refreshTokenClaim.validate(issuer: model.accessToken);
    } on ServiceException {
      rethrow;
    } on JwtException catch (e) {
      log.error('Refresh token invalido', e);
      throw ServiceException('Refresh token invalido');
    } catch (e) {
      throw ServiceException('Erro ao validar refresh token');
    }
  }

  @override
  Future<User> findById(int id) => userRepository.findById(id);

  @override
  Future<User> updateAvatar(UpdateUrlAvatarViewModel viewModel) async {
    await userRepository.updateUrlAvatar(viewModel.userId, viewModel.urlAvatar);
    return findById(viewModel.userId);
  }

  @override
  Future<void> updateDeviceToken(UserUpdateTokenDeviceInputModel model) =>
      userRepository.updateDeviceToken(
        model.userId,
        model.token,
        model.platform,
      );
}
