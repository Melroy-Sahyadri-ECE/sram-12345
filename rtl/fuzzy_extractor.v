`timescale 1ns / 1ps
// ============================================================================
// Fuzzy Extractor (Simplified)
//
// Enrollment:     Takes PUF bits → stores as secret + helper data
// Reconstruction: Recovers secret from stored helper data
//
// This is a simplified "secure sketch" — in production you'd XOR with
// an error-correcting codeword for noise tolerance.
// ============================================================================

`include "sram_puf_params.vh"

module fuzzy_extractor #(
    parameter PUF_BITS    = `PUF_SIZE,
    parameter SECRET_BITS = `SECRET_BITS,
    parameter HELPER_BITS = `HELPER_BITS
)(
    input  wire                     clk,
    input  wire                     rst,
    input  wire                     mode,       // 0 = enroll, 1 = reconstruct
    input  wire                     start,
    input  wire  [PUF_BITS-1:0]    puf_in,     // PUF response
    input  wire  [HELPER_BITS-1:0] helper_in,  // Stored helper data (for reconstruction)
    output reg   [SECRET_BITS-1:0] secret_out,
    output reg   [HELPER_BITS-1:0] helper_out,
    output reg                     error_flag,
    output reg                     done
);

    // 3-state FSM
    reg [1:0] state;
    localparam IDLE    = 2'd0;
    localparam PROCESS = 2'd1;
    localparam DONE_ST = 2'd2;

    always @(posedge clk) begin
        if (rst) begin
            state      <= IDLE;
            done       <= 1'b0;
            error_flag <= 1'b0;
            secret_out <= {SECRET_BITS{1'b0}};
            helper_out <= {HELPER_BITS{1'b0}};
        end
        else begin
            case (state)

                IDLE: begin
                    if (start) begin
                        state <= PROCESS;
                    end
                end

                PROCESS: begin
                    if (mode == 1'b0) begin
                        // --- ENROLLMENT ---
                        // Use PUF bits directly as the secret
                        secret_out <= puf_in[SECRET_BITS-1:0];
                        // Store secret as helper data
                        helper_out <= puf_in[HELPER_BITS-1:0];
                    end
                    else begin
                        // --- RECONSTRUCTION ---
                        // Recover secret from helper data
                        secret_out <= helper_in[SECRET_BITS-1:0];
                        helper_out <= helper_in;
                    end
                    error_flag <= 1'b0;
                    state      <= DONE_ST;
                end

                DONE_ST: begin
                    done <= 1'b1;
                    if (!start) begin
                        done       <= 1'b0;
                        error_flag <= 1'b0;
                        state      <= IDLE;
                    end
                end

            endcase
        end
    end

endmodule
