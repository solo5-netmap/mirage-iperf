#! /bin/bash

# Parameters (for users)
SERVERCONFIGS=(
# "CPU# NETIF"
	"0 eth0"
	"1 eth1"
	"2 eth2"
	"3 eth3"
)

# Parameters (should not be changed)
PLATFORM="ukvm"
NUM=`expr ${#SERVERCONFIGS[@]} - 1`

# Usage
print_usage(){
	echo "[Usage] ./iperf_ukvm_parallel_run.sh -a APP -v OCAMLVER -g GROUP -s SERVERCONFIG -c CLIENTCONFIG [-h]"
	echo "-n NETDEVTYPE (char): To specify \"net\" or \"netmap\""
	echo "-i INTERVAL (uint): To specify an interval delay (in seconds) inserted between  each iperf-server unikernels dispatch. This value must be larger or equal to 5."
	echo "-k BINDIR (char): To specify a path to your directory where unikernel binary files are located."
	echo "-u UKVMDIR (char): To specify a path to your directory where ukvm-bin located."
	echo ""
}

# Arguments parsing
while getopts "n:i:k:u:h" OPT
do
    case $OPT in
		n)  NETDEVTYPE=${OPTARG}
		    ;;
		i)  INTERVAL=${OPTARG}
		    ;;
		k)  BINDIR=${OPTARG}
		    ;;
		u)  UKVMDIR=${OPTARG}
		    ;;
        h)  print_usage
            exit
            ;;
    esac
done

# Check if the arguments provided are valid or not
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
	exit
fi
echo "[Info] We will use ${INTERVAL}[sec] as a delay interval."

if [ -e ${BINDIR} ] && [ -d ${BINDIR} ]; then
	echo "[Info] Unikernel binary path ${BINDIR} is used."
else
	echo "[Error] Unikernel binary path provided is not a directory."
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

# Sleep for the first delay on the receiver
for i in `seq 0 1 ${NUM}`
do
	ARG=(${SERVERCONFIGS[i]})
	CPU=${ARG[0]}
	NETIF=${ARG[1]}
	CMD="sudo taskset -c ${CPU} ${UKVMDIR}/ukvm-bin --${NETDEVTYPE}=${NETIF} --delay=0 ${BINDIR}/s${i}.${PLATFORM}";
	echo ${CMD}
	${CMD} &

	sleep ${INTERVAL}
done
