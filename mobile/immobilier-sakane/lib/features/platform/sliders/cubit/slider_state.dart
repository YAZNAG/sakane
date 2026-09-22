part of 'slider_cubit.dart';



class SliderState {

  AppStatus? fetchDataStatus;
  AppStatus? actionStatus;
  String? error;
  List<SliderModel>? sliders;
  Map<String,dynamic>? errors;

  SliderState({
    this.fetchDataStatus,
    this.error,
    this.sliders,
    this.actionStatus,
    this.errors
  });

  SliderState copyWith({
    AppStatus? fetchDataStatus,
    String? error,
    List<SliderModel>? sliders,
    AppStatus? actionStatus,
    Map<String,dynamic>? errors
  }) {
    return SliderState(
      fetchDataStatus: fetchDataStatus ?? this.fetchDataStatus,
      error: error ?? this.error,
      sliders: sliders ?? this.sliders,
      actionStatus: actionStatus,
      errors: errors
    );
  }

}

