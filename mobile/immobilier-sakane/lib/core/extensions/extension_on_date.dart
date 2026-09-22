


import 'package:intl/intl.dart';

extension extension_on_data on DateTime{

  String get formattedDateTime{
    DateFormat dateFormat=DateFormat("yyyy-MM-dd HH:mm:ss");
    return dateFormat.format(this);
  }

  String get formattedDateTimeFr{
    DateFormat dateFormat=DateFormat("dd/MM/yyyy HH:mm");
    return dateFormat.format(this);
  }

  String get formattedDateEn{
    DateFormat dateFormat=DateFormat("yyyy-MM-dd");
    return dateFormat.format(this);
  }

  String get formattedDateFr{
    DateFormat dateFormat=DateFormat("dd/MM/yyyy");
    return dateFormat.format(this);
  }

  String get formattedTime{
    DateFormat dateFormat=DateFormat("HH:mm");
    return dateFormat.format(this);
  }


  DateTime get justDate{
    return  DateTime(year,month,day);
  }




}