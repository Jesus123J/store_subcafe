import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../errors/failure.dart';

/// Contrato base para todos los UseCases.
/// - `Type` = tipo de retorno exitoso
/// - `Params` = parámetros de entrada (usar `NoParams` si no recibe nada)
abstract class UseCase<Type, Params> {
  Future<Either<Failure, Type>> call(Params params);
}

class NoParams extends Equatable {
  const NoParams();
  @override
  List<Object?> get props => [];
}
