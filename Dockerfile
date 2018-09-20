FROM centos:centos7
MAINTAINER Francisco José Páez Gordillo <frapaego@gmail.com>

# install some necessary/desired RPMs and get updates
RUN yum update -y
RUN yum install -y epel-release
RUN yum install -y \
    fontconfig \
    libSM \
    libICE \
    libXrender \
    libXext \
    cups-libs \
    libGLU \
    supervisor \
    wget
RUN yum clean all

COPY assets/install_alfresco.sh /tmp/install_alfresco.sh
RUN chmod +x /tmp/install_alfresco.sh
RUN /tmp/install_alfresco.sh

COPY assets/install_mysql_connector.sh /tmp/
RUN chmod +x /tmp/install_mysql_connector.sh
RUN /tmp/install_mysql_connector.sh

RUN mkdir -p /alfresco/tomcat/shared/classes/alfresco/extension/subsystems/Authentication/ldap/ldap1/
RUN mkdir -p /alfresco/tomcat/shared/classes/alfresco/extension/subsystems/Authentication/ldap-ad/ldap1/
COPY assets/ldap-authentication.properties /alfresco/tomcat/shared/classes/alfresco/extension/subsystems/Authentication/ldap/ldap1/ldap-authentication.properties
COPY assets/ldap-ad-authentication.properties /alfresco/tomcat/shared/classes/alfresco/extension/subsystems/Authentication/ldap-ad/ldap1/ldap-ad-authentication.properties

COPY assets/init.sh /alfresco/init.sh
RUN chmod +x /alfresco/init.sh
#COPY assets/supervisord.conf /etc/supervisord.conf

RUN mkdir -p /alfresco/tomcat/webapps/ROOT
COPY assets/index.jsp /alfresco/tomcat/webapps/ROOT/

ADD assets/entrypoint /assets/entrypoint

ENV DB_KIND mysql
ENV DB_USERNAME alfresco
ENV DB_PASSWORD admin
ENV DB_NAME alfresco
ENV DB_HOST localhost
ENV CONTENT_STORE /content
ENV ALFRESCO_ADMIN_PASSWORD admin

RUN chmod +x /assets/entrypoint

VOLUME /alfresco/tomcat/logs
VOLUME /content

EXPOSE 21 137 138 139 445 7070 8009 8080
ENTRYPOINT ["/assets/entrypoint"]
