# UCIe-Inspired Chiplet Link Verification

A SystemVerilog RTL and verification project modeling selected behaviors of a chiplet-to-chiplet link. The focus is link-state management, packet transfer, backpressure, recovery, fatal faults, and assertion-based verification.

> Scope: This is an educational UCIe-inspired prototype, not a complete UCIe implementation or compliance suite.

## Architecture

- `rtl/chiplet_link_ctrl.sv`: five-state link controller.
- `rtl/chiplet_packet_channel.sv`: parameterized one-entry ready/valid packet buffer.
- `rtl/chiplet_link_top.sv`: integrates the controller and packet channel.

### Link states

| State | Behavior |
|---|---|
| RESET | Transitions to TRAINING after reset release and a clock edge. |
| TRAINING | Waits for training_done; fatal faults enter FAILED. |
| ACTIVE | Asserts link_up; recoverable faults enter RECOVERY and fatal faults enter FAILED. |
| RECOVERY | Holds the link down; retry_done returns the controller to TRAINING. |
| FAILED | Sticky until reset. |

### Packet channel

- Ready/valid handshaking.
- Backpressure when the one-entry buffer is full.
- Simultaneous dequeue and enqueue.
- One packet per cycle under continuous traffic when the link is active and the receiver is ready.
- Pending packets retained through link-down/recovery.
- Reset clears pending data.

## Verification

| Test | Recorded result |
|---|---|
| Controller | 9 checks passed |
| Packet channel | 16 checks passed |
| Edge cases | 13 checks passed |
| Integration | 17 checks passed |
| Randomized stress | 200 accepted and 200 received transactions |
| Fault stress | 26 checks passed |
| Back-to-back transfers | 7 checks passed; three consecutive output handshakes |
| Negative SVA tests | Three intentional assertion violations detected |

These are recorded development results. Re-run the regression to verify the current checkout.

## Requirements

- Linux
- Verilator with timing and assertion support
- GNU Make
- C++ compiler and standard build tools

## Run the tests

Normal regression:

    make clean && make

Negative assertion tests:

    make sva-negative

Individual targets:

    make controller
    make packet
    make edges
    make integration
    make random
    make faultstress
    make back-to-back

## Limitations

This project does not implement the complete UCIe specification. It does not include a physical layer, electrical signaling, lane bonding, a standards-defined training sequence, or compliance evidence. Training and fault inputs are abstract behavioral signals. The tests do not establish formal proof, timing closure, or interoperability.

## Future improvements

- Expand packet formats and traffic generation.
- Add reset/fault concurrency tests.
- Improve coverage and regression reporting.
- Extend the UCIe-inspired protocol model.
