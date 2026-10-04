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
// Polls every 5 s for new messages only (AU-10); no realtime channel yet.
class ChatCubit extends Cubit<ChatState> {
  final BookingRepository _repo;
  final String bookingId;
  Timer? _poll;

  ChatCubit(this._repo, this.bookingId) : super(const ChatState()) {
    load();
    _poll = Timer.periodic(const Duration(seconds: 5), (_) => _tick());
  }

  /// AU-10: one request at a time (a slow answer used to let polls pile up).
  bool _inFlight = false;
  int _ticks = 0;

  /// Every 5 s: only messages newer than the last one; every 12th tick (about
  /// a minute) the whole thread, so a message moderation hid disappears too.
  void _tick() {
    _ticks++;
    final last = state.messages?.isNotEmpty == true ? state.messages!.last.id : null;
    if (_ticks % 12 == 0 || last == null) {
      load();
    } else {
      _loadNewer(last);
    }
  }

  Future<void> load() async {
    if (_inFlight) return;
    _inFlight = true;
    try {
      final r = await _repo.getChat(bookingId);
      if (isClosed) return;
      r.fold(
        (f) => emit(state.copyWith(error: f.message)),
        (m) => emit(state.copyWith(messages: m)),
      );
    } finally {
      _inFlight = false;
    }
  }

  Future<void> _loadNewer(String afterId) async {
    if (_inFlight) return;
    _inFlight = true;
    try {
      final r = await _repo.getChat(bookingId, afterId: afterId);
      if (isClosed) return;
      r.fold((f) => emit(state.copyWith(error: f.message)), (m) {
        if (m.isEmpty) return;
        final known = {for (final e in state.messages ?? const []) e.id};
        final fresh = [for (final e in m) if (!known.contains(e.id)) e];
        if (fresh.isNotEmpty) {
          emit(state.copyWith(messages: [...?state.messages, ...fresh]));
        }
      });
    } finally {
      _inFlight = false;
    }
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
