#!/usr/bin/env bash
#
# After Ansible is installed, download playbooks from Ansible Galaxy, an online
# repository of Ansible roles that users created (https://galaxy.ansible.com).
#
# All arguments on the command line are assumed to be ansible-galaxy roles.
# These should be passed from packer. This script must be run after
# bootstrap.sh.
#
# This script retries up to 5 times in case of HTTP timeout.
#
count=0
while [ $count -le 5 ]
do
    ansible-galaxy install \
        ansiblebit.oracle-java \
        ansiblebit.launchpad-ppa-webupd8 \
        Datadog.datadog \
        franklinkim.environment \
        geerlingguy.apache \
        geerlingguy.nodejs \
        geerlingguy.ntp \
        hswong3i.webmin

    if [ $? -eq 0 ]
    then
        break
    else
        sleep 10
    fi

    ((count++))
done
