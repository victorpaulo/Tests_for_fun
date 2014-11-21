#!/bin/bash

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

# This script is intended to be used or adapted to WebSphere Products. In this case I tested for IBM BPM products topology...
#
# 1 - This script must be execututed on Deployment Manager (DMgr);
# 2 - The user who will execute this script must be in sudoer root users group;
# 3 - The script variables should be changed to reflect your environment;
#
# usage: 
#	scriptServicoBPM.sh -start 
# or 
#	scriptServicoBPM.sh -stop 
#
# Don't use it without the correct test it may not work in some environments. I've tested on AIX 7.1 and Linux Redhat.

usage () {
	echo ""
	echo " Usage :" 
	echo "       scriptServicoBPM.sh <start|stop>"
	echo ""
	exit 1
}

#Function to cleaning the temporary files for WebSphere.
clearTmp() {
	#Cleaning temporary files older than 1 day..
	sudo -u root find /opt/IBM/BPM/profiles/${type_server}Dmgr01/wstemp/* -depth -mtime +1 -exec rm -rf {} \;
	sudo -u root find /opt/IBM/BPM/profiles/${type_server}Dmgr01/temp/* -depth -mtime +1 -exec rm -rf {} \;
	
	#Cleaning temporary files for Node/profile 01 older than 1 day..
	expectCmd "ssh -o StrictHostKeyChecking=no $userOS@$IP_Node01" $passwordUser "sudo -u root find /opt/IBM/BPM/profiles/${type_server}Node01/wstemp/* -depth -mtime +1 -exec rm -rf {} \;"
	expectCmd "ssh -o StrictHostKeyChecking=no $userOS@$IP_Node01" $passwordUser "sudo -u root find /opt/IBM/BPM/profiles/${type_server}Node01/temp/* -depth -mtime +1 -exec rm -rf {} \;"

	#Cleaning temporary files for Node/profile 02 older than 1 day..
	expectCmd "ssh -o StrictHostKeyChecking=no $userOS@$IP_Node02" $passwordUser "sudo -u root find /opt/IBM/BPM/profiles/${type_server}Node02/wstemp/* -depth -mtime +1 -exec rm -rf {} \;"
	expectCmd "ssh -o StrictHostKeyChecking=no $userOS@$IP_Node02" $passwordUser "sudo -u root find /opt/IBM/BPM/profiles/${type_server}Node02/temp/* -depth -mtime +1 -exec rm -rf {} \;"
	
}

#Function to start WebSphere processes remotely.
startCmd() {
	local _PYTHON_FILE=/tmp/startCluster.py
	echo "#########################################"
	echo "####    Starting DMGR    #########"
	sudo -u root /opt/IBM/BPM/profiles/${type_server}Dmgr01/bin/startManager.sh
	
	echo "#########################################"
	echo "####    Starting NODE 01    ######"
	expectCmd "ssh -o StrictHostKeyChecking=no $userOS@$IP_Node01" $passwordUser "sudo -u root /opt/IBM/BPM/profiles/${type_server}Node01/bin/startNode.sh"
	sleep 5
	
	echo "#########################################"
	echo "####   Starting NODE 02    ######"
	expectCmd "ssh -o StrictHostKeyChecking=no $userOS@$IP_Node02" $passwordUser "sudo -u root /opt/IBM/BPM/profiles/${type_server}Node02/bin/startNode.sh"
	sleep 30
	
	echo "import time" > $_PYTHON_FILE
	echo "cellName=AdminControl.getCell()" >> $_PYTHON_FILE
	echo "clusterMsg = AdminControl.completeObjectName('cell='+cellName+',type=Cluster,name=Messaging,*')" >> $_PYTHON_FILE
	echo "if (AdminControl.getAttribute(clusterMsg, \"state\") == \"websphere.cluster.stopped\"):" >> $_PYTHON_FILE
	echo "	AdminControl.invoke(clusterMsg, 'start')" >> $_PYTHON_FILE
	echo "	time.sleep(180)" >> $_PYTHON_FILE
	echo "clusterSup = AdminControl.completeObjectName('cell='+cellName+',type=Cluster,name=Support,*')" >> $_PYTHON_FILE
	echo "if (AdminControl.getAttribute(clusterSup, \"state\") == \"websphere.cluster.stopped\"):" >> $_PYTHON_FILE
	echo "	AdminControl.invoke(clusterSup, 'start')" >> $_PYTHON_FILE
	echo "	time.sleep(180)" >> $_PYTHON_FILE
	echo "clusterApp = AdminControl.completeObjectName('cell='+cellName+',type=Cluster,name=Application,*')" >> $_PYTHON_FILE
	echo "if (AdminControl.getAttribute(clusterApp, \"state\") == \"websphere.cluster.stopped\"):" >> $_PYTHON_FILE
	echo "	AdminControl.invoke(clusterApp, 'start')" >> $_PYTHON_FILE
	echo "	time.sleep(300)" >> $_PYTHON_FILE
	echo "clusterWeb = AdminControl.completeObjectName('cell='+cellName+',type=Cluster,name=Web,*')" >> $_PYTHON_FILE
	echo "if (AdminControl.getAttribute(clusterWeb, \"state\") == \"websphere.cluster.stopped\"):" >> $_PYTHON_FILE
	echo "	AdminControl.invoke(clusterWeb, 'start')" >> $_PYTHON_FILE
	
	echo "#########################################"
	echo "####   Starting CLUSTERS  ######"
	expectCmd "sudo -u root /opt/IBM/BPM/profiles/${type_server}Dmgr01/bin/wsadmin.sh -lang jython -f $_PYTHON_FILE" "$passwordWsadmin" ""
	
	echo "#########################################"
	echo "#####  Starting HTTP SERVER    #######"
	expectCmd "ssh -o StrictHostKeyChecking=no $userOS@$IP_IHS_01" $passwordUser "sudo -u root /opt/IBM/HTTPServer/bin/apachectl start"
	
	echo "######### END START ####################"
	sudo -u root rm -rf $_PYTHON_FILE
}

#Function to stop WebSphere processes remotely.
stopCmd() {
	local _PYTHON_FILE=/tmp/stopCluster.py

	echo "#########################################"
	echo "######   Stopping HTTP SERVER    ########"
	expectCmd "ssh $userOS@$IP_IHS_01" $passwordUser "sudo -u root /opt/IBM/HTTPServer/bin/apachectl stop"
	
	echo "cellName=AdminControl.getCell()" > $_PYTHON_FILE
	echo "clusterWeb = AdminControl.completeObjectName('cell='+cellName+',type=Cluster,name=Web,*')" >> $_PYTHON_FILE
	echo "if (AdminControl.getAttribute(clusterWeb, \"state\") == \"websphere.cluster.running\"):" >> $_PYTHON_FILE
	echo "	AdminControl.invoke(clusterWeb, 'stop')" >> $_PYTHON_FILE
	echo "clusterApp = AdminControl.completeObjectName('cell='+cellName+',type=Cluster,name=Application,*')" >> $_PYTHON_FILE
	echo "if (AdminControl.getAttribute(clusterApp, \"state\") == \"websphere.cluster.running\"):" >> $_PYTHON_FILE
	echo "	AdminControl.invoke(clusterApp, 'stop')" >> $_PYTHON_FILE
	echo "clusterSup = AdminControl.completeObjectName('cell='+cellName+',type=Cluster,name=Support,*')" >> $_PYTHON_FILE
	echo "if (AdminControl.getAttribute(clusterSup, \"state\") == \"websphere.cluster.running\"):" >> $_PYTHON_FILE
	echo "	AdminControl.invoke(clusterSup, 'stop')" >> $_PYTHON_FILE
	echo "clusterMsg = AdminControl.completeObjectName('cell='+cellName+',type=Cluster,name=Messaging,*')" >> $_PYTHON_FILE
	echo "if (AdminControl.getAttribute(clusterMsg, \"state\") == \"websphere.cluster.running\"):" >> $_PYTHON_FILE
	echo "	AdminControl.invoke(clusterMsg, 'stop')" >> $_PYTHON_FILE
	
	echo "########################################"
	echo "###   Stopping CLUSTERS        ####"
	expectCmd "sudo -u root /opt/IBM/BPM/profiles/${type_server}Dmgr01/bin/wsadmin.sh -lang jython -f $_PYTHON_FILE" "$passwordWsadmin" ""
	sleep 60

	echo "#########################################"
	echo "###  Stopping NODE 01        ######"
	expectCmd "ssh -o StrictHostKeyChecking=no $userOS@$IP_Node01" $passwordUser "sudo -u root /opt/IBM/BPM/profiles/${type_server}Node01/bin/stopNode.sh"
	sleep 5
	
	echo "#########################################"
	echo "###  Stopping NODE 02        ######"
	expectCmd "ssh -o StrictHostKeyChecking=no $userOS@$IP_Node02" $passwordUser "sudo -u root /opt/IBM/BPM/profiles/${type_server}Node02/bin/stopNode.sh"
	sleep 5
	
	echo "#########################################"
	echo "###   Stopping DMGR           ####"
	expectCmd "sudo -u root /opt/IBM/BPM/profiles/${type_server}Dmgr01/bin/stopManager.sh"  "$passwordWsadmin" ""
	
	echo "######### FIM STOP ####################"
	sudo -u root rm -rf $_PYTHON_FILE
}

#Function to read credentials of websphere administrator.
readCredentials() {
	local passchk01=""
	local passchk02=""
	
	userOS=$(whoami)
	
	read -s -p "Inform user password $userOS: " passwordUser
	read -s -p "Retype the password: " passchk01
	echo -e ""
	if [ "$passwordUser" == "$passchk01" ]; then
        read -s -p "Inform password to WSADMIN: " passwordWsadmin
		read -s -p "Retype the password: " passchk02
		echo -e ""
		if [ ! "$passwordWsadmin" == "$passchk02" ]; then
			echo -e "Password for WSADMIN is wrong."
			exit 1
		fi
	else
		echo -e "User OS Password [$userOS] do not match."
		exit 1
    fi
}

#
#Function to input parameters automagically when prompted (e.g: ssh)
expectCmd() {
	#echo $1
	#echo $2
	#echo $3
	VAR=$(expect -c "
		set pid [ spawn -noecho $1 $3 ]
		set timeout 3600
		expect {
			\"(yes/no)\" {
				sleep 1
				send \"yes\r\"
				exp_continue
			}
			\"(y/n)\" {
				sleep 1
				send \"y\r\"
				exp_continue
			}
			password {
				sleep 1
				send \"$2\r\"
				exp_continue
			}
			\"Username:\" {
				sleep 1
				send \"wsadmin\r\"
				exp_continue
			}
			\"Password:\" {
				sleep 1
				send \"$passwordWsadmin\r\"
				exp_continue
			}
			\"Last login\" {
				interact
			}
			\"Permission denied\" {
				puts \"Access not granted, aborting...\"
				exit 1
			}
			timeout {
				puts \"Timeout expired, aborting...\"
				exit 1
			}
			eof {
				#puts \"EOF reached.\"
			}
		}
	")
	echo "$VAR"
}

##########  Some variables  #################################################
IP_Node01=10.0.1.1
IP_Node02=10.0.1.2
IP_IHS_01=10.0.1.3
passwordUser=
passwordWsadmin=
type_server="PS" # Enter "PC" for IBM Process Center; "PS" for IBM Process Server

#######################################################################
###### PROGRAM START/STOP ################################
if [ $# -eq 0 ]; then
     usage
fi
if [ "$1" == "start" ]; then
	readCredentials
    startCmd
elif [ "$1" == "stop" ]; then
	readCredentials
    stopCmd
	#clearTmp
else
    usage
fi
#########################################################################
