part of 'creation_campagne_cubit.dart';

class CreationCampagneState {
  final AppStatus? fetchStatus;
  final AppStatus? estimationStatus;
  final AppStatus? testStatus;
  final AppStatus? saveStatus;

  final List<Map<String, String>>? segments;
  final List<Realestate>? biens;
  final List<Client>? clients;
  final SegmentClients segment;
  final EstimationSegment? estimation;
  final File? image;
  final String? error;

  CreationCampagneState({
    this.fetchStatus,
    this.estimationStatus,
    this.testStatus,
    this.saveStatus,
    this.segments,
    this.biens,
    this.clients,
    SegmentClients? segment,
    this.estimation,
    this.image,
    this.error,
  }) : segment = segment ?? SegmentClients();

  CreationCampagneState copyWith({
    AppStatus? fetchStatus,
    AppStatus? estimationStatus,
    AppStatus? testStatus,
    AppStatus? saveStatus,
    List<Map<String, String>>? segments,
    List<Realestate>? biens,
    List<Client>? clients,
    SegmentClients? segment,
    EstimationSegment? estimation,
    File? image,
    bool effacerImage = false,
    String? error,
  }) {
    return CreationCampagneState(
      fetchStatus: fetchStatus ?? this.fetchStatus,
      // Les statuts d'action declenchent un message : ils ne se conservent pas.
      estimationStatus: estimationStatus,
      testStatus: testStatus,
      saveStatus: saveStatus,
      segments: segments ?? this.segments,
      biens: biens ?? this.biens,
      clients: clients ?? this.clients,
      segment: segment ?? this.segment,
      estimation: estimation ?? this.estimation,
      image: effacerImage ? null : (image ?? this.image),
      error: error,
    );
  }
}
