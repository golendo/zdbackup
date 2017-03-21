#! /bin/bash
PATH=/opt/zdbackup/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

### FUNCTIONS

errcho() {
	printf "%s\n" "$*" >&2;
}

function usage {
	echo "Usage: $0 [OPTION]... Dataset"
	echo ""
	echo "Options: "
	echo "-p, --prefix                specify the prefix to use"
	echo "-i, --interval              specify the interval of the backups (yMwdhms)"
	echo "-n, --backups               specify the count of the backups. The oldest backups gets deleted. 0 = no backup gets deleted"
	echo "-c, --timestamp             sets the 'current time' of the script (unix timestamp)"
}

function timeToSec {
	FullTime="$1"
	RxTime="^(([0-9]+)[y])?(([0-9]+)[M])?(([0-9]+)[w])?(([0-9]+)[d])?(([0-9]+)[h])?(([0-9]+)[m])?(([0-9]+)[s])?$"
	Seconds=0

	## ${BASH_REMATCH[2]} year
	## ${BASH_REMATCH[4]} month
	## ${BASH_REMATCH[6]} week
	## ${BASH_REMATCH[8]} day
	## ${BASH_REMATCH[10]} hour
	## ${BASH_REMATCH[12]} min
	## ${BASH_REMATCH[14]} sec
	if [[ $FullTime =~ $RxTime ]]; then

		if [ "${BASH_REMATCH[14]}" != "" ]; then # seconds
			Seconds=$((Seconds+${BASH_REMATCH[14]}))
		fi

		if [ "${BASH_REMATCH[12]}" != "" ]; then # minutes
			Seconds=$((Seconds+${BASH_REMATCH[12]}*60))
		fi

		if [ "${BASH_REMATCH[10]}" != "" ]; then # hours
			Seconds=$((Seconds+${BASH_REMATCH[10]}*60*60))
		fi

		if [ "${BASH_REMATCH[8]}" != "" ]; then # days
			Seconds=$((Seconds+${BASH_REMATCH[8]}*60*60*24))
		fi

		if [ "${BASH_REMATCH[6]}" != "" ]; then # weeks
			Seconds=$((Seconds+${BASH_REMATCH[6]}*60*60*24*7))
		fi

		if [ "${BASH_REMATCH[4]}" != "" ]; then # month
			Seconds=$((Seconds+${BASH_REMATCH[4]}*60*60*24*30))
		fi

		if [ "${BASH_REMATCH[2]}" != "" ]; then # year
			Seconds=$((Seconds+${BASH_REMATCH[2]}*60*60*24*365))
		fi

		echo "$Seconds"
	else
		exit 1
	fi
}

### DEFAULTS
Dataset=""
BackupSnapshot="zdbackup-"
Interval=0
Backups=0
CurrentTime=$(date +%s)

### Dataset, prefix, interval, elements

while [ "$2" != "" ]; do
	case $1 in
		-p | --prefix )
			shift
			if [ "$1" == "" ]; then
				errcho "prefix is empty"
				exit 1
			fi
			BackupSnapshot="$1-"
		;;
		-i | --interval )
			shift
			Interval=$(timeToSec $1)
			if [ "$?" != 0 ]; then
				errcho "please use the correct format in the proper sequence for setting the interval!"
				exit 1
			fi
		;;
		-n | --backups )
			shift
			Backups=$1
		;;
		-c | --timestamp )
			shift
			CurrentTime="$1"
		;;
		-h | --help )
			usage
			exit
		;;
		* )
			usage
			exit 1
	esac
	shift
done

if [ "$1" == "" ]; then
	usage
	exit 1
fi
Dataset="$1"

LastSnapshot=$(bash -o pipefail -c "zfs list -t snapshot -S creation -o name -H -r $Dataset |sed -n -e '0,/.*@$BackupSnapshot/s/^.*@$BackupSnapshot//p'")
if [ "$?" != 0 ]; then
	errcho "dataset not found!"
	exit 1
fi

if [ "$LastSnapshot" == "" ]; then
	LastSnapshot="0"
fi

NextSnapshot=$(expr $LastSnapshot + $Interval)

if ((NextSnapshot <= CurrentTime)); then
	LastSnapshot=$(zfs snapshot $Dataset@$BackupSnapshot$CurrentTime)
	if [ "$?" -ne 0 ] || [ -n "$LastSnapshot" ]; then
		errcho "could not create snapshot on dataset"
		exit 1
	fi
	LastSnapshot=$CurrentTime
else
	echo "too early for snapshot"
	exit 0
fi

if ((Backups > 0)); then
	Backups=$((Backups+1))
	echo $(bash -o pipefail -c "zfs list -t snapshot -S creation -o name -H -r $Dataset |grep '^$Dataset@$BackupSnapshot' |tail -n +$Backups |xargs -r -n 1 zfs destroy -v")
fi
