#!/bin/bash
ARTIFACT_NAME=`eval echo ${ARTIFACT_NAME}`
CRAC_FILES_DIR=`eval echo ${CRAC_FILES_DIR}`
mkdir -p $CRAC_FILES_DIR

if [ -z "$(ls -A $CRAC_FILES_DIR)" ]; then
  if [ "$FLAG" = "-r" ]; then
    echo 128 > /proc/sys/kernel/ns_last_pid; \
	    java -Dspring.context.checkpoint=onRefresh \
	    -Dmanagement.endpoint.health.probes.add-additional-paths="true" \
	    -Dmanagement.health.probes.enabled="true" \
	    -XX:CRaCCheckpointTo=$CRAC_FILES_DIR -jar \
	    /opt/app/$ARTIFACT_NAME.jar
  else
    echo 128 > /proc/sys/kernel/ns_last_pid; \
	    java -Dmanagement.endpoint.health.probes.add-additional-paths="true" \
	    -Dmanagement.health.probes.enabled="true" \
	    -XX:CRaCCheckpointTo=$CRAC_FILES_DIR -jar \
	    /opt/app/$ARTIFACT_NAME.jar&
    sleep 5
    jcmd /opt/app/$ARTIFACT_NAME.jar JDK.checkpoint
  fi
  sleep infinity
else
  java -Dmanagement.endpoint.health.probes.add-additional-paths="true" -Dmanagement.health.probes.enabled="true" -XX:CRaCRestoreFrom=$CRAC_FILES_DIR&
  PID=$!
  trap "kill $PID" SIGINT SIGTERM
  wait $PID
fi
