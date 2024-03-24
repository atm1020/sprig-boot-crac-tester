#!/bin/bash

if ! [ -x "$(command -v docker)" ]; then
  echo 'Error: docker is not installed.' >&2
  exit 1
fi

IS_MAVEN_PROJECT=$(ls -1 | grep "pom.xml" | wc -l)
IS_GRADLE_PROJECT=$(ls -1 | grep "build.gradle" | wc -l)
if ! [ $IS_GRADLE_PROJECT -eq 1 ] && ! [ $IS_MAVEN_PROJECT -eq 1 ]; then 
	echo "Please init in a valid project directory with a build tool (Maven or Gradle)." >&2
	exit 1
fi

wget https://raw.githubusercontent.com/atm1020/sprig-boot-crac-tester/init/crac.sh
chmod +x crac.sh

echo "Select an operation by number:"
echo "1) checkpoint"
echo "2) checkpointOnRefresh"
echo "3) restore"
