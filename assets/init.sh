#!/bin/bash

ALF_HOME=/alfresco
ALF_BIN=$ALF_HOME/bin
ALF_SETUP=$ALF_HOME/setup
CATALINA_HOME=$ALF_HOME/tomcat

ALFRESCO_HOSTNAME=${ALFRESCO_HOSTNAME:-127.0.0.1}
ALFRESCO_PROTOCOL=${ALFRESCO_PROTOCOL:-http}
if [ "${ALFRESCO_PROTOCOL,,}" = "https" ]; then
  ALFRESCO_PORT=${ALFRESCO_PORT:-8443}
else
  ALFRESCO_PORT=${ALFRESCO_PORT:-8080}
fi

SHARE_HOSTNAME=${SHARE_HOSTNAME:-127.0.0.1}
SHARE_PROTOCOL=${SHARE_PROTOCOL:-http}
if [ "${SHARE_PROTOCOL,,}" = "https" ]; then
  SHARE_PORT=${SHARE_PORT:-8443}
else
  SHARE_PORT=${SHARE_PORT:-8080}
fi

case "${DB_KIND,,}" in
  postgresql)
    DB_DRIVER=org.postgresql.Driver
    DB_PORT=${DB_PORT:-5432}
    ;;
  mysql)
    DB_DRIVER=org.gjt.mm.mysql.Driver
    DB_PORT=${DB_PORT:-3306}
    DB_CONN_PARAMS=${DB_CONN_PARAMS:-?useUnicode=yes\\&characterEncoding=UTF-8\\&useSSL=false}
    ;;
  *)
    echo "Database kind '$DB_KIND' not supported!"
    exit 1
esac

SYSTEM_SERVERMODE=${SYSTEM_SERVERMODE:-PRODUCTION}

MAIL_SMTP_HOST=${MAIL_SMTP_HOST:-localhost}
MAIL_SMTP_PORT=${MAIL_SMTP_PORT:-25}
MAIL_SMTP_USERNAME=${MAIL_SMTP_USERNAME:-mail}
MAIL_SMTP_PASSWORD=${MAIL_SMTP_PASSWORD:-mail}
MAIL_FROM=${MAIL_FROM:-alfresco@alfresco.org}
MAIL_PROTOCOL=${MAIL_PROTOCOL:-smtp}
MAIL_SMTP_AUTH=${MAIL_SMTP_AUTH:-false}
MAIL_SMTP_STARTTLS=${MAIL_SMTP_STARTTLS:-false}
MAIL_SMTPS_AUTH=${MAIL_SMTPS_AUTH:-false}
MAIL_SMTPS_STARTTLS=${MAIL_SMTPS_STARTTLS:-false}

FTP_PORT=${FTP_PORT:-21}

CIFS_ENABLED=${CIFS_ENABLED:-true}
CIFS_SERVER_NAME=${CIFS_SERVER_NAME:-localhost}
CIFS_DOMAIN=${CIFS_DOMAIN:-WORKGROUP}

NFS_ENABLED=${NFS_ENABLED:-false}

LDAP_ENABLED=${LDAP_ENABLED:-false}
LDAP_KIND=${LDAP_KIND:-ldap}
LDAP_AUTH_USERNAMEFORMAT=${LDAP_AUTH_USERNAMEFORMAT:-uid=%s,cn=users,cn=accounts,dc=example,dc=com}
LDAP_URL=${LDAP_URL:-ldap://ldap.example.com:389}
LDAP_DEFAULT_ADMINS=${LDAP_DEFAULT_ADMINS:-admin}
LDAP_SECURITY_PRINCIPAL=${LDAP_SECURITY_PRINCIPAL:-uid=admin,cn=users,cn=accounts,dc=example,dc=com}
LDAP_SECURITY_CREDENTIALS=${LDAP_SECURITY_CREDENTIALS:-password}
LDAP_GROUP_SEARCHBASE=${LDAP_GROUP_SEARCHBASE:-cn=groups,cn=accounts,dc=example,dc=com}
LDAP_USER_SEARCHBASE=${LDAP_USER_SEARCHBASE:-cn=users,cn=accounts,dc=example,dc=com}

CONTENT_STORE=${CONTENT_STORE:-\$\{dir.root\}}

function cfg_replace_option {
  grep "$1" "$3" > /dev/null
  if [ $? -eq 0 ]; then
    # replace option
    echo "replacing option  $1=$2  in  $3"
        sed -i "s#^\($1\s*=\s*\).*\$#\1$2#" $3
    if (( $? )); then
      echo "cfg_replace_option failed"
      exit 1
    fi
  else
    # add option if it does not exist
    echo "adding option  $1=$2  in  $3"
    echo "$1=$2" >> $3
  fi
}

function tweak_alfresco {
  ALFRESCO_GLOBAL_PROPERTIES=$CATALINA_HOME/shared/classes/alfresco-global.properties
  DB_URL=jdbc:$DB_KIND://$DB_HOST:$DB_PORT/$DB_NAME$DB_CONN_PARAMS
  echo -e "\n### Settings added by init script" >> $ALFRESCO_GLOBAL_PROPERTIES
  cfg_replace_option alfresco.host $ALFRESCO_HOSTNAME $ALFRESCO_GLOBAL_PROPERTIES
  cfg_replace_option share.host $SHARE_HOSTNAME $ALFRESCO_GLOBAL_PROPERTIES

  #db.schema.update=true
  cfg_replace_option db.driver $DB_DRIVER $ALFRESCO_GLOBAL_PROPERTIES
  cfg_replace_option db.username $DB_USERNAME $ALFRESCO_GLOBAL_PROPERTIES
  cfg_replace_option db.password $DB_PASSWORD $ALFRESCO_GLOBAL_PROPERTIES
  cfg_replace_option db.name $DB_NAME $ALFRESCO_GLOBAL_PROPERTIES
  cfg_replace_option db.url $DB_URL $ALFRESCO_GLOBAL_PROPERTIES

  cfg_replace_option ftp.port $FTP_PORT $ALFRESCO_GLOBAL_PROPERTIES

  # @see https://forums.alfresco.com/en/viewtopic.php?f=8&t=20893
  # CIFS works, but you have to login as a native Alfresco account, like admin
  # because CIFS does not work with LDAP authentication
  cfg_replace_option cifs.enabled $CIFS_ENABLED $ALFRESCO_GLOBAL_PROPERTIES
  cfg_replace_option cifs.Server.Name $CIFS_SERVER_NAME $ALFRESCO_GLOBAL_PROPERTIES
  cfg_replace_option cifs.domain $CIFS_DOMAIN $ALFRESCO_GLOBAL_PROPERTIES
  cfg_replace_option cifs.hostannounce "true" $ALFRESCO_GLOBAL_PROPERTIES
  cfg_replace_option cifs.broadcast "0.0.0.255" $ALFRESCO_GLOBAL_PROPERTIES
  cfg_replace_option cifs.ipv6.enabled "false" $ALFRESCO_GLOBAL_PROPERTIES

  cfg_replace_option nfs.enabled $NFS_ENABLED $ALFRESCO_GLOBAL_PROPERTIES

  # authentication
  if [ "$LDAP_ENABLED" == "true" ]; then
    cfg_replace_option authentication.chain "alfrescoNtlm1:alfrescoNtlm,ldap1:${LDAP_KIND}" $ALFRESCO_GLOBAL_PROPERTIES

    # now make substitutions in the LDAP config file
    LDAP_CONFIG_FILE=$CATALINA_HOME/shared/classes/alfresco/extension/subsystems/Authentication/${LDAP_KIND}/ldap1/${LDAP_KIND}-authentication.properties

    cfg_replace_option ldap.authentication.userNameFormat $LDAP_AUTH_USERNAMEFORMAT $LDAP_CONFIG_FILE
    cfg_replace_option ldap.authentication.java.naming.provider.url $LDAP_URL $LDAP_CONFIG_FILE
    cfg_replace_option ldap.authentication.defaultAdministratorUserNames $LDAP_DEFAULT_ADMINS $LDAP_CONFIG_FILE
    cfg_replace_option ldap.synchronization.java.naming.security.principal $LDAP_SECURITY_PRINCIPAL $LDAP_CONFIG_FILE
    cfg_replace_option ldap.synchronization.java.naming.security.credentials $LDAP_SECURITY_CREDENTIALS $LDAP_CONFIG_FILE
    cfg_replace_option ldap.synchronization.groupSearchBase $LDAP_GROUP_SEARCHBASE $LDAP_CONFIG_FILE
    cfg_replace_option ldap.synchronization.userSearchBase $LDAP_USER_SEARCHBASE $LDAP_CONFIG_FILE
  else
    cfg_replace_option authentication.chain "alfrescoNtlm1:alfrescoNtlm" $ALFRESCO_GLOBAL_PROPERTIES
  fi

  # content store
  cfg_replace_option dir.contentstore "${CONTENT_STORE}/contentstore" $ALFRESCO_GLOBAL_PROPERTIES
  cfg_replace_option dir.contentstore.deleted "${CONTENT_STORE}/contentstore.deleted" $ALFRESCO_GLOBAL_PROPERTIES
}

tweak_alfresco

if [ -d "$AMP_DIR_ALFRESCO" ]; then
  echo "Installing Alfresco AMPs from $AMP_DIR_ALFRESCO..."
  $ALF_HOME/java/bin/java -jar $ALF_HOME/bin/alfresco-mmt.jar install $AMP_DIR_ALFRESCO $CATALINA_HOME/webapps/alfresco.war -directory -force -verbose
  $ALF_HOME/java/bin/java -jar $ALF_HOME/bin/alfresco-mmt.jar list $CATALINA_HOME/webapps/alfresco.war
fi

if [ -d "$AMP_DIR_SHARE" ]; then
  echo "Installing Share AMPs from $AMP_DIR_SHARE..."
  $ALF_HOME/java/bin/java -jar $ALF_HOME/bin/alfresco-mmt.jar install $AMP_DIR_SHARE $CATALINA_HOME/webapps/share.war -directory -force -verbose
  $ALF_HOME/java/bin/java -jar $ALF_HOME/bin/alfresco-mmt.jar list $CATALINA_HOME/webapps/share.war
fi

# setup environment
source $ALF_HOME/scripts/setenv.sh

# start internal postgres server only if the host is localhost
if [ "${DB_KIND,,}" == "postgresql" ] && [ "$DB_HOST" == "localhost" ]; then
  $ALF_HOME/postgresql/scripts/ctl.sh start
fi

# start Tomcat
$ALF_HOME/tomcat/scripts/ctl.sh start
