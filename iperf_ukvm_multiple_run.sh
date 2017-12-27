#! /bin/bash

# Parameters
APP="iperf"
PARALLEL=4
NETDEVTYPE="net"
INTERVAL=5
BINDIR="/tmp"
UKVMDIR="/home/work/solo5/ukvm"
OCAMLVER="4.04.0"
WORKLOADS=(
	"64 100_000_000"
	"128 200_000_000"
	"256 400_000_000"
	"512 800_000_000"
	"1024 1_400_000_000"
	"1460 1_600_000_000"
	)
REPEAT=10

# Parameters (you shold not change)
GUEST="MirageOS"
PLATFORM="ukvm_${NETDEVTYPE}"
COMPILER="OCaml ${OCAMLVER}"
TMP=`expr ${#WORKLOADS[@]} - 1`

# Usage
print_usage(){
	echo "[Usage] ./iperf_ukvm_multiple_run.sh -v OCAMLVER -n NETDEVTYPE -i INTERVAL -p BINDIR -u UKVMDIR [-h]"
	echo "-c : To indicate the iperf client unikernels will be dispatched on this host server"
	echo "-s : To indicate the iperf server unikernels will be dispatched on this host server"
	echo ""
}

# Arguments parsing
IS_CLIENT="no"
IS_SERVER="no"
while getopts ":cs" OPT
do
    case $OPT in
		c)  IS_CLIENT="yes"
		    ;;
		s)  IS_SERVER="yes"
		    ;;
        h)  print_usage
            exit
            ;;
    esac
done

# Option for Netmap
#if [ ${NETDEVTYPE} = "netmap" ]; then
#	sudo /etc/init.d/irqbalance stop
#	sudo bash -c 'echo 1 > /proc/irq/46/smp_affinity'
#	sudo bash -c 'echo 2 > /proc/irq/64/smp_affinity'
#	sudo bash -c 'echo 4 > /proc/irq/66/smp_affinity'
#	sudo bash -c 'echo 8 > /proc/irq/68/smp_affinity'
#	sudo bash -c 'echo 10 > /proc/irq/70/smp_affinity'
#	sudo bash -c 'echo 20 > /proc/irq/72/smp_affinity'
#fi

# Start execution
## Server side
if [ ${IS_SERVER} = "yes" ]; then
	# Build unikernels required
	BUILD_CMD="./iperf_ukvm_build_parallel.sh -a ${APP} -b 1024 -t 1_000_000_000 -p ${PARALLEL} -v ${OCAMLVER} -k ${BINDIR}"
	echo ${BUILD_CMD}
	${BUILD_CMD}

	echo "Dispaching server side unikernels ..."
	S_CMD="./iperf_ukvm_dispatch_server.sh -n ${NETDEVTYPE} -i ${INTERVAL} -k ${BINDIR} -u ${UKVMDIR}"
	echo ${S_CMD}
	${S_CMD}
fi

## Client side
if [ ${IS_CLIENT} = "yes" ]; then
	for WL_NUM in `seq 0 1 ${TMP}`
	do
		ARG=(${WORKLOADS[${WL_NUM}]})
		BUFSIZE=${ARG[0]}
		TOTALSIZE=${ARG[1]}
		# Build unikernels required
		BUILD_CMD="./iperf_ukvm_build_parallel.sh -a ${APP} -b ${BUFSIZE} -t ${TOTALSIZE} -p ${PARALLEL} -v ${OCAMLVER} -k ${BINDIR}"
		echo ${BUILD_CMD}
		${BUILD_CMD}
		echo "Unikernel build completed!"

		# Create a new directory used to hold logs (a previous directory will be removed)
		NUM=`expr ${PARALLEL} - 1`
		for i in `seq 0 1 ${NUM}`
		do
			LOGPATH="./group${i}/${BUFSIZE}"
			if [ -e ${LOGPATH} ];
			then
				rm -rf ${LOGPATH}
			fi
			mkdir -p ${LOGPATH}
		done

		# Workload dispatch
		echo "Dispaching client side unikernels ..."
		C_CMD="./iperf_ukvm_dispatch_client.sh -a ${APP} -b ${BUFSIZE} -r ${REPEAT} -v ${OCAMLVER} -n ${NETDEVTYPE} -i ${INTERVAL} -k ${BINDIR} -u ${UKVMDIR} -l group"
		echo ${C_CMD}
		${C_CMD}
	done
	
	# JSON file generation for outputs
	NUM=`expr ${PARALLEL} - 1`
	for i in `seq 0 1 ${NUM}`
	do
		LOGBASE="./group${i}"
		JSONLOG="${LOGBASE}/${OCAMLVER}_${PLATFORM}_${APP}.json"
		echo -n "{
		  \"guest\": \"${GUEST}\",
		  \"platform\": \"${PLATFORM}\",
		  \"compiler\": \"${COMPILER}\",
		  \"records\": [
		" > ./${JSONLOG}

		for WL_NUM in `seq 0 1 ${TMP}`
		do
			ARG=(${WORKLOADS[${WL_NUM}]})
			BUFSIZE=${ARG[0]}
            echo -n "{ \"bufsize\": ${BUFSIZE}, \"throughput\": [" >> ./${JSONLOG}

			TP=`grep 'client: Throughput' ./${LOGBASE}/${BUFSIZE}/${OCAMLVER}_ukvm_${APP}_client.log | cut -d' ' -f 10 | tr '\n' ','`
			echo -n "${TP}" >> ./${JSONLOG}
            echo -n "]}," >> ./${JSONLOG}
		done

		# Correct the generated JSON file
		echo -n "]}" >> ./${JSONLOG}
		sed -i -e 's/,\]/]/g' ./${JSONLOG}
		cat ./${JSONLOG} | jq
	done
	sudo killall ${UKVMDIR}/ukvm-bin
fi

