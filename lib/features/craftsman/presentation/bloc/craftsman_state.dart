part of 'craftsman_bloc.dart';

class CraftsmanState extends Equatable {
  final List<Craftsman> craftsmen;

  const CraftsmanState({this.craftsmen = const []});

  CraftsmanState copyWith({List<Craftsman>? craftsmen}) =>
      CraftsmanState(craftsmen: craftsmen ?? this.craftsmen);

  @override
  List<Object?> get props => [craftsmen];
}
