# SRAM-PUF System for FPGA 🔐

A simplified SRAM-based Physical Unclonable Function (PUF) system for FPGA hardware security.  
Generates unique 256-bit cryptographic keys using SRAM power-up behavior.

---

## 🎯 What Does This Do?

Every FPGA has tiny manufacturing differences in its SRAM cells. When powered on, each cell settles to either `0` or `1` based on these differences — like a hardware fingerprint.

This project uses that fingerprint to:
1. **Enroll** → Read SRAM, extract a secret, generate a 256-bit SHA-256 key
2. **Reconstruct** → Re-read SRAM, recover the same secret, regenerate the **same key**

```
┌──────────────┐     ┌──────────────────┐     ┌──────────────┐     ┌──────────┐
│  SRAM PUF    │────▶│ Fuzzy Extractor  │────▶│  Key Gen     │────▶│ 256-bit  │
│  Core        │     │ (Secret + Helper)│     │  (SHA-256)   │     │   KEY    │
│  128 cells   │     │                  │     │              │     │          │
└──────────────┘     └──────────────────┘     └──────────────┘     └──────────┘
```

---

## 📁 Project Structure

```
sram-puf-fpga/
├── rtl/                          # Verilog Source Files
│   ├── sram_puf_params.vh        # System parameters
│   ├── sram_puf_core.v           # SRAM PUF (128-bit response)
│   ├── sram_puf_controller.v     # Top-level 6-state FSM
│   ├── fuzzy_extractor.v         # Secret extraction (3-state FSM)
│   ├── key_gen.v                 # SHA-256 wrapper with padding
│   ├── sha256_core.v             # SHA-256 hash (64-round)
│   └── hamming_codec.v           # Hamming(7,4) error correction
│
├── tb/                           # Testbench
│   └── tb_sram_puf_top.v         # Simulation testbench
│
└── vivado/                       # Vivado Project Files
    ├── create_project.tcl        # Auto project setup
    └── constraints.xdc           # Timing constraints (100 MHz)
```

---

## 🚀 How to Run Simulation

### Prerequisites
- **Xilinx Vivado** 2019.1 or later

### Step 1: Open Vivado & Create Project

Open Vivado, then in the **TCL Console** at the bottom:

```tcl
cd C:/path/to/sram-12345
source vivado/create_project.tcl
```

You'll see:
```
=========================================
Project created successfully!
Next: launch_simulation → run all
=========================================
```

### Step 2: Run Simulation

```tcl
launch_simulation
run all
```

### Step 3: Check Results ✅

You should see this output in the console:

```
========================================
SRAM-PUF System Testbench (Simplified)
========================================

[TEST 1] Starting Enrollment...
[PASS] Enrollment completed successfully
  Helper Data: <128-bit hex value>
  Key Output:  <256-bit hex value>

[TEST 2] Starting Reconstruction...
[PASS] Reconstruction completed successfully
  Key Output: <256-bit hex value>
[PASS] Keys match! PUF system working correctly.

[TEST 3] Testing multiple reconstructions...
  Reconstruction Key: <same 256-bit key>
  Reconstruction Key: <same 256-bit key>
  Reconstruction Key: <same 256-bit key>

========================================
Testbench Complete
========================================
```

**Key Result:** All reconstruction keys match the enrollment key → PUF system works! ✅

---

## 🔬 How It Works (Step by Step)

### Enrollment (First Time Setup)

```
Step 1: Power-up SRAM        → 128 cells settle to 0 or 1 (unique per chip)
Step 2: Read PUF response     → Get 128-bit fingerprint
Step 3: Fuzzy Extract         → Extract 128-bit secret, generate helper data
Step 4: SHA-256 Hash          → Hash the secret → 256-bit cryptographic key
Step 5: Store helper data     → Save for future reconstruction
```

### Reconstruction (Every Time After)

```
Step 1: Power-up SRAM         → Read 128-bit fingerprint again
Step 2: Use helper data       → Recover the original 128-bit secret
Step 3: SHA-256 Hash          → Same secret → Same 256-bit key ✅
```

---

## 🧩 Module Descriptions

### `sram_puf_core.v` — The PUF Heart
- 128 SRAM cells, each with a deterministic bias (simulates manufacturing variation)
- On reset: cells initialize based on bias (>128 → '1', ≤128 → '0')
- Instant parallel readout in 1 clock cycle
- Optional noise injection (~4% bit-flip rate)

### `sram_puf_controller.v` — Main Controller
Simple **6-state FSM**:
```
IDLE → READ_PUF → FUZZY → KEYGEN → DONE
                                  ↘ ERROR
```
- Enrollment: triggers PUF read → fuzzy extract → SHA-256 key
- Reconstruction: triggers PUF read → fuzzy decode → SHA-256 key

### `fuzzy_extractor.v` — Secret Extraction
Simple **3-state FSM**: IDLE → PROCESS → DONE
- Enrollment: takes PUF bits as secret, stores as helper data
- Reconstruction: recovers secret from stored helper data

### `key_gen.v` — SHA-256 Wrapper
- Pads 128-bit secret to 512 bits (NIST SHA-256 padding)
- Feeds padded message to SHA-256 core
- Outputs 256-bit cryptographic key

### `sha256_core.v` — SHA-256 Hash
Standard NIST SHA-256:
- 64 rounds of message schedule preparation
- 64 rounds of compression
- ~130 clock cycles total per hash

### `hamming_codec.v` — Error Correction
- Hamming(7,4): encodes 4 data bits → 7-bit codeword
- Can correct 1-bit errors
- Available for future noise-tolerant implementation

---

## ⚙️ Configuration

Edit `rtl/sram_puf_params.vh` to change:

| Parameter | Default | Description |
|-----------|---------|-------------|
| `PUF_SIZE` | 128 | Number of SRAM cells |
| `SECRET_BITS` | 128 | Secret size |
| `HELPER_BITS` | 128 | Helper data size |
| `KEY_BITS` | 256 | Output key size (SHA-256) |

---

## 📊 Performance

| Metric | Value |
|--------|-------|
| Clock | 100 MHz |
| Enrollment | ~200 cycles (~2 μs) |
| Reconstruction | ~140 cycles (~1.4 μs) |
| Key Size | 256 bits |
| PUF Size | 128 bits |
| Target FPGA | Xilinx Artix-7 |
| Est. LUTs | ~2500 |

---

## 📞 Author

**Melroy Quadros**  
GitHub: [@Melroy-Sahyadri-ECE](https://github.com/Melroy-Sahyadri-ECE)

## 📄 License

MIT License — see [LICENSE](LICENSE) for details.
