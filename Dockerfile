FROM ubuntu:22.04

ARG CRAC_JDK_URL
ARG ARTIFACT_ID
ARG VERSION

ENV ARTIFACT_ID=${ARTIFACT_ID}
ENV VERSION=${VERSION}
ENV ARTIFACT_NAME=${ARTIFACT_ID}-${VERSION}
ENV JAVA_HOME /opt/jdk
ENV PATH $JAVA_HOME/bin:$PATH
ENV CRAC_FILES_DIR /opt/crac-files

ADD $CRAC_JDK_URL $JAVA_HOME/openjdk.tar.gz
RUN tar --extract --file $JAVA_HOME/openjdk.tar.gz --directory "$JAVA_HOME" --strip-components 1; rm $JAVA_HOME/openjdk.tar.gz;
RUN apt-get update && apt-get install -y wget

RUN mkdir -p /opt/app

RUN wget https://raw.githubusercontent.com/atm1020/sprig-boot-crac-tester/init/entrypoint.sh 
RUN mv entrypoint.sh /opt/app/entrypoint.sh
RUN chmod +x /opt/app/entrypoint.sh

COPY target/$ARTIFACT_NAME.jar /opt/app/$ARTIFACT_NAME.jar

ENTRYPOINT /opt/app/entrypoint.sh
