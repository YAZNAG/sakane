part of 'new_version_bloc.dart';

@immutable
abstract class NewVersionEvent {}


class DownloadNewVersion extends NewVersionEvent{}
