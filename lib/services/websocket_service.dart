// Archivo: lib/services/websocket_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

class WebSocketService {
  WebSocketChannel? _channel;
  Function(String)? _messageCallback;
  String? _serverUrl;
  bool _isConnected = false;

  bool get isConnected => _isConnected;

  // Conectar al servidor WebSocket
  Future<bool> connect(
    String serverUrl,
    Function(String) onMessageReceived,
  ) async {
    try {
      if (_isConnected) {
        await disconnect();
      }

      _serverUrl = serverUrl;
      _messageCallback = onMessageReceived;

      debugPrint('Intentando conectar a WebSocket: $serverUrl');
      _channel = WebSocketChannel.connect(Uri.parse(serverUrl));

      _channel!.stream.listen(
        (message) {
          debugPrint('WebSocket mensaje recibido: $message');
          if (_messageCallback != null) {
            _messageCallback!(message);
          }
        },
        onDone: () {
          _isConnected = false;
          debugPrint('WebSocket desconectado');
        },
        onError: (error) {
          _isConnected = false;
          debugPrint('Error WebSocket: $error');
        },
      );

      _isConnected = true;
      debugPrint('WebSocket conectado a $serverUrl');
      return true;
    } catch (e) {
      debugPrint('Error al conectar WebSocket: $e');
      _isConnected = false;
      return false;
    }
  }

  // Enviar mensaje
  Future<bool> sendMessage(Map<String, dynamic> data) async {
    if (!_isConnected || _channel == null) {
      debugPrint('No se puede enviar mensaje: WebSocket no conectado');
      return false;
    }

    try {
      final jsonMessage = jsonEncode(data);
      debugPrint('Enviando mensaje: $jsonMessage');
      _channel!.sink.add(jsonMessage);
      return true;
    } catch (e) {
      debugPrint('Error al enviar mensaje: $e');
      return false;
    }
  }

  // Desconectar del servidor
  Future<void> disconnect() async {
    if (_channel != null) {
      await _channel!.sink.close(status.goingAway);
      _isConnected = false;
      debugPrint('WebSocket desconectado manualmente');
    }
  }

  // Reconectar al servidor
  Future<bool> reconnect() async {
    if (_serverUrl != null && _messageCallback != null) {
      return await connect(_serverUrl!, _messageCallback!);
    }
    return false;
  }
}
