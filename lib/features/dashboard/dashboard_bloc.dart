import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/app_logger.dart';
import 'system_info.dart'; import 'system_repository.dart';
sealed class DashboardEvent extends Equatable { const DashboardEvent(); @override List<Object?> get props=>[]; }
final class DashboardRefreshRequested extends DashboardEvent { const DashboardRefreshRequested(); }
enum DashboardStatus { initial, loading, success, failure }
class DashboardState extends Equatable {
 const DashboardState({this.status=DashboardStatus.initial,this.info,this.error}); final DashboardStatus status; final SystemInfo? info; final String? error;
 DashboardState copyWith({DashboardStatus? status,SystemInfo? info,String? error,bool clear=false})=>DashboardState(status:status??this.status,info:info??this.info,error:clear?null:error??this.error);
 @override List<Object?> get props=>[status,info,error];
}
class DashboardBloc extends Bloc<DashboardEvent,DashboardState>{ DashboardBloc(this.repo):super(const DashboardState()){on<DashboardRefreshRequested>(_refresh);} final SystemRepository repo;
 Future<void> _refresh(DashboardRefreshRequested e,Emitter<DashboardState> emit)async{emit(state.copyWith(status:DashboardStatus.loading,clear:true));try{emit(state.copyWith(status:DashboardStatus.success,info:await repo.load()));}catch(e,s){AppLogger.error('Refresh failed',e,s);emit(state.copyWith(status:DashboardStatus.failure,error:'Unable to read system information: $e'));}}
}
