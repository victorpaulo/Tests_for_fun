#!/bin/bash

remote_server=$1
username="root"

echo "Generating local ssh keys if needed"

if [ -f "/root/.ssh/id_rsa" ] ; then
    echo "Local ssh keys already exist"
else
    mkdir -p "/root/.ssh"
    ssh-keygen -t rsa -N "" -f "/root/.ssh/id_rsa"
fi

cat ~/.ssh/id_dsa.pub | ssh ${username}@${remote_server} "mkdir -p ~/.ssh && touch ~/.ssh/authorized_keys && cat - >> ~/.ssh/authorized_keys"
 
exit 0
