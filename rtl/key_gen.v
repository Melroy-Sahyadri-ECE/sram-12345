`timescale 1ns / 1ps
// ============================================================================
// Key Generator (Simplified)
//
// Pads the secret to 512 bits (SHA-256 padding) and hashes it.
// Input:  128-bit secret
// Output: 256-bit cryptographic key
// ============================================================================

`include "sram_puf_params.vh"

module key_gen #(
    parameter SECRET_BITS = `SECRET_BITS
)(
    input  wire                    clk,
    input  wire                    rst,
    input  wire                    start,
    input  wire [SECRET_BITS-1:0]  secret_in,
    output reg  [255:0]            key_out,
    output reg                     done
);

    // SHA-256 signals
    reg  [511:0] padded_msg;
    reg          sha_start;
    wire [255:0] sha_hash;
    wire         sha_done;

    sha256_core sha_inst (
        .clk           (clk),
        .rst           (rst),
        .start         (sha_start),
        .message_block (padded_msg),
        .hash_out      (sha_hash),
        .done          (sha_done)
    );

    // Simple 3-state FSM
    reg [1:0] state;
    localparam IDLE = 2'd0;
    localparam HASH = 2'd1;
    localparam DONE_ST = 2'd2;

    always @(posedge clk) begin
        if (rst) begin
            state      <= IDLE;
            done       <= 1'b0;
            sha_start  <= 1'b0;
            key_out    <= 256'b0;
            padded_msg <= 512'b0;
        end
        else begin
            case (state)

                IDLE: begin
                    if (start) begin
                        // SHA-256 padding: secret || 1 || zeros || length(64-bit)
                        padded_msg <= { secret_in,
                                        1'b1,
                                        {(512 - SECRET_BITS - 1 - 64){1'b0}},
                                        64'd0 + SECRET_BITS };
                        sha_start <= 1'b1;
                        state     <= HASH;
                    end
                end

                HASH: begin
                    sha_start <= 1'b0;
                    if (sha_done) begin
                        key_out <= sha_hash;
                        done    <= 1'b1;
                        state   <= DONE_ST;
                    end
                end

                DONE_ST: begin
                    if (!start) begin
                        done  <= 1'b0;
                        state <= IDLE;
                    end
                end

            endcase
        end
    end

endmodule
