////////////////////////////////////////////////////////////////////////////////
// test_otf_full.sv  —  On-the-Fly with per-step memory observation
// Loads a .hex or .bin, steps 1 cycle at a time (or N), reads a heartbeat
// address after every step, logs changes, detects completion.
////////////////////////////////////////////////////////////////////////////////
module test_otf_full;

    import "DPI-C" context function int  simx_init(int nc, int nw, int nt);
    import "DPI-C" context function int  simx_load_hex(string path);
    import "DPI-C" context function void simx_dcr_write(int addr, int value);
    import "DPI-C" context function int  simx_step(int cycles);
    import "DPI-C" context function int  simx_is_done();
    import "DPI-C" context function int  simx_get_exitcode();
    import "DPI-C" context function void simx_read_mem(longint addr, int size, inout byte data[]);
    import "DPI-C" context function void simx_cleanup();

    // -----------------------------------------------------------------------
    // Configuration — override via plusargs
    // -----------------------------------------------------------------------
    int      num_cores    = 2;
    int      num_warps    = 4;
    int      num_threads  = 4;
    longint  startup_addr = 64'h80000000;
    int      step_size    = 1;        // cycles per simx_step() call
    int      max_cycles   = 500000;
    int      log_interval = 100;      // print status every N steps
    string   hex_file;

    // Result / heartbeat monitoring
    longint  result_addr;             // set per-test (e.g. 0x80010000)
    int      watch_words  = 16;       // how many 32-bit words to watch
    int      watch_size;

    // Runtime state
    int      current_cycle = 0;
    int      step_result;
    int      exitcode;
    byte     prev_result[];
    byte     curr_result[];
    int      change_count  = 0;
    int      total_steps   = 0;

    // -----------------------------------------------------------------------
    initial begin
        $display("============================================================");
        $display("  SimX On-the-Fly Monitor — Per-Cycle Memory Observer");
        $display("============================================================");

        // Plusargs
        void'($value$plusargs("CORES=%d",        num_cores));
        void'($value$plusargs("WARPS=%d",        num_warps));
        void'($value$plusargs("THREADS=%d",      num_threads));
        void'($value$plusargs("STARTUP_ADDR=%h", startup_addr));
        void'($value$plusargs("STEP=%d",         step_size));
        void'($value$plusargs("TIMEOUT=%d",      max_cycles));
        void'($value$plusargs("LOG_INTERVAL=%d", log_interval));
        void'($value$plusargs("WATCH_WORDS=%d",  watch_words));

        if (!$value$plusargs("HEX=%s", hex_file)) begin
            $error("[OTF] No HEX file specified. Use +HEX=<file>");
            $finish(1);
        end
        if (!$value$plusargs("RESULT_ADDR=%h", result_addr)) begin
            $error("[OTF] No result address. Use +RESULT_ADDR=<hex>");
            $finish(1);
        end

        watch_size = watch_words * 4;

        $display("[OTF] HEX file    : %s",   hex_file);
        $display("[OTF] Result addr : 0x%h", result_addr);
        $display("[OTF] Step size   : %0d cycles", step_size);
        $display("[OTF] Max cycles  : %0d", max_cycles);
        $display("[OTF] Watch words : %0d (= %0d bytes)", watch_words, watch_size);

        // Allocate observation buffers
        prev_result = new[watch_size];
        curr_result = new[watch_size];
        foreach (prev_result[i]) prev_result[i] = 8'hFF; // sentinel — all FF

        // Step 1: Init
        $display("\n[OTF] Initializing SimX...");
        if (simx_init(num_cores, num_warps, num_threads) != 0) begin
            $error("[OTF] Init failed"); $finish(1);
        end

        // Step 2: DCR
        simx_dcr_write(32'h001, startup_addr[31:0]);
        if (startup_addr[63:32] != 0)
            simx_dcr_write(32'h002, startup_addr[63:32]);

        // Step 2.5: DCR is already set inside simx_load_hex → just confirm:
        // simx_dcr_write(32'h001, startup_addr[31:0]);    
        
        // Step 3: Load hex
        $display("[OTF] Loading hex: %s", hex_file);
        if (simx_load_hex(hex_file) != 0) begin
            $error("[OTF] Load failed"); simx_cleanup(); $finish(1);
        end

        // Step 4: Execution loop — one step at a time
        $display("\n[OTF] Starting stepped execution...");
        $display("[OTF] Format: [cycle] WORD[n]=<hex> (on each memory change)");
        $display("[OTF] --------------------------------------------------------");

        while (current_cycle < max_cycles) begin

            step_result = simx_step(step_size);
            current_cycle += step_size;
            total_steps++;

            // Read watched memory
            simx_read_mem(result_addr, watch_size, curr_result);

            // Detect and log any word that changed
            for (int w = 0; w < watch_words; w++) begin
                automatic int b = w * 4;
                if (curr_result[b]   !== prev_result[b]   ||
                    curr_result[b+1] !== prev_result[b+1] ||
                    curr_result[b+2] !== prev_result[b+2] ||
                    curr_result[b+3] !== prev_result[b+3]) begin

                    logic [31:0] new_val, old_val;
                    new_val = {curr_result[b+3], curr_result[b+2],
                               curr_result[b+1], curr_result[b]};
                    old_val = {prev_result[b+3], prev_result[b+2],
                               prev_result[b+1], prev_result[b]};

                    $display("[cycle %0d] result[%0d] changed: 0x%08h -> 0x%08h",
                             current_cycle, w, old_val, new_val);
                    change_count++;
                end
            end

            // Update snapshot
            foreach (curr_result[i]) prev_result[i] = curr_result[i];

            // Periodic heartbeat
            if (total_steps % log_interval == 0) begin
                $display("[OTF] ... cycle=%0d, changes_seen=%0d, done=%0d",
                         current_cycle, change_count, simx_is_done());
            end

            // Completion check
            if (step_result == 1 || simx_is_done() == 1) begin
                exitcode = simx_get_exitcode();
                $display("[OTF] --------------------------------------------------------");
                $display("[OTF] Execution COMPLETED at cycle %0d", current_cycle);
                $display("[OTF] Exit code: %0d", exitcode);
                $display("[OTF] Total memory changes observed: %0d", change_count);
                break;
            end

            if (step_result == -1) begin
                $error("[OTF] simx_step returned error at cycle %0d", current_cycle);
                break;
            end

            #1; // advance sim time
        end

        if (current_cycle >= max_cycles)
            $warning("[OTF] TIMEOUT at %0d cycles", max_cycles);

        // Final dump of watched region
        $display("\n[OTF] === Final memory dump at 0x%h ===", result_addr);
        for (int w = 0; w < watch_words; w++) begin
            automatic int b = w * 4;
            logic [31:0] val;
            val = {curr_result[b+3], curr_result[b+2],
                   curr_result[b+1], curr_result[b]};
            $display("[OTF]   [%02d] 0x%h + %0d = 0x%08h  (%0d)",
                     w, result_addr, w*4, val, $signed(val));
        end

        #100;
        simx_cleanup();
        $display("\n[OTF] Test %s (cycles=%0d)",
                 (exitcode == 0) ? "PASSED" : "FAILED", current_cycle);
        $finish(exitcode);
    end

endmodule