module tb_packet_channel;

    logic clk = 0;
    logic rst_n = 0;
    logic link_up = 0;

    logic s_valid = 0;
    logic s_ready;
    logic [31:0] s_data = 0;

    logic m_valid;
    logic m_ready = 0;
    logic [31:0] m_data;

    integer received_count = 0;
    integer checks = 0;

    always #5 clk <= ~clk;

    chiplet_packet_channel #(
        .DATA_WIDTH(32)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .link_up(link_up),
        .s_valid(s_valid),
        .s_ready(s_ready),
        .s_data(s_data),
        .m_valid(m_valid),
        .m_ready(m_ready),
        .m_data(m_data)
    );

    // Independent receive-side scoreboard.
    always @(posedge clk) begin
        if (rst_n && m_valid && m_ready) begin
            case (received_count)
                0: if (m_data !== 32'hA5A5_0001)
                       $fatal(1, "Packet 0 corrupted: %h", m_data);
                1: if (m_data !== 32'h1234_5678)
                       $fatal(1, "Packet 1 corrupted: %h", m_data);
                2: if (m_data !== 32'hDEAD_BEEF)
                       $fatal(1, "Packet 2 corrupted: %h", m_data);
                default:
                    $fatal(1, "Unexpected extra packet: %h", m_data);
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

    initial begin
        $display("Starting packet-channel tests");

        // Reset.
        repeat (2) @(negedge clk);
        check(m_valid == 0, "Reset clears output valid");

        // Activate the link and offer packet 0.
        rst_n = 1;
        link_up = 1;
        m_ready = 0;
        s_valid = 1;
        s_data = 32'hA5A5_0001;

        #1;
        check(s_ready == 1, "Empty buffer accepts input");

        @(posedge clk);
        @(negedge clk);
        s_valid = 0;

        check(m_valid == 1, "Packet buffered under backpressure");
        check(m_data == 32'hA5A5_0001, "First payload preserved");
        check(s_ready == 0, "Full buffer blocks new input");

        // Stall the receiver for three cycles.
        repeat (3) begin
            @(negedge clk);
            check(m_valid == 1, "Valid held during backpressure");
            check(m_data == 32'hA5A5_0001,
                  "Payload stable during backpressure");
        end

        // Release backpressure and consume packet 0.
        m_ready = 1;
        @(posedge clk);
        @(negedge clk);

        check(received_count == 1,
              "First packet delivered exactly once");

        // Offer packet 1.
        s_valid = 1;
        s_data = 32'h1234_5678;
        #1;
        check(s_ready == 1, "Source ready for packet 1");

        @(posedge clk);
        @(negedge clk);

        // Replace packet 1 with packet 2 while packet 1 is consumed.
        s_data = 32'hDEAD_BEEF;
        #1;
        check(s_ready == 1, "Simultaneous dequeue and enqueue allowed");

        @(posedge clk);
        @(negedge clk);
        s_valid = 0;

        // Allow the last packet to drain.
        repeat (2) @(negedge clk);

        check(received_count == 3, "All three packets delivered");
        check(m_valid == 0, "Buffer empty after final transfer");

        $display("----------------------------------------");
        $display("ALL PACKET TESTS PASSED: %0d checks", checks);
        $finish;
    end

endmodule
