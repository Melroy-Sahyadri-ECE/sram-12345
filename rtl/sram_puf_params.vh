// ============================================================================
// SRAM-PUF System Parameters (Simplified)
// ============================================================================

`ifndef SRAM_PUF_PARAMS_VH
`define SRAM_PUF_PARAMS_VH

// PUF Configuration
`define PUF_SIZE            128     // Number of SRAM cells
`define SECRET_BITS         128     // Secret size (same as PUF)
`define HELPER_BITS         128     // Helper data size
`define KEY_BITS            256     // Output key size (SHA-256)

// Hamming(7,4) Parameters
`define HAMMING_N           7
`define HAMMING_K           4

// SHA-256 Parameters
`define SHA256_BLOCK_WIDTH  512

// FSM States (simplified - 6 states)
`define S_IDLE              3'd0
`define S_READ_PUF          3'd1
`define S_FUZZY             3'd2
`define S_KEYGEN            3'd3
`define S_DONE              3'd4
`define S_ERROR             3'd5

`endif
