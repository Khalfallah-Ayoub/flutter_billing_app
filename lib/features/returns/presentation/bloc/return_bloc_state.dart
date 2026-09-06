part of 'return_bloc.dart';

class ReturnBlocState extends Equatable {
  final List<ReturnInvoice> returns;
  final ReturnInvoice? lastAdded;
  final String? error;

  const ReturnBlocState({this.returns = const [], this.lastAdded, this.error});

  ReturnBlocState copyWith({
    List<ReturnInvoice>? returns,
    ReturnInvoice? lastAdded,
    String? error,
    bool clearError = false,
  }) =>
      ReturnBlocState(
        returns: returns ?? this.returns,
        lastAdded: lastAdded ?? this.lastAdded,
        error: clearError ? null : (error ?? this.error),
      );

  @override
  List<Object?> get props => [returns, lastAdded, error];
}
