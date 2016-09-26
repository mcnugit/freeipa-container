#!/bin/bash

set -e

if [ -z "$DATADIR" -o -z "$HOST" ] ; then
	echo "Not sure where FreeIPA data should be stored." >&2
	exit 1
fi

if [ -f "$HOST$DATADIR"/etc/ipa/default.conf ] ; then
	echo "FreeIPA seems already initialized in [$DATADIR]." >&2
	exit 1
fi

NAME_PARAM=''
if [ -n "$NAME" ] ; then
	NAME_PARAM=" --name $NAME"
fi

mkdir -p "$HOST$DATADIR"

HOSTNAME_PARAM=
NET_HOST_PARAM=false
PUBLISH_PARAM=false
CAP_ADD_PARAM=
IP_ADDRESS_PARAM=

while [[ "$#" -ne '0' ]] ; do
	case "$1" in
		--hostname|hostname)
			shift
			HOSTNAME_PARAM="$1"
			shift
			;;
		--hostname=*)
			HOSTNAME_PARAM="${1#--hostname=}"
			shift
			;;
		hostname=*)
			HOSTNAME_PARAM="${1#hostname=}"
			shift
			;;
		net-host)
			NET_HOST_PARAM=true
			shift
			;;
		publish)
			PUBLISH_PARAM=true
			shift
			;;
		cap-add)
			shift
			CAP_ADD_PARAM="$1"
			shift
			;;
		cap-add=*)
			CAP_ADD_PARAM="${1#cap-add=}"
			shift
			;;
		ip-address)
			shift
			IP_ADDRESS_PARAM="$1"
			shift
			;;
		ip-address=*)
			IP_ADDRESS_PARAM="${1#ip-address=}"
			shift
			;;
		--)
			shift
			break
			;;
		*)
			break
	esac
done

if [ -z "$HOSTNAME_PARAM" ] ; then
	echo "Please specify the hostname for the server with --hostname parameter." >&2
	echo "Usage: atomic install$NAME_PARAM $IMAGE --hostname FQDN.of.the.IPA.server" >&2
	exit 1
fi

echo "--rm" > "$HOST$DATADIR"/docker-run-opts
echo "-h $HOSTNAME_PARAM" >> "$HOST$DATADIR"/docker-run-opts
echo "$HOSTNAME_PARAM" > "$HOST$DATADIR"/hostname
OPTS="-h $HOSTNAME_PARAM"

if $NET_HOST_PARAM ; then
	echo "--net=host" >> "$HOST$DATADIR"/docker-run-opts
	OPTS="$OPTS --net=host"
fi

if $PUBLISH_PARAM ; then
	echo "-P" >> "$HOST$DATADIR"/docker-run-opts
	OPTS="$OPTS -P"
fi

while [ -n "$CAP_ADD_PARAM" ] ; do
	echo "--cap-add=${CAP_ADD_PARAM%%:*}" >> "$HOST$DATADIR"/docker-run-opts
	OPTS="$OPTS --cap-add=${CAP_ADD_PARAM%%:*}"
	if [ "$CAP_ADD_PARAM" == "${CAP_ADD_PARAM#*:}" ] ; then
		CAP_ADD_PARAM=''
	else
		CAP_ADD_PARAM="${CAP_ADD_PARAM#*:}"
	fi
done

if [ -n "$IP_ADDRESS_PARAM" ] ; then
	echo "-e IPA_SERVER_IP=$IP_ADDRESS_PARAM" >> "$HOST$DATADIR"/docker-run-opts
	OPTS="$OPTS -e IPA_SERVER_IP=$IP_ADDRESS_PARAM"
fi

set -x
chroot "$HOST" /usr/bin/docker run -ti --rm $NAME_PARAM \
	-e NAME="$NAME" -e IMAGE="$IMAGE" \
	-v "$DATADIR":/data:Z -v /sys/fs/cgroup:/sys/fs/cgroup:ro -v /dev/urandom:/dev/random:ro --tmpfs /run --tmpfs /tmp \
	$OPTS "$IMAGE" exit-on-finished "$@"
