#! /bin/bash

# Parameters
PLATFORM="ukvm"
CURRENT_DIR=${PWD}

# Usage
print_usage(){
	echo "[Usage] ./iperf_ukvm_build_multiple.sh -a APP -p PARALLEL [-h]"
	echo "-a APP (char): To specify a workload name, iperf or iperf_udp."
	echo "-b BUFSIZE (uint): To specify the sender buffer size used for the workload."
	echo "-t TOTALSIZE (uint): To specify the total data size to be sent from a client."
	echo "-p PARALLEL (uint): To specify the number of workload pairs you want to generate."
	echo "-v OCAMLVERSION (char): To specify an OCaml version to compile iperf"
	echo "-k BINDIR (char): To specify a path to your directory where unikernel binary files are located."
	echo "-h : To print usage"
	echo ""
}

# Arguments parsing
while getopts "a:b:t:p:v:k:h" OPT
do
    case $OPT in
		a)  APP=${OPTARG}
		    ;;
		b)  BUFSIZE=${OPTARG}
		    ;;
		t)  TOTALSIZE=${OPTARG}
		    ;;
		v)  OCAMLVER=${OPTARG}
		    ;;
		p)  PARALLEL=${OPTARG}
		    ;;
		k)  BINDIR=${OPTARG}
		    ;;
        h)  print_usage
            exit
            ;;
    esac
done

# Check the arguments 
if [ ${APP} = "iperf" -o ${APP} = "iperf_udp" ];
then
	echo "[Info] Application you specified: ${APP}"
else
	echo "[Error] An application name you specified is invalid. You must use \"iperf\" or \"iperf_udp\""
	exit
fi

if [[ "${BUFSIZE}" =~ [0-9]* ]]; then
	echo "[Info] Sender buffer size ${BUFSIZE}[bytes] specified."
else
	echo "[Error] Invalid buffer size parameter for senders."
	exit
fi

TMP=${TOTALSIZE//_/}
if [[ "${TMP}" =~ [0-9]* ]]; then
	if [ ${BUFSIZE} -gt ${TMP} ]; then
		echo "[Error] The total transfer size must be larger or equal to the sender buffer size."
		exit
	fi
	echo "[Info] Total transfer size ${TMP}[bytes] specified."
else
	echo "[Error] Invalid transfer size parameter for senders."
	exit
fi

if [[ "${PARALLEL}" =~ [0-9]* ]]; then
	echo "[Info] ${PARALLEL} pair(s) of iperf server and client will be generated at /tmp."
else
	PARALLEL=1
	echo "[Warning] Invalid number of worklaad pairs."
	echo "[Info] ${PARALLEL} pair of iperf server and client will be generated at /tmp."
fi

if [ -e ${BINDIR} ] && [ -d ${BINDIR} ]; then
	echo "[Info] Unikernel binary path ${BINDIR} will be used."
else
	echo "[Error] Unikernel binary path provided is not a directory. (-k option)"
	exit
fi

TMP=`opam switch ${OCAMLVER}`
if [[ ${TMP} = ^\[ERROR\]* ]];
then
	exit
else
	echo ${OCAMLVER}
fi

CLIENTPATH="./${APP}/${APP}_client"
SERVERPATH="./${APP}/${APP}_server"
CLIENTBIN="${APP}_client.${PLATFORM}"
SERVERBIN="${APP}_server.${PLATFORM}"

# switch an OCaml compiler version to be used
echo "[Info] We will use OCaaml compiler version ${OCAMLVER}."
sleep 5
opam switch ${OCAMLVER}
eval `opam config env`

# IP address setting and compilation
# This sample generates 192.168.112.100-1xx for clients and 192.168.112.200-2yy for servers
S_IP=100
C_IP=200
NUM=`expr ${PARALLEL} - 1`
for i in `seq 0 1 ${NUM}`
do
	# Build both the server and client sides
	cd ${SERVERPATH}
	make clean
	sed -i -e "s/192\.168\.112\.[0-2][0-9][0-9]\/24/192.168.112.${S_IP}\/24/" ./config.ml
	mirage configure -t ${PLATFORM}
	make
	cp ./${SERVERBIN} ${BINDIR}/s${i}.${PLATFORM}
	cd ${CURRENT_DIR}

	cd ${CLIENTPATH}
	make clean
	sed -i -e "s/192\.168\.112\.[0-2][0-9][0-9]\/24/192.168.112.${C_IP}\/24/" ./config.ml
	mirage configure -t ${PLATFORM}
	sed -i -e "s/192\.168\.112\.[0-2][0-9][0-9]/192.168.112.${S_IP}/" ./unikernel.ml
	sed -i -e "s/let\ blen\ =\ [0-9]*/let blen = ${BUFSIZE}/" ./unikernel.ml
	sed -i -e "s/let\ total_size\ =\ [0-9,_]*/let total_size = ${TOTALSIZE}/" ./unikernel.ml
	make
	cp ./${CLIENTBIN} ${BINDIR}/c${i}.${PLATFORM}
	cd ${CURRENT_DIR}

	S_IP=`expr ${S_IP} + 1`
	C_IP=`expr ${C_IP} + 1`
done
