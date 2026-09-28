import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/chat_message_entity.dart';
import '../../domain/repositories/booking_repository.dart';

class ChatState {
  final List<ChatMessageEntity>? messages;
  final String? error;

  /// Messages this user reported this session (hides their Report link).
  final Set<String> reported;

  const ChatState({this.messages, this.error, this.reported = const {}});

  ChatState copyWith({
    List<ChatMessageEntity>? messages,
    String? error,
    Set<String>? reported,
  }) => ChatState(
    messages: messages ?? this.messages,
    error: error,
    reported: reported ?? this.reported,
  );
}

/// Booking chat (ChatController).
// ponytail: polls every 5s; no realtime channel in the backend or pubspec.
class ChatCubit extends Cubit<ChatState> {
  final BookingRepository _repo;
  final String bookingId;
  Timer? _poll;

  ChatCubit(this._repo, this.bookingId) : super(const ChatState()) {
    load();
    _poll = Timer.periodic(const Duration(seconds: 5), (_) => load());
  }

  Future<void> load() async {
    final r = await _repo.getChat(bookingId);
    if (isClosed) return;
    r.fold(
      (f) => emit(state.copyWith(error: f.message)),
      (m) => emit(state.copyWith(messages: m)),
    );
  }

  /// Returns false (and keeps the draft) when sending fails.
  Future<bool> send(String text) async {
    final r = await _repo.sendChat(bookingId, text);
    if (isClosed) return false;
    return r.fold(
      (f) {
        emit(state.copyWith(error: f.message));
        return false;
      },
      (m) {
        emit(state.copyWith(messages: [...?state.messages, m]));
        return true;
      },
    );
  }

  Future<void> report(String messageId) async {
    final r = await _repo.reportChatMessage(bookingId, messageId);
    if (isClosed) return;
    r.fold(
      (f) => emit(state.copyWith(error: f.message)),
      (_) => emit(state.copyWith(reported: {...state.reported, messageId})),
    );
  }

  @override
  Future<void> close() {
    _poll?.cancel();
    return super.close();
  }
}
