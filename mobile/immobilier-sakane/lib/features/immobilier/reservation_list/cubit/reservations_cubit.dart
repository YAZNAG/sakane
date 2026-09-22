import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:dio/dio.dart';
import 'package:immobilier/core/constants/app_strings.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/core/extensions/extension_on_date.dart';
import 'package:immobilier/core/utils/logout.dart';
import 'package:immobilier/exceptions/network_connectivity_exception.dart';
import 'package:immobilier/exceptions/unauthenticated_exception.dart';
import 'package:immobilier/exceptions/unauthorized_exception.dart';
import 'package:immobilier/models/booking.dart';
import 'package:immobilier/repository/repository.dart';
import 'package:meta/meta.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

part 'reservations_state.dart';

class ReservationsCubit extends Cubit<ReservationsState> {
  ReservationsCubit(int id) : super(ReservationsState(
      id: id,
      from: DateTime.now().add(Duration(days: -7)),
    to: DateTime.now()
      )
  );


  void fetchData()async{
    try{
      emit(state.copyWith(fetchDataStatus: AppStatus.loading));
      Repository repository=Dependencies.get<Repository>();
      List<Booking> bookings=await repository.fetchBookings(
          state.from!.formattedDateEn,
          state.to!.formattedDateEn,
        type: "realworld",
        id: state.id
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
  void selectDate(DateTime date,String type){
    if(type=="from"){
      emit(state.copyWith(from: date));
    }else{
      emit(state.copyWith(to: date));
    }
  }

  /// Rapatrie le contrat et rend son chemin : c'est l'écran, et non le
  /// cubit, qui décide de la manière de l'afficher.
  Future<String> telechargerContrat(String contract) async {
    final Directory dir = await getTemporaryDirectory();
    final String fullPath = "${dir.path}/${contract.split("/").last}";
    await Dio().download(contract, fullPath);
    return fullPath;
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
