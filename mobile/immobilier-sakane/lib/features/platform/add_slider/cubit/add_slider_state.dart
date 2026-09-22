part of 'add_slider_cubit.dart';


class AddSliderState {

  AppStatus? actionStatus;
  String? error;
  SliderModel? slider;
  Map<String,dynamic>? errors;

  AddSliderState({
    this.actionStatus,
    this.error,
    this.slider,
    this.errors
  });

  AddSliderState copyWith({
    AppStatus? actionStatus,
    String? error,
    SliderModel? slider,
    Map<String,dynamic>? errors
  }) {
    return AddSliderState(
      actionStatus: actionStatus ?? this.actionStatus,
      error: error ?? this.error,
      slider: slider ?? this.slider,
      errors: errors
    );
  }

}




