#!/bin/bash

BPM_HOME="/opt/IBM/BPM"
USERNAME="wsadmin"
PASSWORD=
LOG_ROOT=
LOG_FILE="/tmp/maintenance$$.log"
PROFILE_HOME=

#record log to a file and print to a standard output
main.log() {
    echo $1
    echo "[$(date "+%d/%m/%Y %T")] $1" >> $LOG_FILE
}

#get password confirmation for wsadmin commands
main.get.user_password() {
	local _PASSWORD
	main.log "Informe a senha do wsadmin: "
	read -s PASSWORD
	main.log "Informe novamente a senha do wsadmin: "
	read -s _PASSWORD

	if [ "x${PASSWORD}x" != "x${_PASSWORD}x" ]; then
		main.log "ERRO :: Informe a senha correta do usuario wsadmin"
		main.log "Nao foi possivel prosseguir :( "
		unset PASSWORD
		exit 1
	fi
	unset _PASSWORD	
}

#check if user is root
main.check.rootuser() {
	if [ "$(id -u)" != "0" ]; then
	   main.log "ATENCAO :: Este script deve ser executado como root" 1>&2
	   exit 1
	fi
}

#discover profile of BPM which can be Dmgr, Node of Process Server or Process Center
main.discover.profile(){
	
	if [ ! -d $BPM_HOME ]; then
		main.log "ERROR: Esta maquina nao eh do BPM"
		exit 1
	fi

	cd $BPM_HOME/profiles/*
	PROFILE_HOME=$(pwd)
	cd - 2>&1 >/dev/null
	main.log "printing PROFILE_HOME=${PROFILE_HOME}"
		
}

#check where the log home was defined
main.discover.loghome(){
	
	main.discover.profile
	
	LOG_ROOT=`grep "LOG_ROOT" $PROFILE_HOME/config/cells/*/nodes/*Node01/variables.xml | awk -F"\"" '{print $6}'`
	
	if [ -z $LOG_ROOT ]; then
		LOG_ROOT="/var/log/was"
		main.log "WARNING: Nao foi possivel obter o LOG_ROOT, definindo padrao [${LOG_ROOT}]."
	fi
	
	main.log "printing LOG_ROOT=${LOG_ROOT}"
}


#remove heapdump, javacore and core files.
main.clean.dump_files() {

	main.discover.profile
	
	NR=`ls $PROFILE_HOME/heapdump* $PROFILE_HOME/javacore* $PROFILE_HOME/core* $PROFILE_HOME/Snap* 2>/dev/null | wc -l`
	
	if [ $NR -gt 0 ]; then
		rm -f $PROFILE_HOME/heapdump* $PROFILE_HOME/javacore* $PROFILE_HOME/core* $PROFILE_HOME/Snap* 2>/dev/null 
		main.log "Arquivos de dump excluidos com sucesso."
	else
		main.log "ATENCAO: Nao foram encontrados arquivos a serem excluidos."
		exit 1
	fi
	exit 0
}

#zip dump files
main.zip.dump_files() {
	local _DUMP_FILE="IBM_Dump_Files$(date '+%d%m%Y_%H%M%S').tar"
	
	main.discover.profile

	NR=`ls $PROFILE_HOME/heapdump* $PROFILE_HOME/javacore* $PROFILE_HOME/core* $PROFILE_HOME/Snap* 2>/dev/null | wc -l`
	
	if [ $NR -gt 0 ]; then
		tar cvf  ${_DUMP_FILE} $PROFILE_HOME/heapdump* $PROFILE_HOME/javacore* $PROFILE_HOME/core* $PROFILE_HOME/Snap* 2>/dev/null | gzip > /tmp/${_DUMP_FILE}.gz
		if [ -f /tmp/${_DUMP_FILE}.gz ]; then
			rm -f $PROFILE_HOME/$_DUMP_FILE 2>/dev/null
		fi
	else
		main.log "ATENCAO: Nao foram encontrados arquivos a serem arquivados."
		exit 1
	fi
	
	main.log "ATENCAO: Colete o arquivo /tmp/${_DUMP_FILE}.gz e envie para a IBM"
	exit 0
}

#collect javacore file for application cluster member
main.generate.javacore() {
	
	main.discover.loghome
	
	if [ -f $LOG_ROOT/App*/App*.pid ]; then
		PID=`cat $LOG_ROOT/App*/App*.pid`
		if [ ! -z $PID ]; then
			ps -p $PID >/dev/null
			if [ $? -eq 0 ]; then
				kill -3 $PID
				main.log "Java core gerado com sucesso. Favor consulte arquivo em: [${PROFILE_HOME}]."
			else
				main.log "ERROR: Processo de PID [${PID}] nao esta em execucao"
				exit 1
			fi
		else
			main.log "ERROR: Arquivo de PID vazio"
			exit 1
		fi 
	else
		main.log "ERROR: Este comando deve ser executado no Node."
		exit 1
	fi
	exit 0
}

#collect aixperf for PID of application member
main.collect.aixperf() {
	local _FILE_AIX_PERF="aixperf.sh"	
	main.discover.loghome
	
	if [ -f $LOG_ROOT/App*/App*.pid ]; then
		PID=`cat $LOG_ROOT/App*/App*.pid`
		if [ ! -z $PID ]; then
			ps -p $PID >/dev/null
			if [ $? -eq 0 ]; then
				if [ -f "${_FILE_AIX_PERF}" ] && [ -x "${_FILE_AIX_PERF}" ]; then
					main.log "Executando o [aixperf.sh $PID]."
					"`dirname ${0}`/${_FILE_AIX_PERF}" $PID | tee -a $LOG_FILE
				else
					main.log "ERROR: Arquivo [${_FILE_AIX_PERF}] nao localizado no diretorio corrente, ou "
					main.log "ERROR: Arquivo [${_FILE_AIX_PERF}] sem permissao de execucao."
					exit 1
				fi
			else
				main.log "ERROR: Processo de PID [${PID}] nao esta em execucao"
				exit 1
			fi
		else
			main.log "ERROR: Arquivo de PID vazio"
			exit 1
		fi 
	else
		main.log "ERROR: Por favor, voce deve rodar o aixperf no Node"
		exit 1
	fi
	main.log "ATENCAO: Envie o arquivo [aixperf_RESULTS.tar.gz], no diretorio corrente, para a IBM."
	main.log "ATENCAO: Rode a opcao [${0} 2] e o envie para a IBM tambem."
	exit 0
}

#run wait tool for BPM Application member
main.run.wait_tool() {
	local _FILE_WAIT="waitDataCollector.sh"
	
	main.discover.loghome
	
	if [ -f $LOG_ROOT/App*/App*.pid ]; then
		PID=`cat $LOG_ROOT/App*/App*.pid`
		if [ ! -z $PID ]; then
			ps -p $PID >/dev/null
			if [ $? -eq 0 ]; then
				if [ -f "${_FILE_WAIT}" -a -x "${_FILE_WAIT}" ]; then
					main.log "Executando o [${_FILE_WAIT} $PID]."
					"`dirname ${0}`/${_FILE_WAIT}" `cat $LOG_ROOT/App*/App*.pid` --iters 5 | tee -a $LOG_FILE
				else
					main.log "ERROR: Arquivo [${_FILE_WAIT}] nao localizado no diretorio corrente, ou "
					main.log "ERROR: Arquivo [${_FILE_WAIT}] sem permissao de execucao."
					exit 1
				fi
			else
				main.log "ERROR: Processo de PID [${PID}] nao esta em execucao"
				exit 1
			fi
		else
			main.log "ERROR: Arquivo de PID vazio"
			exit 1
		fi 
	else
		main.log "ERROR: Por favor, voce deve rodar o collect wait no Node"
		exit 1
	fi
	main.log "SUCESSO: Envie o arquivo [waitData.tar.gz], no diretorio corrente, para a IBM."
	exit 0
}


#restart the cluster name provided by parameter
main.restart.cluster() {
	local _PYTHON_FILE="/tmp/python$$"
	local declare -a _CLUSTERS_BPM=( ["1"]="Application", ["2"]="Support", ["3"]="Messaging", ["4"]="Web" )
	main.discover.profile
	main.get.user_password
	
	main.log "Informe o numero correspondente ao cluster que deseja parar: "
	main.log "[1-Application];[2-Support];[3-Messaging];[4-Web]"
	read OPCAO
	if [ $OPCAO -ne 1 -a $OPCAO -ne 2 -a $OPCAO -ne 3 -a $OPCAO -ne 4 ]; then
		main.log "ERROR: Opcao escolhida e invalida."
		exit 1
	fi
	local _CLUSTER_NAME=${_CLUSTERS_BPM["${OPCAO}"]}
	
	echo "import time" > $_PYTHON_FILE
	echo "cellName=AdminControl.getCell()" >> $_PYTHON_FILE
	echo "clusterObj = AdminControl.completeObjectName('cell='+cellName+',type=Cluster,name=${_CLUSTER_NAME},*')" >> $_PYTHON_FILE
	echo "if (AdminControl.getAttribute(clusterObj, \"state\") == \"websphere.cluster.running\"):" >> $_PYTHON_FILE
	echo "  print 'Parando o cluster [${_CLUSTER_NAME}]'" >> $_PYTHON_FILE
	echo "  AdminControl.invoke(clusterObj, 'stop')" >> $_PYTHON_FILE
	echo "while (AdminControl.getAttribute(clusterObj, \"state\") != \"websphere.cluster.stopped\"):" >> $_PYTHON_FILE
	#echo "  print 'Dormindo 30 segundos..'" >> $_PYTHON_FILE
	echo "  time.sleep(30)" >> $_PYTHON_FILE
	echo "print 'Iniciando o cluster [${_CLUSTER_NAME}]'" >> $_PYTHON_FILE
	echo "AdminControl.invoke(clusterObj, 'start')" >> $_PYTHON_FILE
	
	$PROFILE_HOME/bin/wsadmin.sh -lang jython -f $_PYTHON_FILE -user $USERNAME -password $PASSWORD  | tee -a $LOG_FILE
	
	if [ $? -eq 0 -a -f "$_PYTHON_FILE" ]; then
		rm -f $_PYTHON_FILE
	fi
	exit 0
}

main.sync.user_and_group() {
	
	main.discover.profile
	
	if [ -f ${PROFILE_HOME}/bin/setupCmdLine.sh -a -x ${PROFILE_HOME}/bin/setupCmdLine.sh ]; then
		main.log "Rodando o setupCmdLine.sh"
		. ${PROFILE_HOME}/bin/setupCmdLine.sh
	fi
	
	cd ${PROFILE_HOME}/bin/
	
	if [ -f ${PROFILE_HOME}/bin/usersFullSync.sh -a -x ${PROFILE_HOME}/bin/usersFullSync.sh ]; then
		main.log "Iniciando o sincronismo full de usuarios."
		${PROFILE_HOME}/bin/usersFullSync.sh -u operador -p restartBPM -host bpmnodeps01.domain.com.br -port 8880 | tee -a $LOG_FILE
		[ $? -ne 0 ] && exit 1 
	else 
		main.log "ERROR: Script [${PROFILE_HOME}/bin/usersFullSync.sh] nao encontrado ou sem permissao."
		exit 1
	fi
	
	if [ -f ${PROFILE_HOME}/bin/syncGroupMembershipForAllGroups.sh -a -x ${PROFILE_HOME}/bin/syncGroupMembershipForAllGroups.sh ]; then
		main.log "Iniciando o sincronismo full de grupos."
		${PROFILE_HOME}/bin/syncGroupMembershipForAllGroups.sh -u operador -p restartBPM -host bpmnodeps01.domain.com.br -port 8880 | tee -a $LOG_FILE
		[ $? -ne 0 ] && exit 1 
	else 
		main.log "ERROR: Script [${PROFILE_HOME}/bin/syncGroupMembershipForAllGroups.sh] nao encontrado ou sem permissao."
		exit 1
	fi
	cd - 2>&1 >/dev/null
	exit 0
}

main.usage() {
	echo "#####################################################################"
	echo "###############.......ESCOLHA A OPCAO.........#######################"
	echo "#...................................................................#"
	echo "#.Executar:..${0}...<opcao>.........................................#"
	echo "#...................................................................#"
	echo "#####################################################################"
	echo "#[1]-Limpar..arquivos..de..dump.....................................#"
	echo "#[2]-Arquivar..arquivos..de..dump...................................#"
	echo "#[3]-Criar..Thread..dump............................................#"
	echo "#[4]-Rodar..aixperf..script.........................................#"
	echo "#[5]-Rodar..WAIT..tool..............................................#"
	echo "#[6]-Reiniciar..Cluster..Application................................#"
	echo "#[7]-Sincronizar..usuarios..e.grupos................................#"
	echo "#[8]-Alterar..100Custom.xml.........................................#"
	echo "#[9]-Aplicar..Fixes.................................................#"
	echo "#####################################################################"	
}
if [ $# -ne 1 ]; then 
	main.usage
	exit 1
fi

option=$1

case $option in
	1)  main.clean.dump_files;;
	2)  main.zip.dump_files;;
	3)  main.generate.javacore;;
	4)  main.collect.aixperf;;
	5)  main.run.wait_tool;;
	6)  main.restart.cluster;;
	7)  main.sync.user_and_group;;
esac
exit 0;
