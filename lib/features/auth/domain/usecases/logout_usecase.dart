import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/auth_repository.dart';

class LogoutUseCase implements UseCase<void, NoParams> {
  LogoutUseCase(this._repository);
  final AuthRepository _repository;

  @override
  Future<Either<Failure, void>> call(NoParams params) {
    return _repository.logout();
  }
}
