part of 'new_version_bloc.dart';

class NewVersionState {

  AppStatus? downloadStatus;
  String? error;
  double? progress;

  NewVersionState({
    this.downloadStatus,
    this.error,
    this.progress,
  });

  NewVersionState copyWith({
    AppStatus? downloadStatus,
    String? error,
    double? progress,
  }) {
    return NewVersionState(
      downloadStatus: downloadStatus ?? this.downloadStatus,
      error: error ,
      progress: progress ?? this.progress,
    );
  }
}


