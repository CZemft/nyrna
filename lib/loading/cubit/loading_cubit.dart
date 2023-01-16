import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../native_platform/native_platform.dart';

part 'loading_state.dart';

class LoadingCubit extends Cubit<LoadingState> {
  final NativePlatform nativePlatform;

  LoadingCubit()
      : nativePlatform = NativePlatform(),
        super(LoadingInitial()) {
    checkDependencies();
  }

  Future<void> checkDependencies() async {
    final dependenciesSatisfied = await nativePlatform.checkDependencies();
    final newState = dependenciesSatisfied ? LoadingSuccess() : LoadingFailed();
    emit(newState);
  }
}
