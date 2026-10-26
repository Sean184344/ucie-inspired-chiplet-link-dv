module tb_link_fault_stress;

    localparam logic [2:0] RESET    = 3'd0;
    localparam logic [2:0] TRAINING = 3'd1;
    localparam logic [2:0] ACTIVE   = 3'd2;
    localparam logic [2:0] RECOVERY = 3'd3;
    localparam logic [2:0] FAILED   = 3'd4;

    logic clk = 0;
    logic rst_n = 0;

    logic training_done = 0;
    logic recoverable_fault = 0;
    logic fatal_fault = 0;
    logic retry_done = 0;

    logic s_valid = 0;
    logic s_ready;
    logic [31:0] s_data = 0;

    logic m_valid;
    logic m_ready = 1;
    logic [31:0] m_data;

    logic link_up;
    logic [2:0] link_state;

    integer accepted_count = 0;
    integer received_count = 0;
    integer checks = 0;
    integer recovery_count = 0;
    integer fatal_count = 0;

    // Lightweight functional coverage counters.
    integer cov_reset = 0;
    integer cov_training = 0;
    integer cov_active = 0;
    integer cov_recovery = 0;
    integer cov_failed = 0;
    integer cov_normal_transfer = 0;
    integer cov_receiver_stall = 0;
    integer cov_pending_during_recovery = 0;
    integer cov_retrain_success = 0;
    integer cov_reset_after_failure = 0;
    integer cov_packet_after_reset = 0;

    always #5 clk <= ~clk;

    chiplet_link_top #(
        .DATA_WIDTH(32)
    ) dut (.*);

    // Bind protocol and link-state assertions to the integrated DUT signals.
    chiplet_link_sva #(
        .FAILED_STATE(FAILED)
    ) sva_checker (
        .clk       (clk),
        .rst_n     (rst_n),
        .link_up   (link_up),
        .link_state(link_state),
        .m_valid   (m_valid),
        .m_ready   (m_ready),
        .m_data    (m_data)
    );

    // Expected packet order:
    // 1. Normal traffic
    // 2. Traffic queued during recovery
    // 3. Fresh traffic after reset
    always @(posedge clk) begin
        if (rst_n) begin
            if (s_valid && s_ready)
                accepted_count <= accepted_count + 1;

            if (m_valid && m_ready) begin
                case (received_count)
                    0: if (m_data !== 32'hF001_0001)
                           $fatal(1, "Packet 0 mismatch: %h", m_data);
                    1: if (m_data !== 32'hF001_0002)
                           $fatal(1, "Packet 1 mismatch: %h", m_data);
                    2: if (m_data !== 32'hF001_0003)
                           $fatal(1, "Packet 2 mismatch: %h", m_data);
                    default:
                        $fatal(1, "Unexpected extra packet: %h", m_data);
                endcase

                received_count <= received_count + 1;
            end
        end
    end

    task automatic check(
        input logic condition,
        input string test_name
    );
        begin
            if (condition !== 1'b1)
                $fatal(1, "FAIL: %s", test_name);

            checks = checks + 1;
            $display("PASS: %s", test_name);
        end
    endtask

    task automatic send_packet(input logic [31:0] payload);
        begin
            @(negedge clk);
            s_data = payload;
            s_valid = 1;

            // Keep valid asserted until a source handshake occurs.
            do begin
                @(posedge clk);
            end while (s_ready !== 1'b1);

            @(negedge clk);
            s_valid = 0;
        end
    endtask

    initial begin
        $display("Starting integrated fault-stress verification");

        // Reset and initial link training.
        repeat (2) @(negedge clk);
        check(link_state == RESET, "Initial reset state");
        cov_reset = cov_reset + 1;

        rst_n = 1;
        @(negedge clk);
        check(link_state == TRAINING, "Initial training");
        cov_training = cov_training + 1;

        training_done = 1;
        @(negedge clk);
        training_done = 0;
        check(link_state == ACTIVE, "Initial link activation");
        cov_active = cov_active + 1;
        check(link_up == 1, "Link-up asserted");

        // Scenario 1: Normal packet transfer.
        send_packet(32'hF001_0001);
        repeat (2) @(negedge clk);
        check(received_count == 1, "Normal packet delivered");
        cov_normal_transfer = cov_normal_transfer + 1;

        // Scenario 2: Queue a packet while the receiver is stalled.
        m_ready = 0;
        send_packet(32'hF001_0002);
        check(m_valid == 1, "Packet queued before recovery");
        cov_receiver_stall = cov_receiver_stall + 1;
        check(m_data == 32'hF001_0002, "Queued payload correct");

        // Trigger a recoverable fault.
        recoverable_fault = 1;
        @(negedge clk);
        recoverable_fault = 0;

        check(link_state == RECOVERY, "Recoverable fault enters recovery");
        check(link_up == 0, "Link down during recovery");
        check(m_valid == 0, "Output suppressed during recovery");
        check(received_count == 1, "Queued packet not delivered prematurely");
        cov_recovery = cov_recovery + 1;
        cov_pending_during_recovery = cov_pending_during_recovery + 1;

        recovery_count = recovery_count + 1;

        // Complete retry and retrain.
        retry_done = 1;
        @(negedge clk);
        retry_done = 0;
        check(link_state == TRAINING, "Recovery enters retraining");

        training_done = 1;
        @(negedge clk);
        training_done = 0;
        check(link_state == ACTIVE, "Retraining succeeds");
        cov_retrain_success = cov_retrain_success + 1;
        check(link_up == 1, "Link restored after recovery");

        // Deliver the preserved packet.
        m_ready = 1;
        repeat (2) @(negedge clk);
        check(received_count == 2, "Queued packet delivered after recovery");

        // Scenario 3: Fatal fault while active.
        fatal_fault = 1;
        @(negedge clk);
        fatal_fault = 0;

        check(link_state == FAILED, "Fatal fault enters FAILED");
        cov_failed = cov_failed + 1;
        check(link_up == 0, "FAILED state keeps link down");

        fatal_count = fatal_count + 1;

        // Verify FAILED is sticky.
        repeat (3) @(negedge clk);
        check(link_state == FAILED, "FAILED state is sticky");
        cov_failed = cov_failed + 1;

        // Scenario 4: Reset and retrain.
        rst_n = 0;
        @(negedge clk);
        check(link_state == RESET, "Reset clears FAILED state");
        cov_reset = cov_reset + 1;
        cov_reset_after_failure = cov_reset_after_failure + 1;

        rst_n = 1;
        @(negedge clk);
        check(link_state == TRAINING, "Training restarts after reset");
        cov_training = cov_training + 1;

        training_done = 1;
        @(negedge clk);
        training_done = 0;
        check(link_state == ACTIVE, "Link reactivates after reset");
        cov_active = cov_active + 1;

        // Fresh packet after reset.
        send_packet(32'hF001_0003);
        repeat (2) @(negedge clk);

        check(accepted_count == 3, "Three packets accepted");
        check(received_count == 3, "Three packets received exactly once");
        cov_packet_after_reset = cov_packet_after_reset + 1;
        check(m_valid == 0, "No pending packet remains");
        check(recovery_count == 1, "One recovery scenario exercised");
        check(fatal_count == 1, "One fatal-fault scenario exercised");

        $display("----------------------------------------");
        $display("Accepted packets : %0d", accepted_count);
        $display("Received packets : %0d", received_count);
        $display("Recovery events  : %0d", recovery_count);
        $display("Fatal faults     : %0d", fatal_count);
        $display("----------------------------------------");
        $display("FUNCTIONAL COVERAGE SUMMARY");
        $display("State RESET samples       : %0d", cov_reset);
        $display("State TRAINING samples    : %0d", cov_training);
        $display("State ACTIVE samples      : %0d", cov_active);
        $display("State RECOVERY samples    : %0d", cov_recovery);
        $display("State FAILED samples      : %0d", cov_failed);
        $display("Normal transfer           : %0d", cov_normal_transfer);
        $display("Receiver stall            : %0d", cov_receiver_stall);
        $display("Pending packet in recovery: %0d", cov_pending_during_recovery);
        $display("Successful retraining     : %0d", cov_retrain_success);
        $display("Reset after failure       : %0d", cov_reset_after_failure);
        $display("Packet after reset        : %0d", cov_packet_after_reset);
        $display("FAULT-STRESS TESTS PASSED: %0d checks", checks);
        $finish;
    end

    initial begin
        #10000;
        $fatal(1, "Fault-stress test timed out");
    end

endmodule
