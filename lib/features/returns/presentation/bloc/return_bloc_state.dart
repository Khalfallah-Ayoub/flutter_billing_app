part of 'return_bloc.dart';

class ReturnBlocState extends Equatable {
  final List<ReturnInvoice> returns;
  final ReturnInvoice? lastAdded;

  const ReturnBlocState({this.returns = const [], this.lastAdded});

  ReturnBlocState copyWith({List<ReturnInvoice>? returns, ReturnInvoice? lastAdded}) =>
      ReturnBlocState(
        returns: returns ?? this.returns,
        lastAdded: lastAdded ?? this.lastAdded,
      );

  @override
  List<Object?> get props => [returns, lastAdded];
}
