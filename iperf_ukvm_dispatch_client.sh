#! /bin/bash

# Parameters (You can change)
SERVERCONFIGS=(
# "CPU# NETIF"
	"4 eth4"
	"5 eth5"
	"6 eth6"
	"7 eth7"
)

# Parameters (You should not change)
GUEST="Mirage"
PLATFORM="ukvm"
NUM=`expr ${#SERVERCONFIGS[@]} - 1`

# Usage
print_usage(){
	echo "[Usage] ./iperf_ukvm_dispatch_client.sh -v OCAMLVER -n NETDEVTYPE -i INTERVAL -p BINDIR -u UKVMDIR [-h]"
	echo "-a APP (char): To specify a workload name, iperf or iperf_udp."
	echo "-b BUFSIZE (uint): To specify the sender buffer size used for the workload."
	echo "-r REPEAT (uint): To specify the number of workload iteration."
	echo "-v OCAMLVER (char): To specify the OCaml version you are using. This is used for log file names."
	echo "-n NETDEVTYPE (char): To specify \"net\" or \"netmap\""
	echo "-i INTERVAL (uint): To specify an interval delay (in seconds) inserted between  each iperf-server unikernels dispatch. This value must be larger or equal to 5."
	echo "-k BINDIR (char): To specify a path to your directory where unikernel binary files are located."
	echo "-u UKVMDIR (char): To specify a path to your directory where ukvm-bin located."
	echo "-l LOGBASE (char): To specify a base name for log file directories. If you use \"group\' for this parameter, ./group0 ./group1 ... will be created."
	echo ""
}

# Arguments parsing
while getopts "a:b:r:v:n:i:k:u:l:h" OPT
do
    case $OPT in
		a)  APP=${OPTARG}
		    ;;
		b)  BUFSIZE=${OPTARG}
		    ;;
		r)  REPEAT=${OPTARG}
		    ;;
		v)  OCAMLVER=${OPTARG}
		    ;;
		n)  NETDEVTYPE=${OPTARG}
		    ;;
		i)  INTERVAL=${OPTARG}
		    ;;
		k)  BINDIR=${OPTARG}
		    ;;
		u)  UKVMDIR=${OPTARG}
		    ;;
		l)  LOGBASE=${OPTARG}
		    ;;
        h)  print_usage
            exit
            ;;
    esac
done

# Check if the arguments provided are valid or not
if [[ "${BUFSIZE}" =~ [0-9]* ]]; then
	echo "[Info] Log files will be generated on ./group[0,1,...]/${BUFSIZE}/"
else
	echo "[Error] Invalid buffer size parameter for senders. We cannot generate log files. (-b option)"
	exit
fi

if [[ "${REPEAT}" =~ [0-9]* ]]; then
	echo "[Info] A workload you selected will be repeated ${REPEAT} times."
else
	echo "[Error] Invalid parameter for the number of workload isolation. (-r option)"
	exit
fi

if [ "${NETDEVTYPE}" = "net" ] || [ "${NETDEVTYPE}" = "netmap" ]; then
	echo "[Info] Network device type \"${NETDEVTYPE}\" was seleted."
else
	echo "[Error] Invalid network device type. (-n option)"
	exit
fi

if [[ "${INTERVAL}" =~ [0-9]* ]]; then
	if [ ${INTERVAL} -lt 5 ]; then
		echo "[Warning] Invalid delay parameter for receivers. We will use a default value 5 [sec] for it. (-i option)"
		INTERVAL=5
	fi
else
	echo "[Warning] Invalid delay parameter for receivers. We will use a default value 5 [sec] for it. (-i option)"
	INTERVAL=5
fi
echo "[Info] We will use ${INTERVAL}[sec] as a delay interval."

if [ -e ${BINDIR} ] && [ -d ${BINDIR} ]; then
	echo "[Info] Unikernel binary path ${BINDIR} will be used."
else
	echo "[Error] Unikernel binary path provided is not a directory. (-k option)"
	exit
fi

if [ -e ${UKVMDIR}/ukvm-bin ]; then
	echo "[Info] ukvm-bin was found in ${UKVMDIR}."
else
	echo "[Error] ukvm-bin was not found in ${UKVMDIR}. (-u option)"
	exit
fi

MAX_CPU=`grep processor /proc/cpuinfo | tail -n 1 | cut -d ' ' -f 2`
for i in `seq 0 1 ${NUM}`
do
	ARG=(${SERVERCONFIGS[i]})
	CURR_CPU=${ARG[0]}
	if [ ${CURR_CPU} -gt ${MAX_CPU} ];
	then
		echo "[Error] This system does not have the CPU core #${CURR_CPU}"
		exit
	fi
done

# TODO: Server health checking (just pinging)

# Directory check
for i in `seq 0 1 ${NUM}`
do
	LOGPATH="./${LOGBASE}${i}/${BUFSIZE}"
	if [ ! -d ${LOGPATH} ]; then
		echo "[Error] Directory not found: ${LOGPATH}"
		exit
	fi
done

# Workload dispatching
for n in `seq 1 1 ${REPEAT}`
do
	echo ""
	echo "[Info] Buffer size ${BUFSIZE} ${n}/${REPEAT}"
	CLIENTLOG="${OCAMLVER}_${PLATFORM}_${APP}_client.log"
	DELAY=`expr ${NUM} \* ${INTERVAL}`
	for i in `seq 0 1 ${NUM}`
	do
		ARG=(${SERVERCONFIGS[i]})
		CPU=${ARG[0]}
		NETIF=${ARG[1]}
		LOGPATH="./${LOGBASE}${i}/${BUFSIZE}"
		CMD="sudo taskset -c ${CPU} ${UKVMDIR}/ukvm-bin --${NETDEVTYPE}=${NETIF} --delay=${DELAY} ${BINDIR}/c${i}.${PLATFORM}";
	
		echo "[Info] ${CMD}"
		${CMD} >> ${LOGPATH}/${CLIENTLOG} &
	
		DELAY=`expr ${DELAY} - ${INTERVAL}`
		sleep ${INTERVAL}
	done
	WLS=`jobs -p`
	echo ${WLS}
	
	WLS=""
	for WL in `jobs -p`
	do
		WLS="${WLS} ${WL}"
        wait ${WL} || let "FAIL+=1"
	done
    echo "[Info] iperf client processes with PIDs${WLS} finished running"

done

sleep 3
