import 'package:bloc/bloc.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/models/slider.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/dependencies/dependencies.dart';
import '../../../../core/utils/logout.dart';
import '../../../../exceptions/network_connectivity_exception.dart';
import '../../../../exceptions/unauthenticated_exception.dart';
import '../../../../exceptions/unauthorized_exception.dart';
import '../../../../exceptions/validation_exception.dart';
import '../../../../repository/repository.dart';

part 'add_slider_state.dart';

class AddSliderCubit extends Cubit<AddSliderState> {
  AddSliderCubit() : super(AddSliderState());

  void addSlider(SliderModel slider) async {
    try {
      emit(state.copyWith(actionStatus: AppStatus.loading));
      Repository repository = Dependencies.get<Repository>();
      SliderModel sliderR = await repository.addSlider(slider);
      emit(state.copyWith(actionStatus: AppStatus.success,slider: sliderR));
    } on NetworkConnectivityException catch (ex) {
      emit(
        state.copyWith(
          actionStatus: AppStatus.error,
          error: AppStrings.checkConnectivity,
        ),
      );
    } on UnAuthenticatedException catch (ex) {
      logout();
    } on UnAuthorizedException catch (ex) {
      emit(
        state.copyWith(
          actionStatus: AppStatus.error,
          error: AppStrings.authorizationError,
        ),
      );
    } on ValidatorException catch (ex) {
      emit(state.copyWith(actionStatus: AppStatus.error,errors: ex.errors));
    } catch (ex) {
      emit(state.copyWith(actionStatus: AppStatus.error, error: "Error"));
    }
  }
}
