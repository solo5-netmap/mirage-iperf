open Mirage

let server_ipconfig =
  let nw = Ipaddr.V4.Prefix.of_address_string_exn "192.168.112.105/24" in
  let gw = Some (Ipaddr.V4.of_string_exn "192.168.112.1") in
  { network = nw; gateway = gw }

let sv4 =
  generic_stackv4 ~config:server_ipconfig default_network

let main =
  let packages = [ package ~sublibs:["ethif"; "arpv4"; "ipv4"; "icmpv4"; "tcp"; "udp"] "tcpip"] in
  foreign
    ~packages
    "Unikernel.Main" (stackv4 @-> job)

(* let tracing = mprof_trace ~size:2000000 () *)

let () =
  (* register "iperf_udp_server" ~tracing [ *)
  (* register "iperf_udp_server" [ *)
  register "iperf_udp_server" [
    main $ sv4
  ]

