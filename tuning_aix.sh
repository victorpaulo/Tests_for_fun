#!/bin/bash
#
# Simple script bash to configure tuning parameter before installing 
# IBM WebSphere products.
# Please check if your AIX version has these parameters since I tested on AIX 5.3, 6.1 and 7.1, something might changed;
#

_NOW=$(date +"%Y-%m-%d-%H-%M-%S")

log "######## Iniciando Tuning do AIX ##############"

if [ "$OS" = "AIX" ]; then
	log "no -p -o tcp_sendspace=131072"
	no -p -o tcp_sendspace=131072
	log "no -p -o tcp_recvspace=131072"
	no -p -o tcp_recvspace=131072
	log "no -p -o udp_sendspace=655360"
	no -p -o udp_sendspace=655360
	log "no -p -o udp_recvspace=655360"
	no -p -o udp_recvspace=655360
	log "no -p -o somaxconn=10000"
	no -p -o somaxconn=10000
	log "no -p -o tcp_nodelayack=1"
	no -p -o tcp_nodelayack=1
	log "no -p -o rfc1323=1"
	no -p -o rfc1323=1
	log "no -p -o fasttimo=50"
	no -p -o fasttimo=50
	log "no -p -o tcp_finwait2=120"
	no -p -o tcp_finwait2=120
	log "no -p -o tcp_keepinit=10"
	no -p -o tcp_keepinit=10
	log "no -p -o tcp_timewait=1"
	no -p -o tcp_timewait=1
	log "no -p -o tcp_keepidle=600"
	no -p -o tcp_keepidle=600
	log "no -p -o tcp_keepintvl=10"
	no -p -o tcp_keepintvl=10
	log "no -p -o tcptr_enable=0"
	no -p -o tcptr_enable=0
	log "dscrctl -n -b -s 1"
	dscrctl -n -b -s 1
	log "vmo -p -o minperm%=3"
	vmo -p -o minperm%=3
	log "vmo -p -o maxperm%=90"
	vmo -p -o maxperm%=90

	log "Definindo ulimit e parametros AIXTHREAD no nivel de sessao do usuario."
	ulimit -d unlimited
	ulimit -s unlimited
	ulimit -m unlimited
	ulimit -n unlimited
	export AIXTHREAD_SCOPE=S
	export AIXTHREAD_MUTEX_DEBUG=OFF
	export AIXTHERAD_COND_DEBUG=OFF
	export AIXTHREAD_RWLOCK_DEBUG=OFF
	export SPINLOOPTIME=500

	log "Realizando o backup do arquivo /etc/security/limits."

	cp /etc/security/limits /etc/security/limits${_NOW}.bkp
	sleep 2
	echo "############################################" > /etc/security/limits
	echo "## Parametros ulimit definidos para o BPM ##" >> /etc/security/limits
	echo "default:" >> /etc/security/limits
	echo "        fsize = 2097151" >> /etc/security/limits
	echo "        core = 2097151" >> /etc/security/limits
	echo "        cpu = -1" >> /etc/security/limits
	echo "        data = 262144" >> /etc/security/limits
	echo "        rss = 65536" >> /etc/security/limits
	echo "        stack = 65536" >> /etc/security/limits
	echo "        nofiles = 2000" >> /etc/security/limits
	echo ""  >> /etc/security/limits
	echo "root:" >> /etc/security/limits
	echo "        fsize = -1" >> /etc/security/limits
	echo "        core = -1" >> /etc/security/limits
	echo "        data = -1" >> /etc/security/limits
	echo "        stack = -1" >> /etc/security/limits
	echo "        nofiles = -1" >> /etc/security/limits
    echo "############################################"  >> /etc/security/limits
	
	log "Realizando o backup do arquivo /etc/environment."
	cp /etc/environment /etc/environment${_NOW}.bkp
	sleep 2	
	echo "##########################################" >> /etc/environment
	echo "#### Parametros definidos para o BPM ####" >> /etc/environment
	log "Definindo parametro [AIXTHREAD_SCOPE=S]"
	echo "AIXTHREAD_SCOPE=S" >> /etc/environment
	log "Definindo parametro [AIXTHREAD_MUTEX_DEBUG=OFF]"
	echo "AIXTHREAD_MUTEX_DEBUG=OFF" >> /etc/environment
	log "Definindo parametro [AIXTHERAD_COND_DEBUG=OFF]"
	echo "AIXTHERAD_COND_DEBUG=OFF" >> /etc/environment
	log "Definindo parametro [AIXTHREAD_RWLOCK_DEBUG=OFF]"
	echo "AIXTHREAD_RWLOCK_DEBUG=OFF" >> /etc/environment
	log "Definindo parametro [SPINLOOPTIME=500]"
	echo "SPINLOOPTIME=500" >> /etc/environment
	echo "##########################################"  >> /etc/environment 
	log "Tuning do AIX finalizado com sucesso!!"
else
	log "Tuning nao realizado pois o Sistema Operacional[${OS}] nao e' AIX"
fi