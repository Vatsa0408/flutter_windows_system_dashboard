import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/app_logger.dart';
import 'system_metrics.dart';import 'system_monitor_repository.dart';
sealed class SystemMonitorEvent extends Equatable{const SystemMonitorEvent();@override List<Object?>get props=>[];}
final class SystemMonitorStarted extends SystemMonitorEvent{const SystemMonitorStarted();}
final class SystemMonitorStopped extends SystemMonitorEvent{const SystemMonitorStopped();}
final class SystemMonitorTicked extends SystemMonitorEvent{const SystemMonitorTicked();}
enum SystemMonitorStatus{initial,loading,active,paused,failure}
class SystemMonitorState extends Equatable{const SystemMonitorState({this.status=SystemMonitorStatus.initial,this.metrics,this.error});final SystemMonitorStatus status;final SystemMetrics?metrics;final String?error;SystemMonitorState copyWith({SystemMonitorStatus?status,SystemMetrics?metrics,String?error,bool clear=false})=>SystemMonitorState(status:status??this.status,metrics:metrics??this.metrics,error:clear?null:error??this.error);@override List<Object?>get props=>[status,metrics,error];}
class SystemMonitorBloc extends Bloc<SystemMonitorEvent,SystemMonitorState>{SystemMonitorBloc(this.repo):super(const SystemMonitorState()){on<SystemMonitorStarted>(_start);on<SystemMonitorStopped>(_stop);on<SystemMonitorTicked>(_tick);}final SystemMonitorRepository repo;Timer?timer;bool busy=false;void _start(SystemMonitorStarted e,Emitter<SystemMonitorState>emit){timer?.cancel();emit(state.copyWith(status:SystemMonitorStatus.loading,clear:true));add(const SystemMonitorTicked());timer=Timer.periodic(const Duration(seconds:2),(_)=>add(const SystemMonitorTicked()));}void _stop(SystemMonitorStopped e,Emitter<SystemMonitorState>emit){timer?.cancel();timer=null;emit(state.copyWith(status:SystemMonitorStatus.paused));}Future<void>_tick(SystemMonitorTicked e,Emitter<SystemMonitorState>emit)async{if(busy||timer==null)return;busy=true;try{emit(state.copyWith(status:SystemMonitorStatus.active,metrics:await repo.read(),clear:true));}catch(x,s){AppLogger.error('Monitoring failed',x,s);emit(state.copyWith(status:SystemMonitorStatus.failure,error:'Monitoring failed: $x'));}finally{busy=false;}}@override Future<void>close(){timer?.cancel();return super.close();}}
