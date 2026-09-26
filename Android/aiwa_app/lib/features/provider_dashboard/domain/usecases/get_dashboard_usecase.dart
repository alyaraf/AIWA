import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../repositories/dashboard_repository.dart';

class GetDashboardUseCase {
  final DashboardRepository _repository;
  GetDashboardUseCase(this._repository);

  Future<Either<Failure, DashboardStats>> call() => _repository.getStats();
}
