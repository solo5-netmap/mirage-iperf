open Lwt.Infix

type stats = {
  mutable bytes: int64;
}

module Main (S: Mirage_types_lwt.STACKV4) = struct

  let server_port = 5001
  let client_port = 5002

  let write_and_check ip port udp buf =
    S.UDPV4.write ~dst:ip ~dst_port:port udp buf >|= Rresult.R.get_ok

  let iperf s src_ip src_port st buf =
    let l = Cstruct.len buf in
    if l = 1 then
      begin
      st.bytes <- 0L;
      Logs.info (fun f -> f "Connection started:");
      Lwt.return_unit
      end
    else if l = 2 then
      begin
      Logs.info (fun f -> f "Connection finished:");
      Logs.info (fun f -> f "Received %.0Lu Bytes" st.bytes);
      let udp = S.udpv4 s in
      let total = Cstruct.sub (Io_page.(to_cstruct (get 1))) 0 (String.length (Int64.to_string st.bytes)) in
      Cstruct.blit_from_string (Int64.to_string st.bytes) 0 total 0 (String.length (Int64.to_string st.bytes));
      write_and_check src_ip src_port udp total >>= fun () ->
      Lwt.return_unit
      end
    else
      begin
      st.bytes <- (Int64.add st.bytes (Int64.of_int l));
      Lwt.return_unit
      end

  let start s =
    let ips = List.map Ipaddr.V4.to_string (S.IPV4.get_ip (S.ipv4 s)) in
    (* debug is too much for us here *)
    Logs.set_level ~all:true (Some Logs.Info);
    Logs.info (fun f -> f "iperf server process started:");
    Logs.info (fun f -> f "IP address: %s" (String.concat "," ips));
    Logs.info (fun f -> f "Port number: %d" server_port);

    let st = {
      bytes=0L;
    } in

    Mclock.connect () >>= fun clock ->
    S.listen_udpv4 s ~port:server_port (fun ~src ~dst ~src_port buf ->
      iperf s src client_port st buf
    );
    S.listen s

end

