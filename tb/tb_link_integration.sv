module tb_link_integration;

    localparam logic [2:0] RESET    = 3'd0;
    localparam logic [2:0] TRAINING = 3'd1;
    localparam logic [2:0] ACTIVE   = 3'd2;
    localparam logic [2:0] RECOVERY = 3'd3;

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

    integer received_count = 0;
    integer checks = 0;

    always #5 clk <= ~clk;

    chiplet_link_top #(
        .DATA_WIDTH(32)
    ) dut (.*);

    // End-to-end scoreboard.
    always @(posedge clk) begin
        if (rst_n && m_valid && m_ready) begin
            case (received_count)
                0: if (m_data !== 32'hCAFE_0001)
                       $fatal(1, "Packet 0 mismatch: %h", m_data);
                1: if (m_data !== 32'hCAFE_0002)
                       $fatal(1, "Packet 1 mismatch: %h", m_data);
                default:
                    $fatal(1, "Unexpected packet: %h", m_data);
            endcase

            received_count <= received_count + 1;
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

            // Wait for an actual source-side handshake.
            do begin
                @(posedge clk);
            end while (s_ready !== 1'b1);

            @(negedge clk);
            s_valid = 0;
        end
    endtask

    initial begin
        $display("Starting integrated link verification");

        repeat (2) @(negedge clk);
        check(link_state == RESET, "Controller reset");
        check(link_up == 0, "Link down during reset");

        // Initialize the link.
        rst_n = 1;
        @(negedge clk);
        check(link_state == TRAINING, "Link enters training");

        training_done = 1;
        @(negedge clk);
        training_done = 0;
        check(link_state == ACTIVE, "Link becomes active");
        check(link_up == 1, "Link-up asserted");

        // Transfer packet 1.
        send_packet(32'hCAFE_0001);
        repeat (2) @(negedge clk);
        check(received_count == 1, "First packet delivered");

        // Queue packet 2 while the receiver is stalled.
        m_ready = 0;
        send_packet(32'hCAFE_0002);
        check(m_valid == 1, "Second packet buffered");
        check(m_data == 32'hCAFE_0002, "Second payload preserved");

        // Trigger controller-driven recovery.
        recoverable_fault = 1;
        @(negedge clk);
        recoverable_fault = 0;

        check(link_state == RECOVERY, "Controller enters recovery");
        check(link_up == 0, "Link drops during recovery");
        check(m_valid == 0, "Output valid suppressed during recovery");
        check(received_count == 1, "No packet delivered while stalled");

        // Complete recovery and retrain.
        retry_done = 1;
        @(negedge clk);
        retry_done = 0;
        check(link_state == TRAINING, "Recovery returns to training");

        training_done = 1;
        @(negedge clk);
        training_done = 0;
        check(link_state == ACTIVE, "Retraining completes");
        check(link_up == 1, "Link-up restored");

        // Release the receiver and drain the preserved packet.
        m_ready = 1;
        repeat (2) @(negedge clk);

        check(received_count == 2, "Second packet delivered after recovery");
        check(m_valid == 0, "Channel empty after delivery");

        $display("----------------------------------------");
        $display("INTEGRATION TESTS PASSED: %0d checks", checks);
        $finish;
    end

endmodule
