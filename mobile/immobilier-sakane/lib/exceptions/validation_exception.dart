

class ValidatorException implements Exception{
  Map<String,dynamic>? errors;

  ValidatorException(this.errors);

  @override
  String toString() {
    return "$errors";
  }
}