open Lwt.Infix

type stats = {
  mutable bytes: int64;
  mutable start_time: int64;
  mutable last_time: int64;
}

module Main (S: Mirage_types_lwt.STACKV4) (Time : Mirage_types_lwt.TIME) = struct

  let server_ip = Ipaddr.V4.of_string_exn "192.168.112.10"
  let server_port = 5001
  let client_port = 50001
  let total_size = 2_000_000_000
  let blen = 1024

  let msg =
    "01234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789001234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890"

  let mlen =
    if blen <= (String.length msg) then blen
    else (String.length msg)

  let print_data st =
    let duration = Int64.sub st.last_time st.start_time in
    let rate = (Int64.float_of_bits st.bytes) /. (Int64.float_of_bits duration) *. 1000. *. 1000. *. 1000. in
    Logs.info (fun f -> f  "iperf_udp_client: Duration = %.0Lu [ns] (start_t = %.0Lu, end_t = %.0Lu),  Data sent = %Ld [bytes], Throughput = %.2f [bytes/sec]" duration st.start_time st.last_time st.bytes rate);
    Logs.info (fun f -> f  "iperf_udp_client: Throughput = %.2f [MBs/sec]"  (rate /. 1000000.));
    Lwt.return_unit

  let write_and_check ip port udp buf =
    S.UDPV4.write ~src_port:client_port ~dst:ip ~dst_port:port udp buf >|= Rresult.R.get_ok

  (* set a UDP diagram ID for the C-based iperf *)
  let set_id buf num =
    if (Cstruct.len buf) = 0 then
      Lwt.return_unit 
    else
      begin
        Cstruct.BE.set_uint32 buf 0 (Int32.of_int num);
        Lwt.return_unit
      end

  (* client function *)
  let iperfclient amt dest_ip dport udp clock =
    Logs.info (fun f -> f  "iperf_udp_client: Trying to connect to a server at %s:%d, buffer size = %d" (Ipaddr.V4.to_string server_ip) server_port mlen);
    Logs.info (fun f -> f  "iperf_udp_client: %.0d bytes data transfer initiated." amt);
    let zeros = Cstruct.create 40 in
    let body = amt / mlen in
    let reminder = amt - (mlen * body) in

    (* Create data to be sent *)
    let a = Cstruct.sub (Io_page.(to_cstruct (get 1))) 0 mlen in
    Cstruct.blit_from_string msg 0 a 0 mlen;
    Cstruct.blit zeros 0 a 0 (Cstruct.len zeros);

    (* Loop function for packet sending *)
    let rec loop num body st = 
      match num with
      (* Send the first packet to notify the start of a measurement *)
      | 0 -> 
        set_id a 0 >>= fun () ->
        write_and_check dest_ip dport udp a >>= fun () ->
        st.start_time <- Mclock.elapsed_ns clock; 
        loop (num + 1) body st
      (* Send a closing packet(s) to complete the measurement *)
      | -1 -> if reminder = 0 then
        begin
          Logs.info (fun f -> f "body = %d" body);
          set_id a (-1 * body) >>= fun () ->
          write_and_check dest_ip dport udp a >>= fun () ->
          st.last_time <- Mclock.elapsed_ns clock; 
          st.bytes <- (Int64.add st.bytes (Int64.of_int (Cstruct.len a)));
          Lwt.return_unit
        end
        else
        begin
          set_id a body >>= fun () ->
          write_and_check dest_ip dport udp a >>= fun () ->
          st.bytes <- (Int64.add st.bytes (Int64.of_int (Cstruct.len a)));
          let a = Cstruct.sub a 0 reminder in
          st.bytes <- (Int64.add st.bytes (Int64.of_int (Cstruct.len a)));
          set_id a (-1 * (body + 1)) >>= fun () ->
          write_and_check dest_ip dport udp a >>= fun () ->
          st.last_time <- Mclock.elapsed_ns clock; 
          st.bytes <- (Int64.add st.bytes (Int64.of_int (Cstruct.len a)));
          Lwt.return_unit
        end
      (* Usual packet sending *)
      | n ->
        set_id a n >>= fun () ->
        write_and_check dest_ip dport udp a >>= fun () ->
        st.bytes <- (Int64.add st.bytes (Int64.of_int (Cstruct.len a)));
        if (num + 1) = body then
          loop (-1) body st
        else
          loop (num + 1) body st
    in

    (* Measurement *)
    let t0 = Mclock.elapsed_ns clock in
    let st = {
      bytes=0L; start_time = t0; last_time = t0
    } in
    loop 0 body st >>= fun () ->

    (* Print the obtained result *)
    print_data st >>= fun () ->
    Logs.info (fun f -> f  "iperf_udp_client: Done.");
    Time.sleep_ns (Duration.of_sec 3) >>= fun () ->
    Lwt.return_unit

  let start s _time =
    let c = Gc.get() in
    Logs.info (fun f -> f "iperf_udp_client: minor_heap_size %d bytes" c.minor_heap_size);
    Time.sleep_ns (Duration.of_sec 1) >>= fun () -> (* Give server 1.0 s to call listen *)
    S.listen_udpv4 s ~port:client_port (fun ~src ~dst ~src_port buf ->
      Logs.info (fun f -> f "iperf_udp_client: %.0Lu bytes received on the server side." (Cstruct.BE.get_uint64 buf 16));
      Lwt.return_unit
    );
    Lwt.async (fun () -> S.listen s);
    let udp = S.udpv4 s in
    Mclock.connect () >>= fun clock ->
    iperfclient total_size server_ip server_port udp clock

end
