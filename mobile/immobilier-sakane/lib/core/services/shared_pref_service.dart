
import 'package:shared_preferences/shared_preferences.dart';



class SharedPrefService{

  static const String username='username';
  static const String password='password';
  static const String token='token';





  late SharedPreferences _pref;

  SharedPrefService(this._pref);

  static Future<SharedPrefService> initializeService()async{
    SharedPreferences pref=await SharedPreferences.getInstance();
    return SharedPrefService(pref);
  }

  void putValue(String key,value){
    switch(value.runtimeType){
      case int:
        _pref.setInt(key, value);
        break;
      case bool:
        _pref.setBool(key, value);
        break;
      case String:
        _pref.setString(key,value);
        break;
      case double:
        _pref.setDouble(key, value);
        break;
      default:
        throw Exception('unHandled type');
    }

  }


  T getValue<T>(String key,T defVal){
     return ((_pref.get(key) ?? defVal) as T);
  }

  bool contains(String key){
    return _pref.containsKey(key);
  }

  void removeRecord(String key){
    if(contains(key)){
      _pref.remove(key);
    }
  }


}
