import 'package:equatable/equatable.dart';

abstract class DashboardEvent extends Equatable {
  const DashboardEvent();
  @override
  List<Object?> get props => [];
}

/// Loads stats + pending requests; later loads refresh in place.
class DashboardLoadEvent extends DashboardEvent {}
