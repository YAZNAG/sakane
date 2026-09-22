


class ServerException implements Exception{
  String msg;

  ServerException(this.msg);

  @override
  String toString() {
    return msg;
  }
}