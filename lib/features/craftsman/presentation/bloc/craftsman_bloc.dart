import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/craftsman.dart';
import '../../data/models/craftsman_model.dart';
import '../../../../core/data/hive_database.dart';

part 'craftsman_event.dart';
part 'craftsman_state.dart';

class CraftsmanBloc extends Bloc<CraftsmanEvent, CraftsmanState> {
  final _uuid = const Uuid();

  CraftsmanBloc() : super(const CraftsmanState()) {
    on<LoadCraftsmenEvent>(_onLoad);
    on<AddCraftsmanEvent>(_onAdd);
    on<UpdateCraftsmanEvent>(_onUpdate);
    on<DeleteCraftsmanEvent>(_onDelete);
  }

  Future<void> _onLoad(LoadCraftsmenEvent event, Emitter<CraftsmanState> emit) async {
    final box = HiveDatabase.craftsmanBox;
    final craftsmen = box.values.map((m) => m.toEntity()).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    emit(state.copyWith(craftsmen: craftsmen));
  }

  Future<void> _onAdd(AddCraftsmanEvent event, Emitter<CraftsmanState> emit) async {
    final craftsman = Craftsman(
      id: _uuid.v4(),
      name: event.name,
      phone: event.phone,
      address: event.address,
      specialty: event.specialty,
      notes: event.notes,
      createdAt: DateTime.now(),
    );
    final model = CraftsmanModel.fromEntity(craftsman);
    await HiveDatabase.craftsmanBox.put(craftsman.id, model);
    add(LoadCraftsmenEvent());
  }

  Future<void> _onUpdate(UpdateCraftsmanEvent event, Emitter<CraftsmanState> emit) async {
    final model = CraftsmanModel.fromEntity(event.craftsman);
    await HiveDatabase.craftsmanBox.put(event.craftsman.id, model);
    add(LoadCraftsmenEvent());
  }

  Future<void> _onDelete(DeleteCraftsmanEvent event, Emitter<CraftsmanState> emit) async {
    await HiveDatabase.craftsmanBox.delete(event.id);
    add(LoadCraftsmenEvent());
  }
}
