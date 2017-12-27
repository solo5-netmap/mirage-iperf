open Lwt.Infix

type stats = {
  mutable bytes: int64;
  mutable start_time: int64;
  mutable last_time: int64;
}

module Main (S: Mirage_types_lwt.STACKV4) (Time : Mirage_types_lwt.TIME) = struct

  let server_ip = Ipaddr.V4.of_string_exn "192.168.112.105"
  let server_port = 5001
  let client_port = 5002
  let total_size = 3_000_000_000
  let blen = 1024

  let msg =
    "01234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789001234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890"

  let mlen =
    if blen <= (String.length msg) then blen
    else (String.length msg)

  let print_gc_stat () =
    let gc_stat = Gc.stat () in
    Logs.info (fun f -> f  "minor_words: %f" gc_stat.minor_words);
    Logs.info (fun f -> f  "promoted-words: %f" gc_stat.promoted_words);
    Logs.info (fun f -> f  "major-words: %f" gc_stat.major_words);
    Logs.info (fun f -> f  "minor_collections: %d" gc_stat.minor_collections);
    Logs.info (fun f -> f  "major_collections: %d" gc_stat.major_collections);
    Logs.info (fun f -> f  "heap_words: %d" gc_stat.heap_words);
    Logs.info (fun f -> f  "heap_chunks: %d" gc_stat.heap_chunks);
    Logs.info (fun f -> f  "live_words: %d" gc_stat.live_words);
    Logs.info (fun f -> f  "live_blocks: %d" gc_stat.live_blocks);
    Logs.info (fun f -> f  "free_words: %d" gc_stat.free_words);
    Logs.info (fun f -> f  "free_blocks: %d" gc_stat.free_blocks);
    Logs.info (fun f -> f  "largest_free: %d" gc_stat.largest_free);
    Logs.info (fun f -> f  "fragments: %d" gc_stat.fragments);
    Logs.info (fun f -> f  "compactions: %d" gc_stat.compactions);
    Logs.info (fun f -> f  "top_heap_words: %d" gc_stat.top_heap_words);
    Logs.info (fun f -> f  "stack_size: %d" gc_stat.stack_size);
    Lwt.return_unit

  let print_data st ts_now =
    let duration = Int64.sub ts_now st.start_time in
    let rate = (Int64.float_of_bits st.bytes) /. (Int64.float_of_bits duration) *. 1000. *. 1000. *. 1000. in
    Logs.info (fun f -> f  "iperf client: Duration = %.0Lu [ns] (start_t = %.0Lu, end_t = %.0Lu),  Data received = %Ld [bytes], Throughput = %.2f [bytes/sec]" duration st.start_time ts_now st.bytes rate);
    Logs.info (fun f -> f  "iperf client: Throughput = %.2f [MBs/sec]"  (rate /. 1000000.));
    Lwt.return_unit

  let write_and_check ip port udp buf =
    S.UDPV4.write ~src_port:client_port ~dst:ip ~dst_port:port udp buf >|= Rresult.R.get_ok

  let iperfclient amt dest_ip dport udp clock =
    Logs.info (fun f -> f  "iperf client: Trying to connect to a server at %s:%d, buffer size = %d" (Ipaddr.V4.to_string server_ip) server_port mlen);
    Logs.info (fun f -> f  "iperf client: %.0d bytes data transfer initiated." amt);

    (* Prepare data used *)
    let a = Cstruct.sub (Io_page.(to_cstruct (get 1))) 0 mlen in
    let start = Cstruct.sub (Io_page.(to_cstruct (get 1))) 0 1 in
    let stop = Cstruct.sub (Io_page.(to_cstruct (get 1))) 0 2 in
    Cstruct.blit_from_string msg 0 a 0 mlen;
    Cstruct.blit_from_string msg 0 start 0 1;
    Cstruct.blit_from_string msg 0 stop 0 2;

    (* Loop definition *)
    let rec loop = function
      | 0 -> Lwt.return_unit
      | n ->
        write_and_check dest_ip dport udp a >>= fun () -> loop (n-1)
    in

    (* Send a parcket to start *)
    write_and_check dest_ip dport udp start >>= fun () ->

    (* Conduct the main evaluation *)
    let t0 = Mclock.elapsed_ns clock in
    let st = {
      bytes=0L; start_time = t0; last_time = t0
    } in
    loop (amt / mlen) >>= fun () ->
    let a = Cstruct.sub a 0 (amt - (mlen * (amt/mlen))) in
    write_and_check dest_ip dport udp a >>= fun () ->
    let tnow = Mclock.elapsed_ns clock in
    st.bytes <- Int64.of_int total_size;

    (* Send a parcket to finish *)
    write_and_check dest_ip dport udp stop >>= fun () ->

    (* Print the obtained result *)
    print_data st tnow >>= fun () ->
    print_gc_stat () >>= fun () ->
    Logs.info (fun f -> f  "iperf client: Done.");

    Time.sleep_ns (Duration.of_sec 3) >>= fun () ->
    Lwt.return_unit

  let start s _time =
    (*Gc.set { (Gc.get()) with Gc.minor_heap_size = 32768}; *)
    let c = Gc.get() in
    Logs.info (fun f -> f "minor_heap_size: %d" c.minor_heap_size);
    Time.sleep_ns (Duration.of_sec 1) >>= fun () -> (* Give server 1.0 s to call listen *)
    S.listen_udpv4 s ~port:client_port (fun ~src ~dst ~src_port buf ->
      Logs.info (fun f -> f "iperf client: The server side received %.0Lu Bytes" (Int64.of_string (Cstruct.to_string buf)));
      Lwt.return_unit
    );
    Lwt.async (fun () -> S.listen s);
    let udp = S.udpv4 s in
    Mclock.connect () >>= fun clock ->
    iperfclient total_size server_ip server_port udp clock
end

