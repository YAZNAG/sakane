import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:immobilier/components/error_widget.dart';
import 'package:immobilier/components/loading_widget.dart';
import 'package:immobilier/core/constants/app_strings.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/features/auth/initialiser/cubit/initialiser_cubit.dart';




class InitiliserPage extends StatefulWidget {
  InitiliserPage({Key? key}) : super(key: key);

  static Widget page()=>BlocProvider(
      create: (context)=>InitialiserCubit(),
    child: InitiliserPage(),
  );

  @override
  State<InitiliserPage> createState() => _InitiliserPageState();
}

class _InitiliserPageState extends State<InitiliserPage> {

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    fetchData();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<InitialiserCubit,InitialiserState>(
      listener: listener,
      builder:(context, state )=>Scaffold(
        body: Center(
          child: _buildContent(state)
        ),
      ) ,
    );
  }

  void listener(BuildContext context, state) {

  }

  Widget? _buildContent(InitialiserState state) {
    if(state.fetchStatus==AppStatus.loading){
      return LoadingWidget();
    }else if(state.fetchStatus==AppStatus.error){
      return MyErrorWidget(error: state.error??"Error", action: AppStrings.tryAgain,actionCLick: fetchData,);
    }
  }



  void fetchData() {
    BlocProvider.of<InitialiserCubit>(context).fetchData();
  }
}
