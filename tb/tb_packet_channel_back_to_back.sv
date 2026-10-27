module tb_packet_channel_back_to_back;

    logic clk = 0;
    logic rst_n = 0;
    logic link_up = 0;

    logic s_valid = 0;
    logic s_ready;
    logic [31:0] s_data = 0;

    logic m_valid;
    logic m_ready = 1;
    logic [31:0] m_data;

    integer accepted_count = 0;
    integer received_count = 0;
    integer checks = 0;
    integer consecutive_output_cycles = 0;
    integer max_consecutive_output_cycles = 0;
    logic previous_output_handshake = 0;

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

    always @(posedge clk) begin
        if (rst_n) begin
            if (s_valid && s_ready)
                accepted_count <= accepted_count + 1;

            if (m_valid && m_ready) begin
                if (previous_output_handshake) begin
                    consecutive_output_cycles <=
                        consecutive_output_cycles + 1;
                    if (consecutive_output_cycles + 1 >
                        max_consecutive_output_cycles)
                        max_consecutive_output_cycles <=
                            consecutive_output_cycles + 1;
                end else begin
                    consecutive_output_cycles <= 0;
                end
                previous_output_handshake <= 1'b1;

                case (received_count)
                    0: if (m_data !== 32'hA001_0001)
                           $fatal(1, "Packet 1 mismatch: %h", m_data);
                    1: if (m_data !== 32'hA001_0002)
                           $fatal(1, "Packet 2 mismatch: %h", m_data);
                    2: if (m_data !== 32'hA001_0003)
                           $fatal(1, "Packet 3 mismatch: %h", m_data);
                    default:
                        $fatal(1, "Unexpected extra packet: %h", m_data);
                endcase

                received_count <= received_count + 1;
            end else begin
                previous_output_handshake <= 1'b0;
                consecutive_output_cycles <= 0;
            end
        end
    end

    task automatic check(input logic condition, input string name);
        begin
            if (condition !== 1'b1)
                $fatal(1, "FAIL: %s", name);

            checks = checks + 1;
            $display("PASS: %s", name);
        end
    endtask

    initial begin
        repeat (2) @(negedge clk);
        rst_n = 1;
        link_up = 1;

        // Fill the buffer with packet 1.
        @(negedge clk);
        s_valid = 1;
        s_data = 32'hA001_0001;

        @(posedge clk);
        @(negedge clk);
        check(m_valid && m_data == 32'hA001_0001,
              "First packet buffered");

        // Keep valid asserted and replace the payload on each
        // negedge. With m_ready high, dequeue and enqueue overlap.
        s_data = 32'hA001_0002;

        @(posedge clk);
        #1;
        check(m_valid && m_data == 32'hA001_0002,
              "Second packet replaces consumed first packet");

        @(negedge clk);
        s_data = 32'hA001_0003;

        @(posedge clk);
        #1;
        check(m_valid && m_data == 32'hA001_0003,
              "Third packet replaces consumed second packet");

        @(negedge clk);
        s_valid = 0;

        @(posedge clk);
        #1;
        check(accepted_count == 3, "Exactly three packets accepted");
        check(received_count == 3, "Exactly three packets received");
        check(m_valid == 0, "Buffer becomes empty after final packet");
        check(max_consecutive_output_cycles >= 2,
              "At least three packets transfer on consecutive cycles");

        $display("Maximum consecutive output handshakes: %0d",
                 max_consecutive_output_cycles + 1);
        $display("----------------------------------------");
        $display("BACK-TO-BACK TESTS PASSED: %0d checks", checks);
        $finish;
    end

endmodule
