`timescale 1ns / 1ps
// ============================================================================
// SRAM PUF Core (Simplified)
//
// Simulates SRAM power-up behavior:
//   - Each cell has a fixed bias (manufacturing variation)
//   - On reset, cells initialize based on bias
//   - Optional noise flips some bits (simulates real-world noise)
//   - Instant parallel readout (no serial scanning)
// ============================================================================

`include "sram_puf_params.vh"

module sram_puf_core #(
    parameter N = `PUF_SIZE
)(
    input  wire         clk,
    input  wire         rst,            // Power-up reset
    input  wire         read_enable,    // Start readout
    input  wire         enable_noise,   // Enable noise injection
    output reg          read_done,      // Readout complete
    output reg  [N-1:0] puf_response   // PUF output (all cells)
);

    // SRAM cell storage
    reg [N-1:0] sram_cells;

    // ========================================================================
    // Bias Function: deterministic "manufacturing variation" per cell
    // Returns an 8-bit value; cells with bias > 128 tend to power-up as '1'
    // ========================================================================
    function [7:0] cell_bias;
        input integer idx;
        reg [31:0] tmp;
        begin
            tmp = idx * 214013 + 2531011;       // LCG step 1
            tmp = tmp ^ (tmp >> 16);
            tmp = tmp * 1103515245 + 12345;     // LCG step 2
            cell_bias = tmp[7:0];
        end
    endfunction

    // ========================================================================
    // Power-Up: each cell settles to 0 or 1 based on its bias
    // ========================================================================
    integer i;

    always @(posedge rst) begin
        for (i = 0; i < N; i = i + 1) begin
            if (cell_bias(i) > 8'd128)
                sram_cells[i] <= 1'b1;
            else
                sram_cells[i] <= 1'b0;
        end
    end

    // ========================================================================
    // Readout: output all cells in one clock cycle
    // ========================================================================
    reg [N-1:0] noise_mask;

    always @(posedge clk) begin
        if (rst) begin
            read_done    <= 1'b0;
            puf_response <= {N{1'b0}};
        end
        else if (read_enable && !read_done) begin
            if (enable_noise) begin
                // Generate noise: ~4% of bits flip
                // Build noise mask from multiple $urandom calls
                for (i = 0; i < N; i = i + 1) begin
                    // Each bit has ~4% chance of being 1 (flip)
                    noise_mask[i] = ($urandom % 256) < 10;  // 10/256 ≈ 4%
                end
                puf_response <= sram_cells ^ noise_mask;
            end else begin
                puf_response <= sram_cells;   // Clean readout
            end
            read_done <= 1'b1;
        end
        else if (!read_enable) begin
            read_done <= 1'b0;                // Reset for next read
        end
    end

endmodule
