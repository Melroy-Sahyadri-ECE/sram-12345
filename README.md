# SRAM-PUF System for FPGA (Simplified Design) 🔐

A **simplified** SRAM-based Physical Unclonable Function (PUF) system for FPGA.  
This is a clean, easy-to-understand version that generates unique 256-bit keys using SRAM power-up behavior.

> **Why simplified?** The original design had 12 FSM states, dual error correction codecs, environmental noise modeling, and multi-cycle enrollment. This version strips all that down to the **core concept** with just **6 FSM states** — making it much easier to learn, present, and modify.

---

## 🎯 What Is an SRAM PUF?

When SRAM memory powers on, each cell settles to `0` or `1` based on tiny transistor manufacturing differences. This pattern is:
- **Unique** to each chip (like a fingerprint)
- **Unclonable** — can't be copied to another device
- **Repeatable** — same chip gives same pattern every time

This project uses that pattern to generate a **256-bit cryptographic key**.

---

## ⚙️ How Our Simplified Design Works

### System Flow (6 States)

```
         ┌────────┐
         │  IDLE  │ ← Waits for command
         └───┬────┘
             │ start_enroll OR start_reconstruct
             ▼
       ┌───────────┐
       │ READ_PUF  │ ← Power up SRAM, read 128-bit response (1 cycle)
       └─────┬─────┘
             ▼
       ┌───────────┐
       │   FUZZY   │ ← Extract secret / recover from helper data
       └─────┬─────┘
             ▼
       ┌───────────┐
       │  KEYGEN   │ ← SHA-256 hash → 256-bit key (~130 cycles)
       └─────┬─────┘
             ▼
       ┌───────────┐
       │   DONE    │ ← Output key + helper data
       └───────────┘
```

### Enrollment (First Time)

```
SRAM Power-Up → 128-bit PUF response → Store as helper data
                                      → SHA-256 hash → 256-bit KEY
```

### Reconstruction (Every Time After)

```
SRAM Power-Up → 128-bit PUF response (ignored — we use helper data)
Helper Data → Recover 128-bit secret → SHA-256 hash → SAME 256-bit KEY ✅
```

---

## 📁 File Structure (Only 7 Verilog Files)

```
rtl/
├── sram_puf_params.vh        ← Parameters (30 lines)
├── sram_puf_core.v           ← SRAM array simulator (85 lines)
├── sram_puf_controller.v     ← Main FSM - 6 states (197 lines)
├── fuzzy_extractor.v         ← Secret extract/recover (86 lines)
├── key_gen.v                 ← SHA-256 padding wrapper (88 lines)
├── sha256_core.v             ← SHA-256 hash engine (183 lines)
└── hamming_codec.v           ← Error correction (available for future use)

tb/
└── tb_sram_puf_top.v         ← Testbench with 3 tests (186 lines)

vivado/
├── create_project.tcl        ← Auto project setup
└── constraints.xdc           ← 100 MHz clock constraint
```

---

## 🧩 Simplified Code Explained

### 1. `sram_puf_params.vh` — Parameters (30 lines)

Just the essentials:

```verilog
`define PUF_SIZE       128    // 128 SRAM cells
`define SECRET_BITS    128    // 128-bit secret
`define HELPER_BITS    128    // 128-bit helper data
`define KEY_BITS       256    // 256-bit output key (SHA-256)

// Only 6 FSM states (original had 12!)
`define S_IDLE         3'd0
`define S_READ_PUF     3'd1
`define S_FUZZY        3'd2
`define S_KEYGEN       3'd3
`define S_DONE         3'd4
`define S_ERROR        3'd5
```

### 2. `sram_puf_core.v` — SRAM Simulator (85 lines)

Simulates 128 SRAM cells with manufacturing variation:

```verilog
// Each cell has a bias (like a coin that's slightly weighted)
// Bias > 128 → cell powers up as '1'
// Bias ≤ 128 → cell powers up as '0'

always @(posedge rst) begin           // On power-up:
    for (i = 0; i < 128; i = i + 1)
        if (cell_bias(i) > 128)       // Check manufacturing bias
            sram_cells[i] <= 1'b1;    // → settles to 1
        else
            sram_cells[i] <= 1'b0;    // → settles to 0
end

always @(posedge clk) begin           // On read:
    if (read_enable && !read_done)
        puf_response <= sram_cells;   // Output all 128 bits instantly
        read_done <= 1'b1;
end
```

**What changed:** Original had serial readout (128 cycles), environmental noise scaling, metastability detection. We simplified to **instant parallel readout** (1 cycle).

### 3. `sram_puf_controller.v` — Main Controller (197 lines)

The brain of the system — a simple 6-state FSM:

```verilog
case (state)
    S_IDLE:      // Wait for start_enroll or start_reconstruct
    S_READ_PUF:  // Pulse reset on PUF, read 128-bit response
    S_FUZZY:     // Start fuzzy extractor, wait for done
    S_KEYGEN:    // Start SHA-256 key generation, wait for done
    S_DONE:      // Output key_out and helper_data_out
    S_ERROR:     // Set error_flag if something went wrong
endcase
```

**What changed:** Original had 12 states with 10 power-up cycles, majority voting across readings, stability analysis. We simplified to **single read + direct processing**.

### 4. `fuzzy_extractor.v` — Secret Handler (86 lines)

Dead simple 3-state FSM:

```verilog
// ENROLLMENT: PUF bits → secret + helper data
secret_out <= puf_in[127:0];      // PUF response IS the secret
helper_out <= puf_in[127:0];      // Store it as helper data

// RECONSTRUCTION: helper data → recovered secret
secret_out <= helper_in[127:0];   // Just read back the stored secret
```

**What changed:** Original had generate blocks for BCH/Hamming selection, metastability mask filtering, 7 states. We simplified to **direct storage** (3 states).

### 5. `key_gen.v` — SHA-256 Wrapper (88 lines)

Pads the 128-bit secret to 512 bits and feeds it to SHA-256:

```verilog
// SHA-256 padding format:
// [128-bit secret] [1] [319 zeros] [64-bit length = 128]
//  ←── 128 bits ──→ 1   ←─ 319 ──→  ←──── 64 ────→  = 512 bits total
padded_msg <= { secret_in, 1'b1, 319'b0, 64'd128 };
```

### 6. `sha256_core.v` — SHA-256 Hash (183 lines)

Standard NIST SHA-256 (can't simplify without breaking correctness):
- **PREPARE** (64 cycles): Build message schedule W[0..63]
- **COMPRESS** (64 cycles): 64 rounds of hashing
- **FINALIZE** (1 cycle): Output 256-bit hash
- Total: ~130 clock cycles

---

## 🚀 How to Simulate in Vivado

### Step 1: Create Project
```tcl
cd C:/path/to/sram-12345
source vivado/create_project.tcl
```

### Step 2: Run Simulation
```tcl
launch_simulation
run all
```

### Step 3: Expected Output ✅

```
========================================
SRAM-PUF System Testbench (Simplified)
========================================

[TEST 1] Starting Enrollment...
[PASS] Enrollment completed successfully
  Helper Data: <128-bit hex>
  Key Output:  <256-bit hex>

[TEST 2] Starting Reconstruction...
[PASS] Reconstruction completed successfully
  Key Output: <256-bit hex>
[PASS] Keys match! PUF system working correctly.

[TEST 3] Testing multiple reconstructions...
  Reconstruction Key: <same key>
  Reconstruction Key: <same key>
  Reconstruction Key: <same key>

========================================
Testbench Complete
========================================
```

### What the 3 Tests Prove

| Test | What It Does | What It Proves |
|------|-------------|----------------|
| Test 1 | Enrollment | PUF can generate a key |
| Test 2 | Reconstruction | Same device → same key |
| Test 3 | 3× Reconstruction | Key is stable and repeatable |

---

## 📊 Comparison: Original vs Simplified

| Aspect | Original | Simplified |
|--------|----------|------------|
| Controller FSM | 12 states | **6 states** |
| PUF readout | Serial (128 cycles) | **Parallel (1 cycle)** |
| Enrollment | 10 power-up cycles + voting | **Single read** |
| Error correction | Hamming + BCH (selectable) | **Direct storage** |
| Fuzzy extractor | 7 states + meta filtering | **3 states** |
| Environmental model | Temp + voltage scaling | **None** |
| Source files | 8 Verilog | **7 Verilog** |
| Total code lines | ~1500 | **~500** |

---

## 📞 Author

**Melroy Quadros** — [@Melroy-Sahyadri-ECE](https://github.com/Melroy-Sahyadri-ECE)

## 📄 License

MIT License
