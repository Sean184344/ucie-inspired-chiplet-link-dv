module tb_packet_channel_edges;

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

    // Expected receive sequence: packet 1, then packet 3.
    // Packet 2 is deliberately discarded by reset.
    always @(posedge clk) begin
        if (rst_n && m_valid && m_ready) begin
            case (received_count)
                0: if (m_data !== 32'h1111_0001)
                       $fatal(1, "Unexpected first packet: %h", m_data);
                1: if (m_data !== 32'h3333_0003)
                       $fatal(1, "Unexpected second packet: %h", m_data);
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

    task automatic send_packet(input logic [31:0] payload);
        begin
            @(negedge clk);
            s_data = payload;
            s_valid = 1;

            #1;
            if (s_ready !== 1'b1)
                $fatal(1, "Source was not ready for packet %h", payload);

            @(posedge clk);
            @(negedge clk);
            s_valid = 0;
        end
    endtask

    initial begin
        $display("Starting packet-channel edge-case tests");

        // Initialize.
        repeat (2) @(negedge clk);
        check(m_valid == 0, "Reset starts with empty buffer");

        rst_n = 1;
        link_up = 1;

        // Queue packet 1 while the receiver is stalled.
        send_packet(32'h1111_0001);
        check(m_valid == 1, "Packet pending at receiver");
        check(m_data == 32'h1111_0001, "Pending packet payload correct");

        // Simulate link loss while the packet is pending.
        link_up = 0;
        #1;
        check(m_valid == 0, "Link down suppresses output valid");
        check(s_ready == 0, "Link down blocks new input");

        repeat (2) @(negedge clk);
        check(received_count == 0, "No delivery while link is down");

        // Restore link and drain the preserved packet.
        link_up = 1;
        m_ready = 1;

        @(posedge clk);
        @(negedge clk);
        check(received_count == 1, "Pending packet delivered after resume");

        // Queue packet 2, then reset before it can be consumed.
        m_ready = 0;
        send_packet(32'h2222_0002);
        check(m_valid == 1, "Second packet is pending before reset");

        rst_n = 0;
        @(posedge clk);
        @(negedge clk);

        check(m_valid == 0, "Reset clears pending packet");
        check(received_count == 1, "Reset packet was not delivered");

        // Restart the link. The reset packet must not reappear.
        rst_n = 1;
        link_up = 1;
        m_ready = 1;

        repeat (2) @(negedge clk);
        check(m_valid == 0, "No stale packet after reset");

        // Verify that fresh traffic still works.
        send_packet(32'h3333_0003);

        @(posedge clk);
        @(negedge clk);

        check(received_count == 2, "Fresh packet delivered after reset");
        check(m_valid == 0, "Buffer empty at end of test");

        $display("----------------------------------------");
        $display("ALL EDGE-CASE TESTS PASSED: %0d checks", checks);
        $finish;
    end

endmodule
