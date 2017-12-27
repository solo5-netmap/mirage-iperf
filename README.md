# iperf like tool for MirageOS

## Directory
`iperf`: TCP-based iperf server/client  
`iperf_udp`: UDP-based iperf server/client  
`iperf_udp_compat`: UDP-based iperf server/client(experimental)

## Script
(For single server/client pair execution)  
`iperf_run.sh`: for xen and virtio using the `virsh` command  
`iperf_ukvm_run.sh`: for ukvm

(For multiple server/client pairs execution, ukvm only)  
`iperf_ukvm_multiple_run.sh`: for ukvm  
`iperf_ukvm_build_parallel.sh`: called by iperf_ukvm\_multiple\_run.sh  
`iperf_ukvm_dispatch_client.sh`: called by iperf\_ukvm\_multiple\_run.sh  
`iperf_ukvm_dispatch_server.sh`: called by iperf\_ukvm\_multiple\_run.sh  

## Usage
`iperf_run.sh`  
1. Modify IP setting in  `./{iperf,iperf_udp}/{iperf,iperf_udp}_{client,server}/config.ml` so that your unikernel can run on your network environment
2. Set a value for each variable in the script:  
`APP`: iperf or iperf_udp  
`CLIENTADDR`: IP address of a iperf-client side machine  
`SERVERADDR`: IP address of a iperf-server side machine  
`USER`: username for ssh and scp on the iperf-client/server machines  
`BUFIZE`: int array of sender buffer size for each packet  
`ITERATIONS`: how many times the client side is dispached for each buffer size you specified in `BUFSIZE`  
`OCAMLVER`: OCaml version used for `opam switch` in the script  
3. Configure your ssh login so that your passphrase is not required for the iperf-client/server side machines (maybe by using `ssh-agent` and `ssh-add`)
4. Execute the script with two arguments like `./iperf_run.sh virtio /tmp`  
1st argument: target platform, `virtio` or `xen`  
2nd argument: directory to which your unikernel binary is sent by scp  

`iperf_ukvm_run.sh`
1. Modify IP setting in  `./{iperf,iperf_udp}/{iperf,iperf_udp}_{client,server}/config.ml` so that your unikernel can run on your network environment
2. Set a value for each variable in the script:
`APP`: iperf or iperf_udp  
`WORKLOADS`: Array of a sender buffer size and total payload size in bytes to be sent  
`ITERATIONS`: How many times the client side is dispached for each buffer size you specified in `WORKLOADS`  
`OCAMLVER`: OCaml version used for `opam switch` in the script  
`UKVM_PATH`: Which directory the ukvm-bin binary is located at
`NET`: Networking option (`--net=` or `--netmap=`)
`C_NETIF`: A network device used for the iperf-client side
`S_NETIF`: A network device used for the iperf-server side
`CPU_C`: Which CPU core# is assigned for the iperf-client side ukvm-bin (for the taskset command)
`CPU_S`: Which CPU core# is assigned for the iperf-server side ukvm-bin (for the taskset command)
`SEC`: Execution delay between the iperf-server side and iperf-client side dispatch

`iperf_ukvm_multiple_run.sh` (and the related scripts)
1. Set a value for each variable in `iperf_ukvm_multiple_run.sh`:
`APP`: iperf or iperf_udp
`PARALLEL`: How many iperf-clients and/or iperf-servers are executed in parallel
`NETDEVTYPE`: Networking option (`net` or `netmap`)
`UKVMDIR`: Which directory the ukvm-bin binary is located at
`OCAMLVER`: OCaml version used for `opam switch` in the script
`WORKLOADS`: Array of pairs of the sender buffer size and total payload size in bytes to be sent
`REPEAT`: How many times the client side is dispached for each buffer size you specified in `WORKLOADS`
2. IP address configuration change in `iperf_ukvm_build_parallel.sh`  
This script uses the `sed` command for that aim. Please see the comment 'IP address setting and compilation' and below in the script.
3. Set a value for each variable in `iperf_ukvm_dispatch_client.sh`:
`SERVERCONFIG`: Array of pairs of the CPU core number and network device name assigned for each iperf-client process
(the array size must be equal to `PARALLEL` in `iperf_ukvm_multiple_run.sh`)
4. Set a value for each variable in `iperf_ukvm_dispatch_server.sh`:
`SERVERCONFIG`: Array of pairs of the CPU core number and network device name assigned for each iperf-server process
(the array size must be equal to `PARALLEL` in `iperf_ukvm_multiple_run.sh`)
5. Execute `iperf_ukvm_multiple_run.sh` with `-c` and/or `-s`. If you want to execute both the client and server side on a same server, execute `iperf_ukvm_multiple_run.sh -c -u`. Otherwise, execute `iperf_ukvm_multiple_run.sh -s`(for server-side execution only) or `iperf_ukvm_multiple_run.sh -c` (for client-side execution only)  
