`timescale 1ns / 1ps
// ============================================================================
// Testbench for Simplified SRAM-PUF System
//
// Tests: Enrollment → Reconstruction → Multiple Reconstructions
// ============================================================================

module tb_sram_puf_top;

    // Parameters (match simplified design)
    parameter CLK_PERIOD  = 10;     // 100 MHz
    parameter SECRET_BITS = 128;
    parameter HELPER_BITS = 128;

    // Signals
    reg          clk;
    reg          rst;
    reg          start_enroll;
    reg          start_reconstruct;
    reg  [HELPER_BITS-1:0] helper_data_in;
    wire         operation_done;
    wire [255:0] key_out;
    wire [HELPER_BITS-1:0] helper_data_out;
    wire         error_flag;

    // Storage for comparing keys
    reg [HELPER_BITS-1:0] stored_helper;
    reg [255:0]           enrollment_key;
    integer               timeout;

    // ========================================================================
    // DUT
    // ========================================================================
    sram_puf_controller #(
        .N          (128),
        .SECRET_BITS(SECRET_BITS),
        .HELPER_BITS(HELPER_BITS)
    ) dut (
        .clk               (clk),
        .rst               (rst),
        .start_enroll       (start_enroll),
        .start_reconstruct  (start_reconstruct),
        .helper_data_in     (helper_data_in),
        .operation_done     (operation_done),
        .key_out            (key_out),
        .helper_data_out    (helper_data_out),
        .error_flag         (error_flag)
    );

    // ========================================================================
    // Clock
    // ========================================================================
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // ========================================================================
    // Test Sequence
    // ========================================================================
    initial begin
        $display("========================================");
        $display("SRAM-PUF System Testbench (Simplified)");
        $display("========================================");

        // Reset
        rst = 1;  start_enroll = 0;  start_reconstruct = 0;
        helper_data_in = {HELPER_BITS{1'b0}};
        #(CLK_PERIOD * 5);
        rst = 0;
        #(CLK_PERIOD * 5);

        // ==================================================================
        // TEST 1: Enrollment
        // ==================================================================
        $display("\n[TEST 1] Starting Enrollment...");
        start_enroll = 1;
        #(CLK_PERIOD);
        start_enroll = 0;

        // Wait for completion
        timeout = 0;
        while (!operation_done && timeout < 50000) begin
            #(CLK_PERIOD);
            timeout = timeout + 1;
        end

        if (timeout >= 50000) begin
            $display("[ERROR] Enrollment timeout!");
            $finish;
        end

        #(CLK_PERIOD * 2);

        if (error_flag) begin
            $display("[ERROR] Enrollment failed!");
            $finish;
        end else begin
            $display("[PASS] Enrollment completed successfully");
            $display("  Helper Data: %h", helper_data_out);
            $display("  Key Output:  %h", key_out);
            stored_helper  = helper_data_out;
            enrollment_key = key_out;
        end

        #(CLK_PERIOD * 10);

        // ==================================================================
        // TEST 2: Reconstruction
        // ==================================================================
        $display("\n[TEST 2] Starting Reconstruction...");
        helper_data_in    = stored_helper;
        start_reconstruct = 1;
        #(CLK_PERIOD);
        start_reconstruct = 0;

        timeout = 0;
        while (!operation_done && timeout < 50000) begin
            #(CLK_PERIOD);
            timeout = timeout + 1;
        end

        if (timeout >= 50000) begin
            $display("[ERROR] Reconstruction timeout!");
            $finish;
        end

        #(CLK_PERIOD * 2);

        if (error_flag) begin
            $display("[ERROR] Reconstruction failed!");
        end else begin
            $display("[PASS] Reconstruction completed successfully");
            $display("  Key Output: %h", key_out);

            if (key_out == enrollment_key)
                $display("[PASS] Keys match! PUF system working correctly.");
            else begin
                $display("[WARN] Keys differ!");
                $display("  Enrollment Key:     %h", enrollment_key);
                $display("  Reconstruction Key: %h", key_out);
            end
        end

        #(CLK_PERIOD * 10);

        // ==================================================================
        // TEST 3: Multiple Reconstructions
        // ==================================================================
        $display("\n[TEST 3] Testing multiple reconstructions...");

        repeat (3) begin
            while (operation_done) #(CLK_PERIOD);
            #(CLK_PERIOD * 5);

            helper_data_in    = stored_helper;
            start_reconstruct = 1;
            #(CLK_PERIOD);
            start_reconstruct = 0;

            timeout = 0;
            while (!operation_done && timeout < 50000) begin
                #(CLK_PERIOD);
                timeout = timeout + 1;
            end

            if (!error_flag && timeout < 50000)
                $display("  Reconstruction Key: %h", key_out);
            #(CLK_PERIOD * 10);
        end

        $display("\n========================================");
        $display("Testbench Complete");
        $display("========================================");
        $finish;
    end

    // Global timeout
    initial begin
        #(CLK_PERIOD * 1000000);
        $display("[ERROR] Global timeout!");
        $finish;
    end

endmodule
