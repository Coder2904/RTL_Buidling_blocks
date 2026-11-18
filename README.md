# SystemVerilog Learning Projects

A set of small, complete digital-design projects built to practise the full loop that matters in RTL and
design-verification work: **decide the contract, draw the hardware, write the RTL, write a self-checking
testbench, and prove the testbench can catch bugs.**

Every project has its own folder with the same layout:

```
NN_Project_Name/
├── rtl/       synthesizable design
├── tb/        self-checking testbench(s)
├── scripts/   run / regression / mutation scripts
├── docs/      block diagram, waveforms, detailed design document
└── README.md  detailed notes for that project
```

This page is only the index. Each project README holds the detail.

## Repository map

```
SystemVerilog-Learning-Projects/
├── 01_ALU/                           parameterized combinational ALU
├── 02_Shift_Register/                PISO / SIPO shift register
├── 03_FSM/                           traffic light + elevator controller (Moore)
├── 04_Sequence_Detector/             1101 detector, Moore and Mealy
├── 05_Counters/                      programmable timer
├── 06_Multiplexers_Demultiplexers/   planned
├── 07_Encoders_Decoders/             planned
├── 08_Comparators/                   planned
├── 09_Register_File/                 2 read ports, 1 write port
└── 10_Additional_Exercises/          synchronous FIFO, fixed-point multiplier, UART TX/RX
```

## Status

| # | Project | Status |
|---|---|---|
| 01 | ALU | Done |
| 02 | Shift Register | Done |
| 03 | FSM (traffic light, elevator) | Done |
| 04 | Sequence Detector (Moore and Mealy) | Done |
| 05 | Counters (programmable timer) | Done |
| 06 | Multiplexers / Demultiplexers | Planned |
| 07 | Encoders / Decoders | Planned |
| 08 | Comparators | Planned |
| 09 | Register File | Done |
| 10 | Additional exercises (FIFO, fixed-point multiplier, UART) | Done |

## Projects at a glance

### 01 ALU
- **Architecture:** one shared adder serves ADD, SUB, SLT and SLTU (`b` XOR `sub`, carry-in = `sub`); SLT = N xor V, SLTU = not carry-out; shift amount taken from the low `log2(WIDTH)` bits of `b`; overflow flag gated so only ADD/SUB can raise it; opcode table fixed before coding.
- **Verification:** directed edge cases (signed overflow, SLT vs SLTU disagreement, shift boundaries, all-zero/all-ones), corner-value sweeps, random tests against an independent reference model, two widths, bug injection.

### 02 Shift Register
- **Architecture:** MSB-first convention chosen up front so it can be reused in SPI; fixed priority chain reset > load > shift > hold; `serial_out` is a plain wire from the MSB; PISO fills with zeros.
- **Verification:** timing contract checks (first and last bit positions), load in the middle of a shift, load and shift in the same cycle, random cycles against a reference model, two widths, bug injection.

### 03 FSM (traffic light, elevator)
- **Architecture:** strict three-block Moore structure (state register / next-state logic / outputs). Traffic light: one-hot state so outputs are direct flop bits, tick-enable dwell counter with precomputed constants, 2-flop synchronizer plus edge detector for the asynchronous pedestrian button, request latched and served only at a safe transition. Elevator: one latched request bit per floor, fixed up-before-down tie-break, door counter.
- **Verification:** cycle-by-cycle phase monitor (dwell, legal order, no conflicting lights, one-hot invariant), elevator tested against a floor-sensor plant model, reset from every state, simultaneous requests, random stress, bug injection.

### 04 Sequence Detector (Moore and Mealy)
- **Architecture:** overlapping `1101` detector built twice; overlap handled by the longest-suffix rule; Moore needs an extra state and fires one cycle after Mealy.
- **Verification:** software reference model checked every cycle, pulse cycle numbers recorded to prove the one-cycle difference, reset in the middle of a match, long random streams, bug injection.

### 05 Counters (programmable timer)
- **Architecture:** free-running up-counter with synchronous load; priority reset > load > enable; every flag defined against the cycle where the count is visibly on the output (match is an edge-detected combinational decode, overflow is registered); no auto-reload (documented).
- **Verification:** cycle-exact directed timeline at a small width, reference-model random testing at several widths, edge cases (compare value 0, load at the maximum, hold at the compare value), bug injection.

### 06 Multiplexers / Demultiplexers, 07 Encoders / Decoders, 08 Comparators
- Planned. They will follow the same layout, with exhaustive input testing wherever the input space is small.

### 09 Register File
- **Architecture:** two combinational read ports, one synchronous write port; selectable same-cycle policy (`WRITE_FIRST`) with the single-cycle-core caveat documented; optional hard-wired zero register guarded at both write and read; synchronous reset.
- **Verification:** all four parameter combinations, same-cycle read/write checks per policy, register-0 behaviour, no cross-talk between ports, random tests with deliberately colliding addresses against a model, bug injection.

### 10 Additional Exercises
- **Synchronous FIFO:** pointers with an extra wrap bit, power-of-2 depth checked at elaboration, registered read data, rejected requests have no side effects, defined behaviour for simultaneous read and write at full and empty. Verified with a scoreboard model compared every cycle, depths 2 to 16, wraparound laps, bug injection.
- **Fixed-point multiplier:** Q4.4 x Q4.4 to Q8.8 with the format stated explicitly, full precision never overflows, optional requantization with an overflow flag. Verified **exhaustively** (all 65,536 pairs) with an independent real-number check, plus bug injection.
- **UART TX / RX (8N1):** transmitter drives the pin from a frame register and supports zero-gap back-to-back frames; receiver uses a 2-flop synchronizer, 16x oversampling, mid-bit sampling, start-bit glitch rejection and framing-error detection. Verified with cycle-accurate frame checks, bit-banged receiver stimulus, measured baud-mismatch tolerance, loopback scoreboard at two clock ratios, bug injection.

## Verification techniques used across the repo

| Technique | Where |
|---|---|
| Self-checking testbenches that end in `PASS` or `FAIL` (no manual waveform reading) | all |
| Contract first: edge cases from the specification become named tests | all |
| Independent reference model (behavioural, written in a different style from the RTL) | ALU, shift register, detector, register file, FIFO, timer |
| Directed tests plus constrained-random tests | all |
| Exhaustive testing when the input space is small | multiplier |
| Always-on monitors and invariants (one-hot state, no conflicting lights, pulse width, bus timing) | FSM, UART |
| Plant model of the environment (floor sensor, serial line) | elevator, UART |
| Parameter sweeps (several widths, depths, clock ratios) | most projects |
| Mutation testing: inject one deliberate bug at a time and confirm the testbench fails | all (about 40 bugs injected across the set) |

A testbench that still passes on a deliberately broken design is too weak, so mutation checks are part of
"done" for every project.

## Tools

- **Simulator:** Icarus Verilog 12 (`iverilog -g2012`, `vvp`)
- **Waveforms:** GTKWave
- **Scripts:** Bash and Python (regression and mutation runners)
- **Language note:** RTL is written in synthesizable Verilog-2001 style with a few SystemVerilog features
  (for example elaboration-time `$error` parameter checks); testbenches are compiled with `-g2012`.

Typical run for one project:

```bash
iverilog -g2012 -o sim tb/tb_<name>.v rtl/<name>.v && vvp sim
```

Each project README lists its exact command, parameter variants and expected output.

## Conventions

- Write the specification decisions (encodings, priorities, reset values, timing definitions) down **before** the RTL.
- One module per file, parameters for widths, sized constants (no unsized literals in arithmetic).
- Drive testbench inputs on the falling clock edge, sample on the rising edge, so there are no races.
- Every project documents its decisions, its limitations and what it does not do.

## Where these projects lead

| Foundation project | Reused later in |
|---|---|
| Shift register (MSB-first) | SPI master and slave |
| ALU | RISC-V core datapath |
| Register file | RISC-V core (set `WRITE_FIRST` by core type) |
| FSM three-block style | CPU control unit |
| Synchronous FIFO | UART / peripheral buffering, FIFO assertions |
| Counters / timer | peripheral timers |
