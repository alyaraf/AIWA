import 'package:equatable/equatable.dart';

abstract class HomeEvent extends Equatable {
  const HomeEvent();
  @override
  List<Object?> get props => [];
}

class HomeLoadEvent extends HomeEvent {
  final double lat;
  final double lng;
  final String? category;

  /// The user's searchRadiusMaxKm (Preferences); 5 km is the prototype default.
  final double radiusKm;

  const HomeLoadEvent({
    required this.lat,
    required this.lng,
    this.category,
    this.radiusKm = 5,
  });

  @override
  List<Object?> get props => [lat, lng, category, radiusKm];
}

class HomeSearchEvent extends HomeEvent {
  final String query;
  const HomeSearchEvent(this.query);
  @override
  List<Object?> get props => [query];
}

class HomeLoadMoreEvent extends HomeEvent {}

class HomeCategoryFilterEvent extends HomeEvent {
  final String? category;
  const HomeCategoryFilterEvent(this.category);
  @override
  List<Object?> get props => [category];
}
