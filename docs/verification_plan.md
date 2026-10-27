# Verification Plan

## 1. Objective

Verify the UCIe-inspired link controller, packet channel, and integrated design for state transitions, packet integrity, backpressure, recovery, fatal faults, reset behavior, and assertion checking.

This is not a full UCIe compliance plan.

## 2. Design under test

- `chiplet_link_ctrl`: RESET, TRAINING, ACTIVE, RECOVERY, and FAILED states.
- `chiplet_packet_channel`: one-entry ready/valid buffer.
- `chiplet_link_top`: integrated controller and channel.

## 3. Test matrix

| Testbench | Main scenarios | Recorded result |
|---|---|---|
| `tb_link_ctrl.sv` | Reset, training, activation, recovery, retry, fatal fault, sticky FAILED | 9 checks passed |
| `tb_packet_channel.sv` | Acceptance, buffering, backpressure, payload stability, simultaneous dequeue/enqueue | 16 checks passed |
| `tb_packet_channel_edges.sv` | Link-down with pending data, recovery, reset flush, fresh traffic | 13 checks passed |
| `tb_link_integration.sv` | Integrated training, transfer, recovery, retraining | 17 checks passed |
| `tb_packet_channel_random.sv` | Seeded randomized traffic, stalls, transaction count, payload/order checks | 200 accepted and received |
| `tb_link_fault_stress.sv` | Recovery, pending packet, fatal fault, reset, resumed traffic | 26 checks passed |
| `tb_packet_channel_back_to_back.sv` | Three ordered packets and consecutive output handshakes | 7 checks passed |
| `tb_sva_negative.sv` | Output valid while link is down | Expected assertion detected |
| `tb_sva_stall_negative.sv` | Payload changes during output stall | Expected assertion detected |
| `tb_sva_failed_negative.sv` | FAILED state exits without reset | Expected assertion detected |

These results were recorded during development and should be reproduced on the current checkout.

## 4. Assertion properties

`tb/chiplet_link_sva.sv` checks:

1. Output valid is suppressed while `link_up` is low.
2. Output payload remains stable while valid is stalled, unless the link goes down.
3. FAILED remains sticky across sampled cycles unless reset semantics intervene.

Negative tests deliberately violate these properties. Each negative test passes only when the expected assertion failure is detected.

## 5. Randomized test record

Previously recorded results:

- RX seed: `0x5A3C91E7`
- Source seed: `0x1BADB002`
- Target transactions: 200
- Accepted: 200
- Received: 200
- Receiver stall cycles: 87
- Receiver stall events: 54
- Maximum stall length: 9 cycles
- Source idle cycles: 313

Payload integrity and ordering checks passed in that run. These metrics are not formal coverage percentages.

## 6. Fault-stress coverage counters

| Coverage item | Count |
|---|---:|
| RESET state samples | 2 |
| TRAINING state samples | 2 |
| ACTIVE state samples | 2 |
| RECOVERY state samples | 1 |
| FAILED state samples | 2 |
| Normal transfer | 1 |
| Receiver stall | 1 |
| Pending packet during recovery | 1 |
| Successful retraining | 1 |
| Reset after failure | 1 |
| Packet after reset | 1 |

These counters demonstrate exercised scenarios, not exhaustive state or transition coverage.

## 7. Execution

Normal regression:

    make clean && make

Negative assertion tests:

    make sva-negative

## 8. Exit criteria

- All normal Makefile targets complete without unexpected failure.
- Randomized traffic has matching accepted/received counts and passing payload/order checks.
- Fault-stress directed checks pass.
- All three negative SVA tests detect their intended violations.
- Documentation and commands match the committed repository.

## 9. Known limitations

- Simplified behavioral prototype, not full UCIe.
- Training and fault signals are abstract inputs.
- One-entry buffer and one output stream.
- No physical-layer modeling, formal proof, exhaustive coverage, timing closure, or interoperability demonstration.
