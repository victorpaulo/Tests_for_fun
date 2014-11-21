#!/bin/bash

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

#variables
WAS_DIR=/opt/IBM/BPM/v80
profileName=
cellName=
nodeName=
hostName=
serverName=
user=
pass=

function menu(){ 
	clear
	echo -e "==========================="
	echo -e "Choose an option:"
	echo -e "==========================="
	echo -e " 0: Show WebSphere cell configuration"
	echo -e " 1: List profiles"
	echo -e " 2: Create profile Dmgr"
	echo -e " 3: Create profile Custom"
	echo -e " 4: Create profile Standalone"
	echo -e " 5: Remove profile"
	echo -e " 6: Start Dmgr"
	echo -e " 7: Stop Dmgr"
	echo -e " 8: Start Node Agent"
	echo -e " 9: Stop Node Agent"
	echo -e "10: Start Server"
	echo -e "11: Stop Server"
	echo -e "12: Define custom properties of Webcontainer"
	echo -e "13: Define custom properties of JVM"
	echo -e "14: Define heap size of JVM"
	echo -e "15: Define log properties of JVM"
	echo -e "x: Exit"
}

function menuProfile() {
   clear
   echo -e "Inform profile name:"
   read profileName
   echo -e "Inform cell name:"
   read cellName
   echo -e "Inform node name:"
   read nodeName
   echo -e "Inform server name:"
   read serverName   
   echo -e "Inform hostname/IP:"
   read hostName   
   echo -e "Inform username:"
   read user
   echo -e "Inform password:"
   read pass
   
   
}
function createDmgr() {
	clear
	menuProfile
	echo -e "[profileName=$profileName;cellName=$cellName;nodeName=$nodeName;hostname=$hostName;serverName=$serverName;userName=$user]"
	$WAS_DIR/bin/manageprofiles.sh \
	-create \
	-profileName $profileName \
	-profilePath $WAS_DIR/profiles/$profileName \
	-templatePath $WAS_DIR/profileTemplates/management \
	-serverType DEPLOYMENT_MANAGER  \
	-cellName $cellName \
	-nodeName $nodeName \
	-hostName $hostName \
	-enableAdminSecurity true \
	-adminUserName $user \
	-adminPassword $pass \
	-personalCertValidityPeriod 15 \
	-signingCertValidityPeriod 15
	echo press enter to return to menu; 
	read DUMMY ; 
}

function createCustom() {
	clear
	menuProfile
	echo -e "Inform hostname/IP of dmgr host:"
	read dmgrHost
	echo -e "Inform SOAP port of dmgr host:"
	read dmgrPort
	echo -e "[profileName=$profileName;cellName=$cellName;nodeName=$nodeName;hostname=$hostName; \
				serverName=$serverName;dmgrHost=$dmgrHost;dmgrPort=$dmgrPort;userName=$user]"
	$WAS_DIR/bin/manageprofiles.sh \
	-create \
	-profileName $profileName \
	-profilePath $WAS_DIR/profiles/$profileName \
	-templatePath $WAS_DIR/profileTemplates/managed \
	-nodeName $nodeName \
	-hostName $hostName \
	-dmgrHost $dmgrHost \
	-dmgrPort $dmgrPort \
	-dmgrAdminUserName $user \
	-dmgrAdminPassword $pass
	echo press enter to return to menu; 
	read DUMMY ; 
}

function createStandAlone() {
	clear
	menuProfile
	echo -e "[profileName=$profileName;cellName=$cellName;nodeName=$nodeName;hostname=$hostName;serverName=$serverName;userName=$user]"
	$WAS_DIR/bin/manageprofiles.sh \
	-create \
	-profileName $profileName \
	-profilePath $WAS_DIR/profiles/$profileName \
	-templatePath $WAS_DIR/profileTemplates/default \
	-cellName $cellName \
	-nodeName $nodeName \
	-hostName $hostName \
	-serverName $serverName \
	-enableAdminSecurity true \
	-adminUserName $user \
	-adminPassword $pass
	echo pressione enter para retornar ao menu
	read DUMMY
}

function removeProfile() {
	clear
	echo -e "Inform profile name:"
	read profileName
	echo -e "deleting..."
	$WAS_DIR/bin/manageprofiles.sh -delete -profileName $profileName
	#rm -rf $WAS_DIR/profiles/$profileName
	echo press enter to return to menu
	read DUMMY
}

function startDmgr() {
	clear
	echo -e "Inform profile name:"
        read profileName
	$WAS_DIR/bin/startManager.sh -profileName $profileName
	echo press enter to return to menu
	read DUMMY
}

function stopDmgr() {
	clear
	echo -e "Inform profile name:"
        read profileName
	#echo -e "Informe o usuario:"
        #read user
        #echo -e "Informe a senha:"
        #read pass
	#$WAS_DIR/profiles/$profileName/bin/stopManager.sh -username $user -password $pass
	$WAS_DIR/bin/stopManager.sh -profileName $profileName
	echo press enter to return to menu
	read DUMMY
}

function startNodeAgent() {
	clear
	echo -e "Inform profile name:"
        read profileName
	$WAS_DIR/bin/startNode.sh -profileName $profileName
	echo press enter to return to menu
	read DUMMY
}

function stopNodeAgent() {
	clear
	echo -e "Inform profile name:"
        read profileName
	#echo -e "Informe o usuario:"
        #read user
        #echo -e "Informe a senha:"
        #read pass
	#$WAS_DIR/profiles/$profileName/bin/stopNode.sh -username $user -password $pass
	$WAS_DIR/bin/stopNode.sh -profileName $profileName
	echo press enter to return to menu
	read DUMMY
}

function startServer() {
	clear
	echo -e "Inform profile name:"
        read profileName
	echo -e "Inform server name:"
        read serverName
	$WAS_DIR/bin/startServer.sh $serverName -profileName $profileName
	echo press enter to return to menu
	read DUMMY
}

function stopServer() {
	clear
	echo -e "Inform profile name:"
        read profileName
	echo -e "Inform server name:"
        read serverName
	#echo -e "Informe o usuario:"
    	#read user
    	#echo -e "Informe a senha:"
    	#read pass
	#$WAS_DIR/profiles/$profileName/bin/stopServer.sh $serverName -username $user -password $pass
	$WAS_DIR/bin/stopServer.sh $serverName -profileName $profileName
	echo press enter to return to menu
	read DUMMY
}

function listProfiles() {
	clear
	echo -e "Listing profiles:"
	$WAS_DIR/bin/manageprofiles.sh -listProfiles
	echo press enter to return to menu
	read DUMMY
}

function definePropertiesJVM() {
   clear
   echo -e "Inform cell name:"
   read cellName
   echo -e "Inform node name:"
   read nodeName
   echo -e "Inform server name:"
   read serverName   
   #echo -e "Inform username:"
   #read user
   #echo -e "Inform password:"
   #read pass
   cont=1
   while [ $cont -eq 1 ]
   do 
		echo -e "Inform custom property name:"
		read propName
		echo -e "Inform property value:"
		read propValue
		> /tmp/scriptJVM.txt
		echo "set server [\$AdminConfig getid /Cell:$cellName/Node:$nodeName/Server:$serverName/]" >> /tmp/scriptJVM.txt
		echo "set jvmId [ \$AdminConfig list JavaVirtualMachine \$server ]" >> /tmp/scriptJVM.txt
		echo "set attr [subst {{name $propName} {value $propValue} }] "  >> /tmp/scriptJVM.txt
		echo "\$AdminConfig create Property \$jvmId \$attr " >> /tmp/scriptJVM.txt
		echo "\$AdminConfig save" >> /tmp/scriptJVM.txt
		#$WAS_DIR/bin/wsadmin.sh -username $user -password $pass -lang jacl -f /tmp/scriptJVM.txt
		$WAS_DIR/bin/wsadmin.sh -lang jacl -f /tmp/scriptJVM.txt
		rm -rf /tmp/scriptJVM.txt
		echo -e "Type 1 to input more properties or type enter to return to menu"
		read cont
   done
}

function definePropertiesWebcontainer() {
   clear
   echo -e "Inform cell name:"
   read cellName
   echo -e "Inform node name:"
   read nodeName
   echo -e "Inform server name:"
   read serverName   
   #echo -e "Inform username:"
   #read user
   #echo -e "Inform password:"
   #read pass
   cont=1
   while [ $cont -eq 1 ]
   do 
		echo -e "Inform custom property name:"
		read propName
		echo -e "Inform property value:"
		read propValue
		> /tmp/scriptWC.txt
		echo "set server [\$AdminConfig getid /Cell:$cellName/Node:$nodeName/Server:$serverName/]" >> /tmp/scriptWC.txt
		echo "set webcontainerId [\$AdminConfig list WebContainer \$server]" >> /tmp/scriptWC.txt
		echo "set attr [subst {{name $propName} {value $propValue} }] "  >> /tmp/scriptWC.txt
		echo "\$AdminConfig create Property \$webcontainerId \$attr " >> /tmp/scriptWC.txt
		echo "\$AdminConfig save" >> /tmp/scriptWC.txt
		#$WAS_DIR/bin/wsadmin.sh -username $user -password $pass -lang jacl -f /tmp/scriptWC.txt
		$WAS_DIR/bin/wsadmin.sh -username -lang jacl -f /tmp/scriptWC.txt
		echo -e "Type 1 to input more properties or type enter to return to menu"
		read cont
   done
   rm -rf /tmp/scriptWC.txt
}

function defineHeapSizeJVM() {
   clear
   echo -e "Inform cell name:"
   read cellName
   echo -e "Inform node name:"
   read nodeName
   echo -e "Inform server name:"
   read serverName   
   echo -e "Inform minimum value of heap(MB):"
   read minHeapSize 
   echo -e "Inform maximum value of heap(MB):"
   read maxHeapSize 
   #echo -e "Inform username:"
   #read user
   #echo -e "Inform password:"
   #read pass
   	> /tmp/scriptSizeJVM.txt
	echo "set server [\$AdminConfig getid /Cell:$cellName/Node:$nodeName/Server:$serverName/]" >> /tmp/scriptSizeJVM.txt
	echo "set jvmId [ \$AdminConfig list JavaVirtualMachine \$server ]" >> /tmp/scriptSizeJVM.txt
	echo "set initialHeapSize1 [ list initialHeapSize $minHeapSize ]" >> /tmp/scriptSizeJVM.txt
	echo "set maximumHeapSize1 [ list maximumHeapSize $maxHeapSize ]" >> /tmp/scriptSizeJVM.txt
	echo "set attr [ list \$initialHeapSize1 \$maximumHeapSize1 ]" >> /tmp/scriptSizeJVM.txt
	echo "\$AdminConfig modify \$jvmId \$attr " >> /tmp/scriptSizeJVM.txt
	echo "\$AdminConfig save" >> /tmp/scriptSizeJVM.txt
	#$WAS_DIR/bin/wsadmin.sh -username $user -password $pass -lang jacl -f /tmp/scriptSizeJVM.txt
	$WAS_DIR/bin/wsadmin.sh -lang jacl -f /tmp/scriptSizeJVM.txt
	rm -rf /tmp/scriptSizeJVM.txt
	echo press enter to return to menu
	read DUMMY
}

function definePropertiesLog() {
    	clear
	echo -e "== Rotation log of SystemOut and SystemErr files(time 24horas) =="
	echo -e "Inform cell name:"
	read cellName
	echo -e "Inform node name:"
	read nodeName
	echo -e "Inform server name:"
	read serverName   
	echo -e "Inform the log path  (without / at the end)"
	read pathLog
	echo -e "Inform the number of historical log files:"
	read numLogFilesBackup	

	> /tmp/scriptLogWAS.txt
	echo "set server [\$AdminConfig getid /Cell:$cellName/Node:$nodeName/Server:$serverName/]" >> /tmp/scriptLogWAS.txt
	echo "set pathLogServer \"$pathLog/$serverName\"" >> /tmp/scriptLogWAS.txt
	echo "set sysOut	\"\$pathLogServer/SystemOut.log\"" >> /tmp/scriptLogWAS.txt
	echo "set sysErr    \"\$pathLogServer/SystemErr.log\"" >> /tmp/scriptLogWAS.txt

	#Definindo SystemOut		
	echo "set outputLogId [ \$AdminConfig showAttribute \$server outputStreamRedirect ]" >> /tmp/scriptLogWAS.txt
	echo "set maxNumberOfBackupFiles [ list maxNumberOfBackupFiles $numLogFilesBackup ]" >> /tmp/scriptLogWAS.txt
	echo "set rolloverType   [ list rolloverType          TIME ]" >> /tmp/scriptLogWAS.txt
	echo "set baseHour 	     [ list baseHour 1 ]" >> /tmp/scriptLogWAS.txt
	echo "set rolloverPeriod [ list rolloverPeriod 24 ]" >> /tmp/scriptLogWAS.txt
	echo "set fileName 		 [ list fileName \$sysOut ]" >> /tmp/scriptLogWAS.txt
	echo "set attrList     [ list \$maxNumberOfBackupFiles \$rolloverType \$baseHour \$rolloverPeriod \$fileName ]" >> /tmp/scriptLogWAS.txt
	echo "\$AdminConfig modify \$outputLogId \$attrList" >> /tmp/scriptLogWAS.txt

	#Definindo SystemErr				
	echo "set errorLogId	 [ \$AdminConfig showAttribute \$server errorStreamRedirect ]" >> /tmp/scriptLogWAS.txt
	echo "set fileName       [ list fileName \$sysErr ]" >> /tmp/scriptLogWAS.txt
	echo "set attrList       [ list \$maxNumberOfBackupFiles \$rolloverType \$baseHour \$rolloverPeriod \$fileName ]" >> /tmp/scriptLogWAS.txt
	echo "\$AdminConfig modify \$errorLogId \$attrList" >> /tmp/scriptLogWAS.txt
	echo "\$AdminConfig save" >> /tmp/scriptLogWAS.txt
	$WAS_DIR/bin/wsadmin.sh -lang jacl -f /tmp/scriptLogWAS.txt
	rm -rf /tmp/scriptLogWAS.txt
	echo press enter to return to menu
	read DUMMY
}

function showCell() {
	clear
	echo -e "========================================"
	echo -e "Showing WebSphere cell structure"
	echo -e "========================================"
	>/tmp/scriptShowCell.txt
	echo "set cells [\$AdminConfig list Cell]" >> /tmp/scriptShowCell.txt
	echo "foreach cell \$cells {" >> /tmp/scriptShowCell.txt
	echo "	set cname [\$AdminConfig showAttribute \$cell name]" >> /tmp/scriptShowCell.txt
	echo "	set nodes [\$AdminConfig list Node \$cell]" >> /tmp/scriptShowCell.txt
	echo "	foreach node \$nodes {" >> /tmp/scriptShowCell.txt
	echo "		set nname [\$AdminConfig showAttribute \$node name]" >> /tmp/scriptShowCell.txt
	echo "		set servs [\$AdminConfig list Server \$node]" >> /tmp/scriptShowCell.txt
	echo "		foreach server \$servs {" >> /tmp/scriptShowCell.txt
	echo "			set sname [\$AdminConfig showAttribute \$server name]" >> /tmp/scriptShowCell.txt
	echo " 			puts \"CellName=\$cname; NodeName=\$nname; ServerName=\$sname\"" >> /tmp/scriptShowCell.txt
	echo "		}" >> /tmp/scriptShowCell.txt
	echo "	}" >> /tmp/scriptShowCell.txt
	echo "}" >> /tmp/scriptShowCell.txt
	$WAS_DIR/bin/wsadmin.sh -lang jacl -f /tmp/scriptShowCell.txt
	rm -rf /tmp/scriptShowCell.txt
	echo press enter to return to menu
	read DUMMY
}

while true
do
	menu
	read answer
	case $answer in
		0)  showCell;;
		1)  listProfiles;;
		2)  createDmgr;;
		3)  createCustom;;
		4)  createStandAlone;;
		5)  removeProfile;;
		6)  startDmgr;;
		7)  stopDmgr;;
		8)  startNodeAgent;;
		9)  stopNodeAgent;;
		10) startServer;;
		11) stopServer;;
		12) definePropertiesWebcontainer;;
		13) definePropertiesJVM;;
		14) defineHeapSizeJVM;;
		15) definePropertiesLog;;
		x) break;;
		*)  echo "Please, choose the correct option";;
	esac
done
exit 0;

