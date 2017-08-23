#!/bin/bash

USERNAME=wasadmin
WAS_HOME=/opt/IBM/WebSphere/AppServer
TMP_FILE=/tmp/script_rename.py
CELLNAME=$(hostname)Cell01
NODENAME=$(hostname)CellNode

read -s -p "Informe a senha wasadmin: `echo $'\n> '`" PASSWORD
echo ""
read -s -p "Repita a senha wasadmin: `echo $'\n> '`" PASSWORD2

if [ "x${PASSWORD}x" != "x${PASSWORD2}x" ]; then
	echo "ERRO: As senhas informadas nao sao identicas."
	exit 99
fi

echo "Verificando processo Dmgr..."
DMGR_PROCESS=`ps -A -o pid,cmd|grep dmgr | grep -v grep |head -n 1 | awk '{print $1}'`
if [[ ! -z $DMGR_PROCESS ]]; then
    echo "Parando o Dmgr"
	$WAS_HOME/profiles/Dmgr01/bin/stopManager.sh -username $USERNAME -password $PASSWORD 
	echo "Dmgr parado"
fi

echo "AdminTask.renameCell('[-newCellName $CELLNAME -regenCerts true -nodeName DmgrNode01 -hostName $(hostname) -changeSetupCmdBat true]')" > $TMP_FILE
echo "AdminConfig.save()" >> $TMP_FILE

echo "AdminTask.renameNode('[-nodeName DmgrNode01 -newNodeName $NODENAME]')" >> $TMP_FILE
echo "AdminConfig.save()" >> $TMP_FILE

echo "Executando o comando wsadmin..."
$WAS_HOME/wsadmin.sh -lang jython -conntype NONE -username $USERNAME -password $PASSWORD -f $TMP_FILE 
echo "Comando wsadmin finalizado"

sed -i -e 's/WAS_CELL=Cell01/WAS_CELL=$CELLNAME/g; s/WAS_NODE=DmgrNode01/WAS_NODE=$NODENAME/g' $WAS_HOME/profiles/Dmgr01/bin/setupCmdLine.sh

IS_OK=$?

if [ $IS_OK -eq 0 ]; then 
	echo "Iniciando o Dmgr"
	$WAS_HOME/profiles/Dmgr01/bin/startManager.sh
else
	echo "Ops!! Algo deu errado, verifique os erros e execute novamente"
	exit 99
fi

echo "Rode o comando syncNode.sh nos nodes do WAS e teste o ambiente"
