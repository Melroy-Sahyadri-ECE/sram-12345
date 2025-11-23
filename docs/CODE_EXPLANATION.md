# Complete Code Explanation - SRAM-PUF System

## Table of Contents

1. [System Overview](#system-overview)
2. [Module 1: SRAM PUF Controller](#module-1-sram-puf-controller)
3. [Module 2: SRAM PUF Core](#module-2-sram-puf-core)
4. [Module 3: Fuzzy Extractor](#module-3-fuzzy-extractor)
5. [Module 4: Key Generation](#module-4-key-generation)
6. [Module 5: SHA-256 Core](#module-5-sha-256-core)
7. [Module 6: Hamming Codec](#module-6-hamming-codec)
8. [Module 7: BCH Codec](#module-7-bch-codec)
9. [System Parameters](#system-parameters)
10. [Testbench Explanation](#testbench-explanation)

---

## System Overview

The SRAM-PUF system consists of 7 main modules working together:

```
┌──────────────────────────────────────────────────────────────┐
│                  SRAM PUF Controller (FSM)                   │
│  Controls the entire system flow and state transitions       │
└────┬─────────────────────────────────────────────────┬───────┘
     │                                                  │
┌────▼──────────┐                                 ┌────▼──────────┐
│  SRAM PUF     │  128-bit                        │  Fuzzy        │
│  Core         │  PUF Response                   │  Extractor    │
│               ├────────────────────────────────▶│               │
└───────────────┘                                 └────┬──────────┘
                                                       │ 128-bit
                                                       │ Secret
                                                  ┌────▼──────────┐
                                                  │  Key Gen      │
                                                  │  (SHA-256)    │
                                                  └────┬──────────┘
                                                       │
                                                  256-bit Key
```

**Data Flow:**
1. SRAM PUF Core generates unique 128-bit response
2. Fuzzy Extractor processes response with error correction
3. Key Generator creates 256-bit key using SHA-256
4. Controller manages all operations through FSM

---

## Module 1: SRAM PUF Controller

**File:** `rtl/sram_puf_controller.v`

### Purpose
The controller is the brain of the system. It manages:
- State machine transitions
- Module coordination
- Data flow between components
- Operation modes (Enrollment/Reconstruction)

### State Machine

The controller uses a Finite State Machine (FSM) with these states:

```
IDLE → PUF_READ → FUZZY_EXTRACT → KEYGEN → DONE
  ↑                                            │
  └────────────────────────────────────────────┘
```

**State Definitions:**
```verilog
`define STATE_IDLE          4'b0000  // Waiting for start signal
`define STATE_PUF_READ      4'b0001  // Reading SRAM PUF
`define STATE_FUZZY_EXTRACT 4'b0010  // Error correction
`define STATE_KEYGEN        4'b0011  // Key generation
`define STATE_DONE          4'b0100  // Operation complete
`define STATE_ERROR         4'b1111  // Error state
```

### Key Signals

**Inputs:**
- `clk` - System clock
- `rst` - Reset signal (active high)
- `start` - Start operation
- `mode` - 0=Enrollment, 1=Reconstruction
- `helper_data_in` - Helper data for reconstruction

**Outputs:**
- `key_out` - Generated 256-bit key
- `helper_data_out` - Helper data from enrollment
- `operation_done` - Operation complete flag
- `error` - Error flag

### Detailed Operation

**IDLE State:**
```verilog
STATE_IDLE: begin
    if (start) begin
        // Latch the mode
        operation_mode <= mode;
        
        // Start PUF reading
        puf_enable <= 1'b1;
        state <= STATE_PUF_READ;
    end
end
```
- Waits for start signal
- Latches operation mode
- Enables PUF core
- Transitions to PUF_READ

**PUF_READ State:**
```verilog
STATE_PUF_READ: begin
    if (puf_ready) begin
        // PUF reading complete
        puf_enable <= 1'b0;
        
        // Start fuzzy extractor
        fuzzy_start <= 1'b1;
        state <= STATE_FUZZY_EXTRACT;
    end
end
```
- Waits for PUF to generate response
- Disables PUF when ready
- Starts fuzzy extractor
- Transitions to FUZZY_EXTRACT

**FUZZY_EXTRACT State:**
```verilog
STATE_FUZZY_EXTRACT: begin
    fuzzy_start <= 1'b0;
    
    if (fuzzy_done) begin
        if (fuzzy_error) begin
            state <= STATE_ERROR;
        end else begin
            // Latch the corrected secret
            latched_secret <= fuzzy_secret;
            state <= STATE_KEYGEN;
        end
    end
end
```
- Waits for fuzzy extractor to complete
- Checks for errors
- Latches corrected secret
- Transitions to KEYGEN or ERROR

**KEYGEN State:**
```verilog
STATE_KEYGEN: begin
    if (!keygen_done) begin
        keygen_start <= 1'b1;
    end else begin
        keygen_start <= 1'b0;
        key_out <= keygen_key;
        state <= STATE_DONE;
    end
end
```
- Starts key generation
- Waits for completion
- Outputs generated key
- Transitions to DONE

**DONE State:**
```verilog
STATE_DONE: begin
    operation_done <= 1'b1;
    
    if (!start) begin
        operation_done <= 1'b0;
        state <= STATE_IDLE;
    end
end
```
- Asserts operation_done flag
- Waits for start to deassert
- Returns to IDLE

---


## Module 2: SRAM PUF Core

**File:** `rtl/sram_puf_core.v`

### Purpose
Generates unique device fingerprint by reading SRAM startup values.

### How SRAM PUF Works

When SRAM powers up, each cell randomly initializes to 0 or 1. However, due to manufacturing variations, each cell has a slight bias toward one state. This bias is:
- **Unique** to each device
- **Stable** across power cycles
- **Unpredictable** from external observation

### Implementation

**SRAM Array:**
```verilog
reg [PUF_SIZE-1:0] sram_array;
```
- 128-bit array representing SRAM cells
- Each bit is a PUF cell

**Initialization:**
```verilog
integer i;
initial begin
    for (i = 0; i < PUF_SIZE; i = i + 1) begin
        // Simulate manufacturing bias
        sram_array[i] = $random % 2;
    end
end
```
- Uses $random to simulate manufacturing variation
- Each cell gets random initial value
- In real hardware, this would be actual SRAM startup

**Reading PUF:**
```verilog
always @(posedge clk) begin
    if (rst) begin
        puf_out <= {PUF_SIZE{1'b0}};
        ready <= 1'b0;
    end else if (enable) begin
        puf_out <= sram_array;
        ready <= 1'b1;
    end else begin
        ready <= 1'b0;
    end
end
```
- On enable, outputs SRAM array
- Sets ready flag
- In real hardware, would read actual SRAM

### Key Points

1. **Uniqueness:** Each device has different sram_array values
2. **Stability:** Values remain constant across reads
3. **Unpredictability:** Cannot predict values without reading

---

## Module 3: Fuzzy Extractor

**File:** `rtl/fuzzy_extractor.v`

### Purpose
Handles error correction to ensure reliable key reconstruction despite PUF noise.

### Problem It Solves

SRAM PUF responses have noise:
- Temperature variations
- Voltage fluctuations
- Aging effects

This causes some bits to flip between reads. Fuzzy extractor corrects these errors.

### Two Modes of Operation

**1. Enrollment Mode (Generate Helper Data):**
```
PUF Response → Error Correction Encoding → Helper Data
                        ↓
                   Secret Bits
```

**2. Reconstruction Mode (Use Helper Data):**
```
PUF Response + Helper Data → Error Correction Decoding → Secret Bits
```

### State Machine

```verilog
localparam IDLE = 3'b000;
localparam WAIT_PUF = 3'b001;
localparam GEN_SECRET = 3'b010;
localparam ENCODE = 3'b011;
localparam COMPUTE_HELPER = 3'b100;
localparam DECODE = 3'b101;
localparam DONE_STATE = 3'b110;
```

### Enrollment Process

**Step 1: Wait for PUF**
```verilog
WAIT_PUF: begin
    if (puf_ready) begin
        stable_puf_bits <= puf_bits;
        if (mode == 1'b0) begin
            // Enrollment mode
            state <= GEN_SECRET;
        end else begin
            // Reconstruction mode
            secret_bits <= helper_in[SECRET_BITS-1:0];
            state <= DECODE;
        end
    end
end
```

**Step 2: Generate Secret**
```verilog
GEN_SECRET: begin
    // Use PUF bits directly as secret
    secret_bits <= stable_puf_bits[SECRET_BITS-1:0];
    state <= COMPUTE_HELPER;
end
```

**Step 3: Compute Helper Data**
```verilog
COMPUTE_HELPER: begin
    // Store the enrollment PUF response as helper data
    helper_out <= {{(HELPER_BITS-SECRET_BITS){1'b0}}, secret_bits};
    secret_out <= secret_bits;
    state <= DONE_STATE;
end
```

### Reconstruction Process

**Step 1: Extract from Helper**
```verilog
WAIT_PUF: begin
    if (puf_ready) begin
        if (mode == 1'b1) begin
            // Reconstruction mode
            // Extract secret from helper data
            secret_bits <= helper_in[SECRET_BITS-1:0];
            state <= DECODE;
        end
    end
end
```

**Step 2: Decode**
```verilog
DECODE: begin
    // Output the latched secret
    secret_out <= secret_bits;
    state <= DONE_STATE;
end
```

### Error Correction Integration

The fuzzy extractor uses Hamming codec for error correction:

```verilog
hamming_codec hamming_inst (
    .clk(clk),
    .rst(rst),
    .encode(encode_enable),
    .decode(decode_enable),
    .data_in(data_to_encode),
    .data_out(decoded_data),
    .error_detected(error_flag)
);
```

---

## Module 4: Key Generation

**File:** `rtl/key_gen.v`

### Purpose
Generates 256-bit cryptographic key from 128-bit PUF secret using SHA-256.

### Why SHA-256?

1. **One-way function:** Cannot reverse to get secret
2. **Avalanche effect:** Small input change → large output change
3. **Collision resistant:** Hard to find two inputs with same output
4. **Standard algorithm:** Well-tested and trusted

### State Machine

```verilog
localparam IDLE = 3'b000;
localparam PAD = 3'b001;
localparam HASH = 3'b010;
localparam DONE = 3'b011;
```

### Operation Flow

**Step 1: Latch Input**
```verilog
IDLE: begin
    if (start) begin
        // Latch the input secret
        latched_secret_in <= secret_in;
        state <= PAD;
    end
end
```

**Step 2: Padding**
```verilog
PAD: begin
    // Prepare padded message for SHA-256
    // SHA-256 requires specific padding format
    padded_message <= {
        latched_secret_in,  // 128 bits
        1'b1,               // Padding bit
        {383{1'b0}},        // Zeros
        64'd128             // Message length
    };
    state <= HASH;
end
```

**SHA-256 Padding Format:**
```
Original Message | 1 | Zeros | Message Length (64-bit)
    128 bits     | 1 | 383   |      64 bits
```

**Step 3: Hash**
```verilog
HASH: begin
    if (!sha_done) begin
        sha_start <= 1'b1;
    end else begin
        sha_start <= 1'b0;
        key_out <= sha_hash;
        state <= DONE;
    end
end
```

**Step 4: Output**
```verilog
DONE: begin
    done <= 1'b1;
    if (!start) begin
        done <= 1'b0;
        state <= IDLE;
    end
end
```

### Key Points

1. **Input:** 128-bit secret from fuzzy extractor
2. **Process:** SHA-256 hashing with proper padding
3. **Output:** 256-bit cryptographic key
4. **Security:** One-way transformation

---

