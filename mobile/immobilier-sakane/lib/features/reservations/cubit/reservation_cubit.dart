import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:dio/dio.dart';
import 'package:immobilier/core/extensions/extension_on_date.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/constants/enums/app_status.dart';
import '../../../core/dependencies/dependencies.dart';
import '../../../core/utils/logout.dart';
import '../../../exceptions/network_connectivity_exception.dart';
import '../../../exceptions/unauthenticated_exception.dart';
import '../../../exceptions/unauthorized_exception.dart';
import '../../../models/booking.dart';
import '../../../repository/repository.dart';

part 'reservation_state.dart';

class ReservationCubit extends Cubit<ReservationState> {
  ReservationCubit() : super(ReservationState(
      from: DateTime.now().add(Duration(days: -7)),
      to: DateTime.now()
  ));


  void fetchData()async{
    try{
      emit(state.copyWith(fetchDataStatus: AppStatus.loading));
      Repository repository=Dependencies.get<Repository>();
      List<Booking> bookings=await repository.fetchBookings(
          state.from!.formattedDateEn,
          state.to!.formattedDateEn,
          type: "realworld",
      );
      emit(state.copyWith(fetchDataStatus: AppStatus.success,bookings: bookings));
    }on NetworkConnectivityException catch(ex){
      emit(state.copyWith(fetchDataStatus: AppStatus.error,error: AppStrings.checkConnectivity));
    }on UnAuthenticatedException catch (ex){
      logout();
    }on UnAuthorizedException catch(ex){
      emit(state.copyWith(fetchDataStatus: AppStatus.error,error: AppStrings.authorizationError));
    }catch (ex){
      emit(state.copyWith(fetchDataStatus: AppStatus.error,error: "Error"));
    }
  }
  /// Applique une periode entiere d'un coup (filtres rapides) puis
  /// recharge : une seule emission au lieu de deux.
  void selectPeriode(DateTime from, DateTime to){
    emit(state.copyWith(from: from, to: to));
    fetchData();
  }

  void selectDate(DateTime date,String type){
    if(type=="from"){
      emit(state.copyWith(from: date));
    }else{
      emit(state.copyWith(to: date));
    }
  }

  void viewDocument(String contract)async{
    Directory dir=await getTemporaryDirectory();
    String fullPath="${dir.path}/${contract.split("/").last}";
    await Dio().download(contract, fullPath);
    OpenFile.open(fullPath);
  }


  /// Supprime la réservation. [rembourse] : le client est-il remboursé ?
  /// Si oui, [montant] sort de la caisse de celui qui supprime.
  void deleteBooking(Booking boooking, {required bool rembourse, double? montant})async{
    try{
      emit(state.copyWith(actionStatus: AppStatus.loading));
      Repository repository=Dependencies.get<Repository>();
      await repository.deleteBooking(
        boooking.id!,
        rembourse: rembourse,
        montantRembourse: rembourse ? montant : null,
      );
      fetchData();
      emit(state.copyWith(actionStatus: AppStatus.success));
    }on NetworkConnectivityException catch(_){
      emit(state.copyWith(actionStatus: AppStatus.error,error: AppStrings.checkConnectivity));
    }on UnAuthenticatedException catch (_){
      logout();
    }on UnAuthorizedException catch(_){
      emit(state.copyWith(actionStatus: AppStatus.error,error: AppStrings.authorizationError));
    }catch(ex){
      emit(state.copyWith(
        actionStatus: AppStatus.error,
        error: ex.toString().replaceFirst('Exception: ', ''),
      ));
    }
  }


}
