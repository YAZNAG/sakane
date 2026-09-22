import 'dart:async';
import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:dio/dio.dart';
import 'package:flutter_app_installer/flutter_app_installer.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/models/application.dart';
import 'package:meta/meta.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/constants/enums/app_status.dart';


part 'new_version_event.dart';
part 'new_version_state.dart';

class NewVersionBloc extends Bloc<NewVersionEvent, NewVersionState> {

  NewVersionBloc() : super(NewVersionState()) {
    on<DownloadNewVersion>(_downloadNewVersion);
  }

  FutureOr<void> _downloadNewVersion(DownloadNewVersion event, Emitter<NewVersionState> emit) async{
    try{
      emit(state.copyWith(downloadStatus: AppStatus.loading));

      Directory directory=await getTemporaryDirectory();
      String destinationPath="${directory.path}/app.apk";

      AppVersion appVersion=Dependencies.get<AppVersion>();
      String apkUrl=appVersion.apkUrl!;

      Dio dio=Dio();
      await dio.download(apkUrl, destinationPath,onReceiveProgress: (count,total)=>calculProgress(count,total,emit));
      FlutterAppInstaller flutterAppInstaller=FlutterAppInstaller();
      flutterAppInstaller.installApk(filePath: destinationPath);
      //emit(state.copyWith(downloadStatus: AppStatus.success));
    }catch(ex){
      emit(state.copyWith(error: ex.toString(),downloadStatus: AppStatus.error));
    }
  }

  void calculProgress(count,total,Emitter<NewVersionState> emit){
    double prog=count/total;

    emit(state.copyWith(progress: prog));
  }


}
