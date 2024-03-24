#!/bin/bash

ZULU_JDK_TAR_VERSION="17.44.55-ca-crac-jdk17.0.8.1"

logGreen() {
    echo -e "\033[32m$1\033[0m"
}

logYellow() {
    echo -e "\033[33m$1\033[0m"
}


choices() {
    echo "Select an operation by number:"
    echo "1. Checkpoint"
    echo "2. Checkpoint on Refresh"
    echo "3. Restore"
}


getEnvVars() {
    logGreen "Getting project variables..."
    IS_MAVEN_PROJECT=$(ls -1 | grep "pom.xml" | wc -l)
    IS_GRADLE_PROJECT=$(ls -1 | grep "build.gradle" | wc -l)
    if [ $IS_GRADLE_PROJECT -eq 1 ]; then
	ARTIFACT_ID=$(./gradlew properties -q | grep "archivesBaseName:" | awk '{print $2}')
	VERSION=$(./gradlew properties -q | grep "version:" | awk '{print $2}')
	BUILD_CMD="./gradlew build"
    elif [ $IS_MAVEN_PROJECT -eq 1 ]; then
	ARTIFACT_ID=$(./mvnw help:evaluate -Dexpression=project.artifactId -q -DforceStdout)
	VERSION=$(./mvnw help:evaluate -Dexpression=project.version -q -DforceStdout)
	BUILD_CMD="./mvnw clean package"
    else
	logYellow "Please provide a valid project directory with a build tool (Maven or Gradle)." >&2
	exit 1
    fi

    CONTAINER_NAME=$ARTIFACT_ID
    USER_NAME=$(whoami)
    IMAGE_NAME=$USER_NAME/$ARTIFACT_ID

   logGreen  "\n--- Get project variables ---"
   logGreen  "ARTIFACT_ID: $ARTIFACT_ID"
   logGreen  "VERSION: $VERSION"
   logGreen  "BUILD_CMD: $BUILD_CMD"
   logGreen  "CONTAINER_NAME: $CONTAINER_NAME"
   logGreen  "USER_NAME: $USER_NAME"
   logGreen  "IMAGE_NAME: $IMAGE_NAME"
   logGreen  "-----------------------------\n"
}

checkpoint() {
	getEnvVars
	FLAG=$1
	DOCKERFILE=Dockerfile.crac
	if [ -z "$FLAG" ]; then
		logGreen "--------------------------------------------------------"
		logGreen "On-demand checkpoint/restore of a running application"
		logGreen "--------------------------------------------------------\n"
	else
		logGreen "--------------------------------------------------------"
		logGreen "Automatic checkpoint/restore at startup"
		logGreen "--------------------------------------------------------\n"
	fi
	
	case $(uname -m) in
	    arm64)   url="https://cdn.azul.com/zulu/bin/zulu$ZULU_JDK_VERSION-linux_aarch64.tar.gz" ;;
	    *)       url="https://cdn.azul.com/zulu/bin/zulu$ZULU_JDK_VERSION-linux_x64.tar.gz" ;;
	esac

	if [ ! -f $DOCKERFILE ]; then
		logGreen "Downloading the Dockerfile..."
		wget -O $DOCKERFILE https://raw.githubusercontent.com/atm1020/sprig-boot-crac-tester/init/Dockerfile
		logGreen "Dockerfile downloaded successfully."
	fi

	logGreen "\nExecuting $BUILD_CMD..."
	/bin/bash $BUILD_CMD

	logGreen "Using CRaC enabled JDK $url"
	logGreen "Building the image $IMAGE_NAME:builder"

	docker build --no-cache -t $IMAGE_NAME:builder --build-arg CRAC_JDK_URL=$url  --build-arg ARTIFACT_ID=$ARTIFACT_ID --build-arg VERSION=$VERSION -f $DOCKERFILE .
 	docker run -d --privileged --rm --name=$CONTAINER_NAME --ulimit nofile=1024 -p 8080:8080 -v $(pwd)/target:/opt/mnt -e FLAG=$1 $IMAGE_NAME:builder
 	echo "Please wait during creating the checkpoint..."
 	sleep 10

 	logGreen "--- Container logs ---"
 	docker logs $CONTAINER_NAME
 	logGreen "----------------------"

 	logGreen "----- Crac files -----"
 	if [ $(docker exec -it $CONTAINER_NAME ls -1 /opt/crac-files | wc -l) -eq 0 ]; then
 	  logYellow "[WARNING] There are no crac files created."
 	else
 	  docker exec -it $CONTAINER_NAME ls /opt/crac-files
 	fi
 	logGreen "----------------------\n"

 	docker commit --change='ENTRYPOINT ["/opt/app/entrypoint.sh"]' $(docker ps -qf "name=$CONTAINER_NAME") $IMAGE_NAME:checkpoint
 	docker kill $(docker ps -qf "name=$CONTAINER_NAME ")
}

restore() {
	getEnvVars
	logGreen "Start restoring the application..."
	logGreen "Container name: $CONTAINER_NAME | Image name: $IMAGE_NAME:checkpoint"
	docker run --cap-add CHECKPOINT_RESTORE --cap-add SYS_ADMIN --rm -p 8080:8080 --name $CONTAINER_NAME $IMAGE_NAME:checkpoint
}

checkpointOnRefresh() {
	checkpoint -r
}

operation=$1
if [ -z "$operation" ]; then
    echo "Select an operation by number:"
    choices
    read -p "Enter the number: " choice
    case $choice in
	1) operation="checkpoint";;
	2) operation="checkpointOnRefresh";;
	3) operation="restore";;
	*) logYellow "Invalid choice. Please select a valid operation." >&2; exit 1;;
    esac

fi

case $operation in
    checkpoint)
        checkpoint
        ;;
    checkpointOnRefresh)
        checkpointOnRefresh
        ;;
    restore)
        restore
        ;;
    *)
        echo "Invalid operation: $operation" >&2
        usage
        ;;
esac
