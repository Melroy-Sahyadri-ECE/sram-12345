`timescale 1ns / 1ps
// ============================================================================
// SRAM PUF Controller — Top Level (Simplified)
//
// 6-state FSM that coordinates:
//   Enrollment:     Read PUF → Fuzzy Extract → SHA-256 Key Gen → Done
//   Reconstruction: Read PUF → Fuzzy Decode  → SHA-256 Key Gen → Done
// ============================================================================

`include "sram_puf_params.vh"

module sram_puf_controller #(
    parameter N           = `PUF_SIZE,
    parameter SECRET_BITS = `SECRET_BITS,
    parameter HELPER_BITS = `HELPER_BITS
)(
    input  wire                    clk,
    input  wire                    rst,
    input  wire                    start_enroll,
    input  wire                    start_reconstruct,
    input  wire  [HELPER_BITS-1:0] helper_data_in,
    output reg                     operation_done,
    output reg   [255:0]           key_out,
    output reg   [HELPER_BITS-1:0] helper_data_out,
    output reg                     error_flag
);

    // ========================================================================
    // FSM State Register
    // ========================================================================
    reg [2:0] state;
    reg       mode;       // 0 = enroll, 1 = reconstruct

    // ========================================================================
    // Sub-module Wires
    // ========================================================================

    // PUF Core
    reg              puf_rst;
    reg              puf_read_en;
    wire             puf_read_done;
    wire [N-1:0]     puf_response;

    // Fuzzy Extractor
    reg              fuzzy_start;
    wire             fuzzy_done;
    wire             fuzzy_error;
    wire [SECRET_BITS-1:0] fuzzy_secret;
    wire [HELPER_BITS-1:0] fuzzy_helper;

    // Key Generator
    reg              keygen_start;
    wire             keygen_done;
    wire [255:0]     keygen_key;

    // Latched secret for key generation
    reg [SECRET_BITS-1:0] latched_secret;

    // ========================================================================
    // Sub-module Instances
    // ========================================================================

    sram_puf_core #(.N(N)) puf_inst (
        .clk          (clk),
        .rst          (puf_rst),
        .read_enable  (puf_read_en),
        .enable_noise (1'b0),           // No noise in default config
        .read_done    (puf_read_done),
        .puf_response (puf_response)
    );

    fuzzy_extractor #(
        .PUF_BITS    (N),
        .SECRET_BITS (SECRET_BITS),
        .HELPER_BITS (HELPER_BITS)
    ) fuzzy_inst (
        .clk         (clk),
        .rst         (rst),
        .mode        (mode),
        .start       (fuzzy_start),
        .puf_in      (puf_response),
        .helper_in   (helper_data_in),
        .secret_out  (fuzzy_secret),
        .helper_out  (fuzzy_helper),
        .error_flag  (fuzzy_error),
        .done        (fuzzy_done)
    );

    key_gen #(.SECRET_BITS(SECRET_BITS)) keygen_inst (
        .clk        (clk),
        .rst        (rst),
        .start      (keygen_start),
        .secret_in  (latched_secret),
        .key_out    (keygen_key),
        .done       (keygen_done)
    );

    // ========================================================================
    // Main FSM (6 states only)
    // ========================================================================

    always @(posedge clk) begin
        if (rst) begin
            state          <= `S_IDLE;
            operation_done <= 1'b0;
            error_flag     <= 1'b0;
            key_out        <= 256'b0;
            helper_data_out<= {HELPER_BITS{1'b0}};
            latched_secret <= {SECRET_BITS{1'b0}};
            puf_rst        <= 1'b0;
            puf_read_en    <= 1'b0;
            fuzzy_start    <= 1'b0;
            keygen_start   <= 1'b0;
            mode           <= 1'b0;
        end
        else begin
            case (state)

                // ----- Wait for command -----
                `S_IDLE: begin
                    operation_done <= 1'b0;
                    error_flag     <= 1'b0;

                    if (start_enroll) begin
                        mode    <= 1'b0;            // Enrollment
                        puf_rst <= 1'b1;            // Trigger SRAM power-up
                        state   <= `S_READ_PUF;
                    end
                    else if (start_reconstruct) begin
                        mode    <= 1'b1;            // Reconstruction
                        puf_rst <= 1'b1;
                        state   <= `S_READ_PUF;
                    end
                end

                // ----- Read PUF response -----
                `S_READ_PUF: begin
                    puf_rst    <= 1'b0;             // Release reset
                    puf_read_en <= 1'b1;            // Start readout

                    if (puf_read_done) begin
                        puf_read_en <= 1'b0;
                        state       <= `S_FUZZY;
                    end
                end

                // ----- Fuzzy extract / reconstruct -----
                `S_FUZZY: begin
                    if (!fuzzy_done) begin
                        fuzzy_start <= 1'b1;
                    end else begin
                        fuzzy_start <= 1'b0;

                        if (fuzzy_error) begin
                            error_flag <= 1'b1;
                            state      <= `S_ERROR;
                        end else begin
                            helper_data_out <= fuzzy_helper;
                            latched_secret  <= fuzzy_secret;
                            state           <= `S_KEYGEN;
                        end
                    end
                end

                // ----- SHA-256 key generation -----
                `S_KEYGEN: begin
                    if (!keygen_done) begin
                        keygen_start <= 1'b1;
                    end else begin
                        keygen_start <= 1'b0;
                        key_out      <= keygen_key;
                        state        <= `S_DONE;
                    end
                end

                // ----- Success -----
                `S_DONE: begin
                    operation_done <= 1'b1;
                    if (!start_enroll && !start_reconstruct)
                        state <= `S_IDLE;
                end

                // ----- Error -----
                `S_ERROR: begin
                    operation_done <= 1'b1;
                    error_flag     <= 1'b1;
                    if (!start_enroll && !start_reconstruct)
                        state <= `S_IDLE;
                end

                default: state <= `S_IDLE;
            endcase
        end
    end

endmodule
