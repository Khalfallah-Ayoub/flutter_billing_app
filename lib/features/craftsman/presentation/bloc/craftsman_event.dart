part of 'craftsman_bloc.dart';

abstract class CraftsmanEvent extends Equatable {
  const CraftsmanEvent();
  @override List<Object?> get props => [];
}

class LoadCraftsmenEvent extends CraftsmanEvent {}

class AddCraftsmanEvent extends CraftsmanEvent {
  final String name;
  final String phone;
  final String? address;
  final String? specialty;
  final String? notes;
  const AddCraftsmanEvent({
    required this.name,
    required this.phone,
    this.address,
    this.specialty,
    this.notes,
  });
  @override List<Object?> get props => [name, phone];
}

class UpdateCraftsmanEvent extends CraftsmanEvent {
  final Craftsman craftsman;
  const UpdateCraftsmanEvent(this.craftsman);
  @override List<Object?> get props => [craftsman];
}

class DeleteCraftsmanEvent extends CraftsmanEvent {
  final String id;
  const DeleteCraftsmanEvent(this.id);
  @override List<Object?> get props => [id];
}
