#!/bin/sh


# Set this to true to log the call output to /tmp/s3fs-container
INTERNAL_DEBUG=false

usage() {


    echo "Invalid usage of s3 provisioner CLI.. :" >> /tmp/s3fs-container.log
    echo $@ >> /tmp/s3fs-container.log

    echo "Invalid usage/options of s3 provisioner CLI: ${@}"
    echo $@
	# err "Invalid usage. Usage: "
	# err "\t$0 init"
	# err "\t$0 attach <json params>"
	# err "\t$0 detach <mount device>"
	# err "\t$0 mount <mount dir> <mount device> <json params>"
	# err "\t$0 unmount <mount dir>"
	# err "\t$0 provision bucket awskey_id awskey"
	# exit 1
}

err() {
	echo -ne $* 1>&2
}

log() {
	echo -ne $* >&1
}

ismounted() {
    echo "ismounted() called" >> /tmp/s3fs-container.log

	CONTAINER=`docker ps --filter "label=flex.mount.path=${MNTPATH}" --format "{{.ID}}"`
	if [ "${CONTAINER}" == "" ]; then
		echo "0"
	else
		echo "1"
	fi
}

delete(){
    echo "delete() called" >> /tmp/s3fs-container.log
    echo "using AWS_ACCESS_KEY_ID=${2} AWS_SECRET_ACCESS_KEY=${3}" >> /tmp/s3fs-container.log
     #  provision bucket awskey_id awskey
    AWS_COMMAND="AWS_ACCESS_KEY_ID=$2 AWS_SECRET_ACCESS_KEY=$3 /usr/local/bin/aws s3 rb s3://${1} --force"
    echo "delete() called, running command: ${AWS_PROVISION_COMMAND}" >> /tmp/s3fs-container.log
    RESULT=`eval ${AWS_COMMAND}`
    if [ $? -eq 0 ]; then
          echo "delete() success: ${RESULT} " >> /tmp/s3fs-container.log
          log "{\"status\": \"Success\"}"
          exit 0
    else
       echo "delete failed with: $RESULT " >> /tmp/s3fs-container.log
       err "{\"status\": \"Failure\", \"message\": \"${RESULT}\"}"
       exit 1
    fi
}

provision(){
    echo "provision() called" >> /tmp/s3fs-container.log
    echo "using AWS_ACCESS_KEY_ID=${2} AWS_SECRET_ACCESS_KEY=${3}" >> /tmp/s3fs-container.log
     #  provision bucket awskey_id awskey
    AWS_PROVISION_COMMAND="AWS_ACCESS_KEY_ID=$2 AWS_SECRET_ACCESS_KEY=$3 /usr/local/bin/aws s3api create-bucket --bucket $1"
    echo "provision() called, running command: ${AWS_PROVISION_COMMAND}" >> /tmp/s3fs-container.log
    RESULT=`eval ${AWS_PROVISION_COMMAND}`
    if [ $? -eq 0 ]; then
          echo "provision() success: ${RESULT} " >> /tmp/s3fs-container.log
          log "{\"status\": \"Success\"}"
          exit 0
    else
       echo "provision failed with: $RESULT " >> /tmp/s3fs-container.log
       err "{\"status\": \"Failure\", \"message\": \"${RESULT}\"}"
       exit 1
    fi
}

attach() {
    echo "attach() called" >> /tmp/s3fs-container.log
    log "{\"status\": \"Success\"}"
	exit 0
}

detach() {
    echo "detach() called" >> /tmp/s3fs-container.log
	log "{\"status\": \"Success\"}"
	exit 0
}

domount() {
    echo "domount() called" >> /tmp/s3fs-container.log
	MNTPATH=$1

	FSTYPE=$(echo $2|jq -r '.["kubernetes.io/fsType"]')
	BUCKET=$(echo $2|jq -r '.["bucket"]')
	AWS_ACCESS_KEY_ID=$(echo $2|jq -r '.["AWS_ACCESS_KEY_ID"]')
	AWS_SECRET_ACCESS_KEY=$(echo $2|jq -r '.["AWS_SECRET_ACCESS_KEY"]')


  echo "domount() called aws_access_key_id: ${AWS_ACCESS_KEY_ID}" >> /tmp/s3fs-container.log
    echo "domount() called aws_secret_access_key: ${AWS_SECRET_ACCESS_KEY}" >> /tmp/s3fs-container.log
      echo "domount() called BUCKET: ${BUCKET}" >> /tmp/s3fs-container.log

	if [ $(ismounted) -eq 1 ] ; then
	    echo "domount() called, returning as its already mounted!  ${MNTPATH} " >> /tmp/s3fs-container.log
		log "{\"status\": \"Success\"}"
		exit 0
	fi

    mkdir -p ${MNTPATH} &> /dev/null

    DOCKER_OUT=`docker run -d --privileged -l flex.mount.path=${MNTPATH} -e S3User=${AWS_ACCESS_KEY_ID} -e S3Secret=${AWS_SECRET_ACCESS_KEY} -v ${MNTPATH}:/mnt/mountpoint:shared --cap-add SYS_ADMIN s3fs ${BUCKET} /mnt/mountpoint -o passwd_file=/etc/passwd-s3fs -d -d -f -o f2 -o curldbg`
    echo "domount() docker container output: ${DOCKER_OUT}" >> /tmp/s3fs-container.log
    log "{\"status\": \"Success\", \"docker-out\":\"${DOCKER_OUT}\"}"

	exit 0
}

unmount() {
        echo "unmount() called" >> /tmp/s3fs-container.log
	MNTPATH=$1
	if [ $(ismounted) -eq 0 ] ; then
                echo "unmount() called, but already unmounted " >> /tmp/s3fs-container.log
		log "{\"status\": \"Success\"}"
		exit 0
	fi

        CONTAINER=`docker ps --filter "label=flex.mount.path=${MNTPATH}" --format "{{.ID}}"`
        echo "unmount() called killing container ${CONTAINER}" >> /tmp/s3fs-container.log
	docker rm ${CONTAINER}
        rmdir ${MNTPATH} &> /dev/null

	log "{\"status\": \"Success\"}"
	exit 0
}


echo "--------------------------------------------------------------`date`------------------------------------" >> /tmp/s3fs-container.log
echo $@ >> /tmp/s3fs-container.log

op=$1

if [ "$op" = "init" ]; then
	log "{\"status\": \"Success\"}"
	exit 0
fi

shift
case "$op" in
	attach)
		attach $*
		;;
	detach)
		detach $*
		;;
	provision)
		provision $*
		;;
	delete)
        delete $*
        ;;
	mount)
		domount $*
		;;
	unmount)
		unmount $*
		;;
	*)
		usage
esac

exit 1

