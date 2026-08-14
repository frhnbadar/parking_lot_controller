# Parking Lot Controller — SystemVerilog RTL + Verification

A parameterized FSM-based parking lot controller designed in SystemVerilog.

The controller manages vehicle entry and exit barriers based on
parking-slot availability and vehicle sensors. The project also
includes a self-checking verification environment with directed
tests, randomized testing, SystemVerilog Assertions (SVA), functional
coverage, and waveform generation.

---

## Features

- Parameterized parking capacity using `NUM_SLOTS`
- FSM-based entry and exit control
- Sensor-based vehicle detection
- Entry and exit barrier control
- Occupancy calculation using a slot-occupancy vector
- Automatic calculation of available slots
- Parking full / empty detection
- Entry and exit transaction counters
- Illegal-exit detection
- Simultaneous entry/exit arbitration
- Self-checking SystemVerilog testbench
- Directed verification tests
- 100 randomized occupancy tests
- SystemVerilog Assertions
- Functional coverage
- VCD waveform generation
- Icarus Verilog–compatible simulation flow
- Optional SVA/coverage support for simulators such as VCS/Questa

---

## Project Structure

```text
parking_lot_controller/
│
├── rtl/
│   └── parking_lot_controller.sv
│
├── tb/
│   └── parking_lot_controller_tb.sv
│
├── sim/
│   └── Simulation / build artifacts
│
├── docs/
│   └── Waveforms, screenshots, design notes
│
├── Makefile
├── .gitignore
└── README.md
```

---

## Design Overview

The parking lot is modeled using an occupancy vector:

```systemverilog
logic [NUM_SLOTS-1:0] slot_occupied;
```

Each bit represents one parking slot:

- `1` → occupied
- `0` → empty

For example:

```
slot_occupied = 8'b10110100
```

means four parking slots are occupied.

The controller calculates the total occupancy using a population-count
operation:

```text
slot_occupied
      │
      ▼
   Popcount
      │
      ▼
occupied_count
      │
      ├──────────────► available_slots
      │
      ├──────────────► parking_full
      │
      └──────────────► parking_empty
```

The individual slot occupancy is treated as an external input,
representing physical parking-slot sensors. The controller therefore
does not directly modify `slot_occupied`.

---

## FSM Architecture

The controller uses seven states:

```
IDLE
CHECK_ENTRY
ENTRY_OPEN
ENTRY_WAIT
CHECK_EXIT
EXIT_OPEN
EXIT_WAIT
```

### State Flow — Entry

```text
              entry_request
                    │
                    ▼
                 IDLE
                    │
                    ▼
              CHECK_ENTRY
                    │
              parking available
                    │
                    ▼
               ENTRY_OPEN
                    │
             vehicle detected
                    │
                    ▼
               ENTRY_WAIT
                    │
             vehicle clears
                    │
                    ▼
                  IDLE
```

### State Flow — Exit

```text
               exit_request
                    │
                    ▼
                  IDLE
                    │
                    ▼
               CHECK_EXIT
                    │
              vehicle present
                    │
                    ▼
                EXIT_OPEN
                    │
             vehicle detected
                    │
                    ▼
                EXIT_WAIT
                    │
             vehicle clears
                    │
                    ▼
                  IDLE
```

---

## Entry Control

An entry request is accepted only when the parking lot has at least
one available slot.

If the lot is full (`parking_full = 1`), the entry barrier remains
closed.

The entry sequence is:

```text
CHECK_ENTRY
     ↓
ENTRY_OPEN
     ↓
ENTRY_WAIT
     ↓
IDLE
```

The entry barrier is asserted in `ENTRY_OPEN` and `ENTRY_WAIT`.

A successful entry is counted when the vehicle clears the entry
sensor.

---

## Exit Control

An exit request is accepted only when the parking lot is not empty.

If the lot is empty (`parking_empty = 1`), the exit barrier remains
closed.

The exit sequence is:

```text
CHECK_EXIT
     ↓
EXIT_OPEN
     ↓
EXIT_WAIT
     ↓
IDLE
```

The exit barrier is asserted in `EXIT_OPEN` and `EXIT_WAIT`.

A successful exit is counted when the vehicle clears the exit sensor.

---

## Simultaneous Request Arbitration

The controller explicitly handles the case where both requests are
asserted simultaneously.

| Condition        | Priority |
|-------------------|----------|
| Space available   | Entry    |
| Parking lot full  | Exit     |

Therefore:

```text
entry_request = 1
exit_request  = 1
parking_full  = 0
```

results in **ENTRY**, while:

```text
entry_request = 1
exit_request  = 1
parking_full  = 1
```

results in **EXIT**.

This prevents an entry request from being accepted when the parking
lot is already full.

---

## Occupancy Status

For `NUM_SLOTS = 8`:

| Signal            | Meaning                              |
|-------------------|---------------------------------------|
| `occupied_count`  | Number of occupied slots              |
| `available_slots` | Number of free slots                  |
| `parking_full`    | `1` when all slots are occupied       |
| `parking_empty`   | `1` when no slots are occupied        |

The relationship is:

```text
available_slots = NUM_SLOTS - occupied_count
```

**Example:**

```text
slot_occupied   = 8'b11001010

occupied_count  = 4
available_slots = 4
parking_full    = 0
parking_empty   = 0
```

---

## Statistics

The controller maintains two 16-bit counters:

- `entry_count`
- `exit_count`

A successful entry increments `entry_count`. A successful exit
increments `exit_count`. Both counters reset to zero when `rst` is
asserted.

---

## Illegal Exit Detection

An illegal exit occurs when an exit is requested while the parking lot
is empty. The controller generates `illegal_exit = 1` for one clock
cycle.

The sequence is:

```text
exit_request
     ↓
CHECK_EXIT
     ↓
parking_empty = 1
     ↓
illegal_exit pulse
```

The exit barrier does not open during an illegal exit attempt.

---

## Verification Environment

The testbench is self-checking and verifies both normal operation and
corner cases.

### Directed Tests

**Test 1 — Reset**
Checks occupancy, available slots, full/empty flags, entry counter,
exit counter, illegal-exit flag, and barrier outputs.

**Test 2 — Occupancy Calculation**
Multiple occupancy patterns are applied and compared against
independently calculated expected values.

**Test 3 — Normal Entry**
Checks entry request, entry barrier opening, entry sensor handshake,
entry barrier closing, and entry counter increment.

**Test 4 — Normal Exit**
Checks exit request, exit barrier opening, exit sensor handshake, exit
barrier closing, and exit counter increment.

**Test 5 — Full Parking Lot**
Checks that `parking_full = 1`, `available_slots = 0`, and that the
entry barrier does not open.

**Test 6 — Empty Parking Lot**
Checks that `parking_empty = 1`, `occupied_count = 0`, and
`available_slots = NUM_SLOTS`.

**Test 7 — Illegal Exit**
Checks that an exit request on an empty lot generates the expected
one-cycle `illegal_exit` indication.

**Test 8 — Simultaneous Entry + Exit**
Checks both arbitration cases: space available → entry wins; lot full
→ exit wins.

**Test 9 — Randomized Occupancy**
100 randomized `slot_occupied` patterns are generated. For each
pattern, the testbench independently calculates `occupied_count`,
`available_slots`, `parking_full`, and `parking_empty`, and compares
them against the DUT outputs.

### SystemVerilog Assertions

The SVA section checks important design invariants:

- **Full/empty exclusivity** — `FULL` and `EMPTY` cannot be asserted simultaneously.
- **Full parking lot** — `parking_full → available_slots == 0`
- **Empty parking lot** — `parking_empty → occupied_count == 0`
- **Barrier exclusivity** — `entry_barrier && exit_barrier` must never occur.
- **Full blocks entry** — `parking_full → !entry_barrier`
- **Empty blocks exit** — `parking_empty → !exit_barrier`

SVA and functional coverage are conditionally compiled using:

```systemverilog
`ifdef SIM_SUPPORTS_SVA
```

This allows the basic testbench to run on simulators that do not
support concurrent assertions or covergroups (e.g. Icarus Verilog).

### Functional Coverage

The coverage model monitors:

- Occupancy levels
- Full status
- Empty status
- Entry barrier
- Exit barrier
- Entry requests
- Exit requests
- Entry sensor
- Exit sensor
- Entry/exit request combinations
- Full/empty status combinations

Occupancy is divided into: `EMPTY`, `LOW`, `MEDIUM`, `HIGH`, `FULL`.

The request cross checks `entry_request × exit_request`, while the
status cross checks `parking_full × parking_empty`.

---

## Simulation

### Requirements

**Icarus Verilog** (default simulator):

```bash
sudo apt update
sudo apt install iverilog
```

**GTKWave** (waveform viewer):

```bash
sudo apt install gtkwave
```

### Makefile Commands

```bash
make            # run simulation
make run        # same as above
make wave       # open waveform in GTKWave
make lint       # run lint
make clean      # remove generated files
```

### Manual Icarus Simulation

The project can also be compiled manually:

```bash
iverilog -g2012 \
    -o simv \
    rtl/parking_lot_controller.sv \
    tb/parking_lot_controller_tb.sv
```

Run it:

```bash
vvp simv
```

The testbench generates `parking_lot_controller.vcd`. Open it with:

```bash
gtkwave parking_lot_controller.vcd
```

### SVA / Coverage Simulation

For a simulator supporting SVA and functional coverage, define
`SIM_SUPPORTS_SVA`. For example:

```bash
vcs -sverilog \
    +define+SIM_SUPPORTS_SVA \
    rtl/parking_lot_controller.sv \
    tb/parking_lot_controller_tb.sv
```

The exact command may vary depending on the simulator and
installation.

### EDA Playground

The project can also be simulated using [EDA Playground](https://www.edaplayground.com/).

1. Add `rtl/parking_lot_controller.sv` as the design source.
2. Add `tb/parking_lot_controller_tb.sv` as the testbench.
3. Select a SystemVerilog-compatible simulator and run.
4. For simulators that support SVA and functional coverage, enable
   `SIM_SUPPORTS_SVA` as a compilation define.

---

## Waveform Signals

Useful signals to inspect in GTKWave:

```
clk
rst

entry_request
exit_request

entry_sensor
exit_sensor

slot_occupied

entry_barrier
exit_barrier

occupied_count
available_slots

parking_full
parking_empty

entry_count
exit_count

illegal_exit

dut.state
```

The FSM state (`dut.state`) is particularly useful for debugging the
transaction sequence.

---

## Parameterization

The default parking capacity is `NUM_SLOTS = 8`.

The controller can be instantiated with another capacity:

```systemverilog
parking_lot_controller #(
    .NUM_SLOTS(16)
) dut (
    ...
);
```

The counter width automatically adapts using:

```systemverilog
$clog2(NUM_SLOTS + 1)
```

This allows the design to represent values from `0` to `NUM_SLOTS`.

---

## Design Characteristics

| Feature           | Implementation           |
|--------------------|---------------------------|
| Design style       | FSM                       |
| HDL                | SystemVerilog             |
| Default capacity   | 8 slots                   |
| Parameterized      | Yes                       |
| Entry control      | Sensor-based              |
| Exit control       | Sensor-based              |
| Occupancy          | External slot sensors     |
| Statistics         | 16-bit counters           |
| Illegal exit       | One-cycle pulse           |
| Verification       | Self-checking TB          |
| Random testing     | 100 cases                 |
| Assertions         | SVA                       |
| Coverage           | Functional                |
| Waveform           | VCD                       |

---

## Verification Flow

```text
                RTL
                 │
                 ▼
          SystemVerilog DUT
                 │
                 ▼
        Self-Checking Testbench
                 │
        ┌────────┼────────┐
        ▼        ▼        ▼
    Directed   Random    SVA
     Tests     Tests   Assertions
        │        │        │
        └────────┼────────┘
                 ▼
        Functional Coverage
                 │
                 ▼
             VCD Dump
                 │
                 ▼
             GTKWave
```

---

## Expected Result

A successful simulation should finish with:

```text
======================================================
          ALL TESTS COMPLETED
======================================================
```

without unexpected `$error` messages.

---

## Author

**Md Farhan Badar**
B.Tech Electronics — VLSI Design & Technology
Jamia Millia Islamia