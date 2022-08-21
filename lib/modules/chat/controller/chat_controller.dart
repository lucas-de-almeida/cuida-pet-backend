import 'dart:async';
import 'dart:convert';

import 'package:cuidapet_api/application/logger/i_logger.dart';
import 'package:cuidapet_api/entities/supplier.dart';
import 'package:cuidapet_api/modules/chat/view_models/chat_notify_view_model.dart';
import 'package:injectable/injectable.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'package:cuidapet_api/modules/chat/service/i_chat_service.dart';

part 'chat_controller.g.dart';

//chasts/schedule/12/start-chat
@Injectable()
class ChatController {
  final IChatService service;
  final ILogger log;
  ChatController({
    required this.service,
    required this.log,
  });
  @Route.post('/schedule/<scheduleId>/start-chat')
  Future<Response> startChatByScheduleId(
      Request request, String scheduleId) async {
    try {
      final chatId = await service.startChat(int.parse(scheduleId));
      return Response.ok(jsonEncode({'chat_id': chatId}));
    } catch (e, s) {
      log.error('Erro ao iniciar chat', e, s);
      return Response.internalServerError();
    }
  }

  @Route.post('/notify')
  Future<Response> notifyUser(Request request) async {
    try {
      final model = ChatNotifyViewModel(await request.readAsString());
      await service.notifyChat(model);
      return Response.ok(jsonEncode({}));
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode(
          {'message': 'Erro ao enviar notificação'},
        ),
      );
    }
  }

  @Route.get('/user')
  Future<Response> fingChatsByUser(Request request) async {
    try {
      final user = int.parse(request.headers['user']!);
      final chats = await service.getChatsByUser(user);
      final resultChats = chats
          .map((c) => {
                'id': c.id,
                'user': c.user,
                'name': c.name,
                'pet_name': c.petName,
                'supplier': {
                  'id': c.supplier.id,
                  'name': c.supplier.name,
                  'logo': c.supplier.logo,
                }
              })
          .toList();
      return Response.ok(jsonEncode(resultChats));
    } catch (e, s) {
      log.error('Erro ao buscar chats do usuario', e, s);
      return Response.internalServerError();
    }
  }

  Router get router => _$ChatControllerRouter(this);
}
