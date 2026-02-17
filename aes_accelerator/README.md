# AES-128 CBC Hardware Accelerator

**Target FPGA:** Xilinx Zynq-7000 XC7Z020CLG400-1  
**Interface:** AXI4-Lite Slave  
**Mode:** AES-128 CBC Encryption & Decryption  
**Architecture:** Fully Pipelined (10-stage, 1 round/stage, separate encrypt/decrypt datapaths)

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                      aes_top                            │
│                                                         │
│  ┌─────────────────┐     ┌──────────────────────────┐   │
│  │                 │     │       aes_cbc             │   │
│  │  axi4_lite      │     │                          │   │
│  │  _slave         │ key │  ┌───────────────────┐   │   │
│  │                 ├─────┤  │  aes_key_expand   │   │   │
│  │  Register Map:  │     │  └───────┬───────────┘   │   │
│  │  KEY[0:3]   W   │     │          │ round keys    │   │
│  │  IV[0:3]    W   │ iv  │  ┌───────▼───────────┐   │   │
│  │  DIN[0:3]   W   ├─────┤  │                   │   │   │
│  │  DOUT[0:3]  R   │     │  │  XOR ──► AES      │   │   │
│  │  CTRL       R/W │ din │  │  with    Pipeline  │   │   │
│  │  STATUS     R   ├─────┤  │  IV/     (10-stage │   │   │
│  │  KEY_CTRL   W   │     │  │  prev    pipelined)│   │   │
│  │                 │ dout│  │  CT                │   │   │
│  │                 ◄─────┤  │       ──► CT out   │   │   │
│  │                 │     │  │                   │   │   │
│  └─────────────────┘     │  └───────────────────┘   │   │
│                          └──────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
         ▲                                    
         │ AXI4-Lite                          
         │ M_AXI_GP0                          
    ┌────┴────┐                               
    │ Zynq PS │                               
    │ ARM A9  │                               
    └─────────┘                               
```

## AES Pipeline Architecture

```
=== Encrypt Pipeline ===
Plaintext ──► XOR(K0) ──► Round1 ──► Round2 ──► ... ──► Round9 ──► FinalRound ──► Ciphertext
                │           │          │                  │            │
                K0          K1         K2                 K9           K10

Each Round: SubBytes(16×SBox) → ShiftRows(wire) → MixColumns(GF) → AddRoundKey(XOR)
Final Round: SubBytes → ShiftRows → AddRoundKey (no MixColumns)

=== Decrypt Pipeline (Inverse Cipher, FIPS-197 §5.3) ===
Ciphertext ──► XOR(K10) ──► InvRound1 ──► InvRound2 ──► ... ──► InvRound9 ──► InvFinal ──► Plaintext
                  │            │             │                     │              │
                  K10          K9            K8                    K1             K0

Each InvRound: InvShiftRows → InvSubBytes → AddRoundKey(XOR) → InvMixColumns(GF)
InvFinal:      InvShiftRows → InvSubBytes → AddRoundKey (no InvMixColumns)

Latency: 11 clock cycles (both directions)
Throughput: 1 block/11 cycles (CBC, sequential due to feedback)
```

## Register Map

| Offset | Name     | R/W | Description                          |
|--------|----------|-----|--------------------------------------|
| 0x00   | KEY0     | W   | Key bits [127:96]                    |
| 0x04   | KEY1     | W   | Key bits [95:64]                     |
| 0x08   | KEY2     | W   | Key bits [63:32]                     |
| 0x0C   | KEY3     | W   | Key bits [31:0]                      |
| 0x10   | IV0      | W   | IV bits [127:96]                     |
| 0x14   | IV1      | W   | IV bits [95:64]                      |
| 0x18   | IV2      | W   | IV bits [63:32]                      |
| 0x1C   | IV3      | W   | IV bits [31:0]                       |
| 0x20   | DIN0     | W   | Data-in bits [127:96] (PT or CT)     |
| 0x24   | DIN1     | W   | Data-in bits [95:64]                 |
| 0x28   | DIN2     | W   | Data-in bits [63:32]                 |
| 0x2C   | DIN3     | W   | Data-in bits [31:0]                  |
| 0x30   | DOUT0    | R   | Data-out bits [127:96] (CT or PT)    |
| 0x34   | DOUT1    | R   | Data-out bits [95:64]                |
| 0x38   | DOUT2    | R   | Data-out bits [63:32]                |
| 0x3C   | DOUT3    | R   | Data-out bits [31:0]                 |
| 0x40   | CTRL     | R/W | bit0: start, bit1: encrypt(1)/decrypt(0), bit2: iv_load |
| 0x44   | STATUS   | R   | bit0: done (sticky), bit1: busy      |
| 0x48   | KEY_CTRL | W   | bit0: key_valid (trigger key expand)  |

## Usage Sequence

### Encryption
```c
// 1. Write AES-128 key
Xil_Out32(BASE + 0x00, key_word0);
Xil_Out32(BASE + 0x04, key_word1);
Xil_Out32(BASE + 0x08, key_word2);
Xil_Out32(BASE + 0x0C, key_word3);
Xil_Out32(BASE + 0x48, 0x1);        // Trigger key expansion

// 2. Write IV
Xil_Out32(BASE + 0x10, iv_word0);
Xil_Out32(BASE + 0x14, iv_word1);
Xil_Out32(BASE + 0x18, iv_word2);
Xil_Out32(BASE + 0x1C, iv_word3);
Xil_Out32(BASE + 0x40, 0x4);        // Load IV (CTRL bit 2)

// 3. For each plaintext block:
Xil_Out32(BASE + 0x20, pt_word0);
Xil_Out32(BASE + 0x24, pt_word1);
Xil_Out32(BASE + 0x28, pt_word2);
Xil_Out32(BASE + 0x2C, pt_word3);
Xil_Out32(BASE + 0x40, 0x3);        // Start + encrypt (CTRL bit0=1, bit1=1)

// 4. Poll for completion
while (!(Xil_In32(BASE + 0x44) & 0x1));

// 5. Read ciphertext
ct0 = Xil_In32(BASE + 0x30);
ct1 = Xil_In32(BASE + 0x34);
ct2 = Xil_In32(BASE + 0x38);
ct3 = Xil_In32(BASE + 0x3C);
```

### Decryption
```c
// Setup key and IV same as above, then:

// For each ciphertext block:
Xil_Out32(BASE + 0x20, ct_word0);
Xil_Out32(BASE + 0x24, ct_word1);
Xil_Out32(BASE + 0x28, ct_word2);
Xil_Out32(BASE + 0x2C, ct_word3);
Xil_Out32(BASE + 0x40, 0x1);        // Start + decrypt (CTRL bit0=1, bit1=0)

while (!(Xil_In32(BASE + 0x44) & 0x1));

pt0 = Xil_In32(BASE + 0x30);
pt1 = Xil_In32(BASE + 0x34);
pt2 = Xil_In32(BASE + 0x38);
pt3 = Xil_In32(BASE + 0x3C);
```

## Project Structure

```
aes_accelerator/
├── rtl/
│   ├── aes_sbox.v            — Forward & inverse S-Box (256-entry LUT)
│   ├── aes_round.v           — AES round: SubBytes+ShiftRows+MixColumns+AddRoundKey
│   ├── aes_final_round.v     — Final round: SubBytes+ShiftRows+AddRoundKey (no MixColumns)
│   ├── aes_key_expand.v      — AES-128 key expansion (generates all 11 round keys)
│   ├── aes_pipeline.v        — 10-stage fully pipelined AES-128 encrypt datapath
│   ├── aes_inv_round.v       — Inverse AES round (InvShiftRows+InvSubBytes+InvMixColumns)
│   ├── aes_inv_final_round.v — Inverse final round (no InvMixColumns)
│   ├── aes_inv_pipeline.v    — 10-stage fully pipelined AES-128 decrypt datapath
│   ├── aes_cbc.v             — CBC mode wrapper (encrypt & decrypt) with feedback
│   ├── aes_top.v             — Top level: AXI4-Lite interface + CBC core
│   └── axi4_lite_slave.v     — AXI4-Lite slave register file
├── tb/
│   ├── tb_aes_pipeline.v     — NIST FIPS-197 & SP 800-38A ECB vectors
│   ├── tb_aes_cbc.v          — NIST SP 800-38A CBC-AES128 vectors (encrypt + decrypt)
│   └── tb_aes_top.v          — Full AXI4-Lite system test (encrypt + decrypt)
├── constraints/
│   └── xc7z020.xdc           — Timing/configuration constraints
├── scripts/
│   ├── create_project.tcl    — Vivado project creation
│   └── run_sim.tcl           — Vivado simulation runner
└── README.md
```

## Resource Utilization (Estimated)

| Resource | Used     | Available | Utilization |
|----------|----------|-----------|-------------|
| LUT      | ~20,000  | 53,200    | ~38%        |
| FF       | ~12,000  | 106,400   | ~11%        |
| BRAM     | 0        | 140       | 0%          |
| DSP      | 0        | 220       | 0%          |

## Timing

| Parameter          | Value        |
|--------------------|--------------|
| Target Clock       | 100 MHz      |
| Clock Period       | 10.0 ns      |
| Pipeline Latency   | 11 cycles    |
| CBC Encrypt        | ~110 ns/block|
| ECB Throughput     | 12.8 Gbps    |

## Build Instructions

### Vivado (recommended)
```bash
cd scripts/
vivado -mode batch -source create_project.tcl
```

### Icarus Verilog (simulation only)
```bash
# Compile and run pipeline test
iverilog -o sim_pipeline -s tb_aes_pipeline rtl/*.v tb/tb_aes_pipeline.v
vvp sim_pipeline

# Compile and run CBC test
iverilog -o sim_cbc -s tb_aes_cbc rtl/*.v tb/tb_aes_cbc.v
vvp sim_cbc

# Compile and run top-level AXI test
iverilog -o sim_top -s tb_aes_top rtl/*.v tb/tb_aes_top.v
vvp sim_top
```

## Test Vectors

All test vectors are from NIST publications:
- **FIPS-197 Appendix B** — AES-128 single-block encryption
- **NIST SP 800-38A Appendix F.2.1** — AES-128-CBC multi-block encryption (4 blocks)
- **NIST SP 800-38A Appendix F.2.2** — AES-128-CBC multi-block decryption (4 blocks)

## Design Decisions

1. **Fully pipelined**: 10-stage pipeline provides maximum throughput for streaming use cases. CBC mode is inherently sequential (feedback dependency) but the pipelines are available for future ECB/CTR modes.

2. **Separate encrypt/decrypt datapaths**: Dedicated forward and inverse cipher pipelines allow switching direction per-block via CTRL bit 1. Both pipelines share the same round keys from a single key expansion.

3. **LUT-based S-Box**: Uses combinational `case` statements that synthesize to distributed ROM on Xilinx FPGAs. No BRAM consumed, lower latency than BRAM-based approaches. Both forward and inverse S-Boxes are implemented.

4. **Standard Inverse Cipher**: Implements the standard inverse cipher per FIPS-197 §5.3 (InvShiftRows → InvSubBytes → AddRoundKey → InvMixColumns), with GF(2^8) multiplication by {09}, {0b}, {0d}, {0e}.

5. **Pre-computed round keys**: All 11 round keys are generated combinationally from the input key and registered. This avoids key scheduling overhead during operation but uses more registers.

6. **AXI4-Lite interface**: Simple register-based control suitable for the CBC mode's inherently serial throughput. No DMA complexity required.

## License

This design is provided for educational and evaluation purposes.
