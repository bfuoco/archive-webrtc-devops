#!/usr/bin/env bash
#
# Bootstraps an Ubuntu instance by installing Ansible, a configuration
# management tool (https://ansible.com).
#
# The script executes in a loop and will retry 5 times. This is to account for
# HTTP timeouts, which often occur when trying to download the GPG key for
# Ansible's ppa repository.
#
count=0
while [ $count -le 5 ]
do
    apt-get install software-properties-common -y
    apt-add-repository ppa:ansible/ansible
    apt-get update -y
    apt-get install ansible curl -y

    if [ $? -eq 0 ]
    then
        break
    else
        sleep 10
    fi

    ((count++))
done
