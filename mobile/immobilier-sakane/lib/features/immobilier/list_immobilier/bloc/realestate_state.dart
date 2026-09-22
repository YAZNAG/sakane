part of 'realestate_cubit.dart';




 class RealestateState {

   AppStatus? fetchStatus;
   AppStatus? deleteStatus;
   int? deletingId;
   String? error;
   List<Realestate>? realestates;

   RealestateState({
     this.fetchStatus,
     this.deleteStatus,
     this.deletingId,
     this.error,
     this.realestates,
   });

   RealestateState copyWith({
     AppStatus? fetchStatus,
     AppStatus? deleteStatus,
     int? deletingId,
     String? error,
     List<Realestate>? realestates,
   }) {
     return RealestateState(
       fetchStatus: fetchStatus ?? this.fetchStatus,
       deleteStatus: deleteStatus,
       deletingId: deletingId ?? this.deletingId,
       error: error,
       realestates: realestates ?? this.realestates,
     );
   }

 }

