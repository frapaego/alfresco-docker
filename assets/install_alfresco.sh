#!/bin/bash
set -e

# vars
ALF_HOME=/alfresco
ALF_BIN=alfresco-community-3.4.d-installer-linux-x64.bin
ALF_URL=ftp://192.168.0.10:2021/alfresco_3.4d/$ALF_BIN

DB_USERNAME=${DB_USERNAME:-alfresco}
DB_PASSWORD=${DB_PASSWORD:-secret}
DB_NAME=${DB_NAME:-alfresco}
ALFRESCO_ADMIN_PASSWORD=${ALFRESCO_ADMIN_PASSWORD:-admin}

# get alfresco installer
mkdir -p $ALF_HOME
cd /tmp
curl -O $ALF_URL
chmod +x $ALF_BIN

# install alfresco
./$ALF_BIN --mode unattended --prefix $ALF_HOME --alfresco_admin_password $ALFRESCO_ADMIN_PASSWORD --mysql_password $DB_PASSWORD --mysql_database_name $DB_USERNAME --mysql_database_username $DB_USERNAME --mysql_database_password $DB_PASSWORD

# get rid of installer - makes image smaller
rm $ALF_BIN

# add alfresco user
#useradd alfresco
