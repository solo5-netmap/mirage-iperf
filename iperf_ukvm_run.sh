#! /bin/bash

# Parameters (You can chenge)
APP="iperf"
WORKLOADS=(
	"64 100_000_000"
	"128 200_000_000"
	"256 400_000_000"
	"512 800_000_000"
	"1024 1_600_000_000"
	"1460 2_200_000_000"
	)
ITERATIONS="10"
OCAMLVER="4.04.0"
UKVM_PATH="/home/work/solo5/ukvm"
NET="--netmap="
C_NETIF="eth1"
S_NETIF="eth0"
CPU_C="1"
CPU_S="0"
SEC=5

# Parameters (You should not chenge)
GUEST="Mirage"
PLATFORM="ukvm"
CURRENT_DIR=${PWD}
CLIENTPATH="./${APP}/${APP}_client"
SERVERPATH="./${APP}/${APP}_server"
CLIENTBIN="${APP}_client.${PLATFORM}"
SERVERBIN="${APP}_server.${PLATFORM}"

# Check the arguments provided
case ${PLATFORM} in
        "ukvm" )
                CMD_C="sudo taskset -c ${CPU_C} ${UKVM_PATH}/ukvm-bin ${NET}${C_NETIF} ./${CLIENTPATH}/${CLIENTBIN}";
                CMD_S="sudo taskset -c ${CPU_S} ${UKVM_PATH}/ukvm-bin ${NET}${S_NETIF} ./${SERVERPATH}/${SERVERBIN}";
        ;;
        * ) echo "Invalid hypervisor selected"; exit
esac

COMPILER="OCaml ${OCAMLVER}"

# switch an OCaml compiler version to be used
opam switch ${OCAMLVER}
eval `opam config env`

# Build and dispatch a server application
cd ${SERVERPATH}
make clean
mirage configure -t ${PLATFORM}
make
cd ${CURRENT_DIR}
${CMD_S} &
sleep ${SEC}

# Dispatch a client side MirageOS VM repeatedly
JSONLOG="./${OCAMLVER}_${PLATFORM}_${APP}.json"
echo -n "{
  \"guest\": \"${GUEST}\",
  \"platform\": \"${PLATFORM}\",
  \"compiler\": \"${COMPILER}\",
  \"records\": [
" > ./${JSONLOG}

CLIENTLOG="${OCAMLVER}_${PLATFORM}_${APP}_client.log"
echo -n '' > ./${CLIENTLOG}

cd ${CLIENTPATH}
make clean
mirage configure -t ${PLATFORM}
cd ${CURRENT_DIR}

for WL in "${WORKLOADS[@]}"
do
	cd ${CLIENTPATH}
	TMP=(${WL})
	BUF=${TMP[0]}
	SIZE=${TMP[1]}
	sed -i -e "s/let\ blen\ =\ [0-9]*/let blen = ${BUF}/" ./unikernel.ml
	sed -i -e "s/let\ total_size\ =\ [0-9,_]*/let total_size = ${SIZE}/" ./unikernel.ml
	make
	cd ${CURRENT_DIR}

	echo -n "{ \"bufsize\": ${BUF}, \"throughput\": [" >> ./${JSONLOG}
	for i in $(seq 1 ${ITERATIONS});
	do
		echo "***** Testing iperf: Buffer size ${BUF}, ${i}/${ITERATIONS} *****"
		echo "${CURRENT_DIR}/${CLIENTPATH}"
		${CMD_C} >> ${CLIENTLOG}
		TP=`sed -e 's/^M/\n/g' ./${CLIENTLOG} | grep Throughput | tail -n 1 | cut -d' ' -f 10`
		echo -n "${TP}," >> ./${JSONLOG}
	done
	echo -n "]}," >> ./${JSONLOG}
done

# Correct the generated JSON file
echo -n "]}" >> ./${JSONLOG}
sed -i -e 's/,\]/]/g' ${JSONLOG}
cat ./${JSONLOG} | jq

# Destroy the server application
sudo killall ${UKVM_PATH}/ukvm-bin
