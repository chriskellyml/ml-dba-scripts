###############################################################
#
#   Copyright (c) 2021 MarkLogic Corporation
#
###############################################################
FROM centos:centos7

###############################################################
# set build args
###############################################################
ARG ML_RPM="artefacts/marklogic.rpm"
ARG ML_START_SCRIPT="artefacts/start-marklogic.sh"
ARG ML_USER="marklogic_user"
ARG ML_GROUP="root"
ARG ML_VERSION=10-internal
ARG TZ="Europe/Amsterdam"

###############################################################
# define docker labels
###############################################################
LABEL "Maintainer"="docker@marklogic.com"
LABEL "Name"="MarkLogic Server ${ML_VERSION}"
LABEL "Version"="1.0.0"
LABEL "com.marklogic"="MarkLogic"
LABEL "com.marklogic.release-type"="production"
LABEL "com.marklogic.release-version"="${ML_VERSION}"
LABEL "com.marklogic.license"="MarkLogic EULA"
LABEL "com.marklogic.license.description"="By subscribing to this product, you agree to the terms and conditions outlined in MarkLogic's End User License Agreement (EULA) here https://developer.marklogic.com/eula "
LABEL "com.marklogic.license.url"="https://developer.marklogic.com/eula"
LABEL "com.marklogic.version"="${ML_VERSION}"
LABEL "com.marklogic.description"="MarkLogic is the only Enterprise NoSQL database. It is a new generation database built with a flexible data model to store, manage, and search JSON, XML, RDF, and more - without sacrificing enterprise features such as ACID transactions, certified security, and backup and recovery. With these capabilities, MarkLogic is ideally suited for making heterogeneous data integration simpler and faster and for doing dynamic content delivery at massive scale. MarkLogic Developer redhat image includes all features but is limited to pre-production applications and use."
LABEL docker.cmd="docker run -it -p 7997-8010:7997-8010 -e MARKLOGIC_INIT=true -e MARKLOGIC_ADMIN_USERNAME=<INSERT USERNAME> -e MARKLOGIC_ADMIN_PASSWORD=<INSERT PASSWORD> -v ~/data:/var/opt/MarkLogic marklogicdb/marklogic-server-centos:${ML_VERSION}"

###############################################################
# define env for TimeZone
###############################################################

ENV TZ=$TZ

###############################################################
# install networking, base deps and ntp/tzdata for timezone
###############################################################

RUN yum -y update \
    && yum -y install gdb.x86_64 glibc.i686 initscripts redhat-lsb-core.x86_64 tzdata libhugetlbfs-utils \
    && yum clean all

###############################################################
# inject init, start and clustering scripts
###############################################################

COPY ${ML_START_SCRIPT} /usr/local/bin/start-marklogic.sh

###############################################################
# install MarkLogic server
###############################################################
COPY ${ML_RPM} /tmp/marklogic-server.rpm
RUN yum localinstall -y /tmp/marklogic-server.rpm \
    && rm /tmp/marklogic-server.rpm \
    && yum -y clean all \
    && rm -rf ./opt/MarkLogic/mlcmd/lib/* \
    && rm -rf ./opt/MarkLogic/mlcmd/ext/*

###############################################################
# Copy converters package
###############################################################
#COPY ${ML_CONVERTERS} ./converters.rpm

###############################################################
# create system user
###############################################################

RUN adduser --gid users --uid 1000 ${ML_USER}
# RUN useradd -l --uid 1000740000 -G users ${ML_USER} \

###############################################################
# set marklogic.conf authorisation
###############################################################

RUN touch /etc/marklogic.conf \
    && chown ${ML_USER} /etc/marklogic.conf \
    && chmod 644 /etc/marklogic.conf

RUN chmod +x /usr/local/bin/start-marklogic.sh
RUN chown ${ML_USER} /usr/local/bin/start-marklogic.sh

###############################################################
# Add TINI to serve as PID 1 process
###############################################################
ENV TINI_VERSION v0.19.0
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /tini
RUN chown ${ML_USER} /tini \
    && chmod +x /tini

###############################################################
# set env vars
###############################################################

ENV MARKLOGIC_INSTALL_DIR=/opt/MarkLogic  \
    MARKLOGIC_DATA_DIR=/var/opt/MarkLogic \
    MARKLOGIC_USER=${ML_USER} \
    MARKLOGIC_PID_FILE=/home/${ML_USER}/MarkLogic.pid  \
    MARKLOGIC_UMASK=022 \
    LD_LIBRARY_PATH=/lib64:$LD_LIBRARY_PATH:/opt/MarkLogic/lib \
    MARKLOGIC_VERSION="${ML_VERSION}" \
    MARKLOGIC_BOOTSTRAP_HOST=bootstrap \
    MARKLOGIC_ADMIN_USERNAME_FILE=mldb_admin_user \
    MARKLOGIC_ADMIN_PASSWORD_FILE=mldb_password_user \
    MARKLOGIC_WALLET_PASSWORD_FILE=mldb_wallet_password \
    TZ=:/etc/localtime

################################################################
# Set appropriate authorisation to MARKLOGIC_DATA_DIR
################################################################

# FIXME: Correct permission requires a in-depth review of the
#        MarkLogic & SP rules and technical limitations.
RUN mkdir -p ${MARKLOGIC_DATA_DIR} \
    && chown -R ${ML_USER} ${MARKLOGIC_DATA_DIR}

###############################################################
# expose MarkLogic server ports
###############################################################

EXPOSE 25 7997-8010 8040-8043

###############################################################
# set system user
###############################################################

USER ${ML_USER}

###############################################################
# ulimit settings
###############################################################

RUN ulimit -Hu

###############################################################
# define volume for persistent MarkLogic server data
###############################################################

VOLUME /var/opt/MarkLogic
RUN chown ${ML_USER} ${MARKLOGIC_DATA_DIR} \
    && chown -R ${ML_USER} ${MARKLOGIC_DATA_DIR}

###############################################################
# set entrypoint
###############################################################
ENTRYPOINT ["/tini", "--"]
CMD ["/usr/local/bin/start-marklogic.sh"]
