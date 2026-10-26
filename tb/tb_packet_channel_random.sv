module tb_packet_channel_random;

    localparam integer NUM_PACKETS = 200;
    localparam logic [31:0] DATA_BASE = 32'hC001_0000;

    logic clk = 0;
    logic rst_n = 0;
    logic link_up = 0;

    logic s_valid = 0;
    logic s_ready;
    logic [31:0] s_data = 0;

    logic m_valid;
    logic m_ready = 0;
    logic [31:0] m_data;

    logic source_fire = 0;
    integer accepted_count = 0;
    integer received_count = 0;

    logic [31:0] rx_lfsr = 32'h5A3C_91E7;
    logic [31:0] src_lfsr = 32'h1BAD_B002;

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

    function automatic logic [31:0] next_lfsr(
        input logic [31:0] value
    );
        next_lfsr = {
            value[30:0],
            value[31] ^ value[21] ^ value[1] ^ value[0]
        };
    endfunction

    // Reproducible randomized receiver backpressure.
    initial begin
        forever begin
            @(negedge clk);
            rx_lfsr = next_lfsr(rx_lfsr);
            m_ready = rx_lfsr[0] | rx_lfsr[3];
        end
    end

    // Independent transaction accounting and scoreboard.
    always @(posedge clk) begin
        if (!rst_n) begin
            source_fire <= 0;
        end else begin
            source_fire <= s_valid && s_ready;

            if (s_valid && s_ready) begin
                if (s_data !== DATA_BASE + accepted_count)
                    $fatal(1, "Unexpected source payload at index %0d",
                           accepted_count);

                accepted_count <= accepted_count + 1;
            end

            if (m_valid && m_ready) begin
                if (m_data !== DATA_BASE + received_count)
                    $fatal(1,
                           "Scoreboard mismatch at index %0d: got %h expected %h",
                           received_count, m_data,
                           DATA_BASE + received_count);

                received_count <= received_count + 1;
            end
        end
    end

    task automatic send_packet(input logic [31:0] payload);
        begin
            // Randomized source idle gaps.
            src_lfsr = next_lfsr(src_lfsr);

            if (src_lfsr[0]) begin
                @(negedge clk);
            end

            @(negedge clk);
            s_data = payload;
            s_valid = 1;

            // Wait for a sampled source handshake.
            do begin
                @(posedge clk);
                #1;
            end while (source_fire !== 1'b1);

            @(negedge clk);
            s_valid = 0;
        end
    endtask

    initial begin
        $display("Starting seeded randomized packet stress");
        $display("Seed RX=0x5A3C91E7 SRC=0x1BADB002");
        $display("Target transactions: %0d", NUM_PACKETS);

        repeat (3) @(negedge clk);

        rst_n = 1;
        link_up = 1;

        for (integer i = 0; i < NUM_PACKETS; i++) begin
            send_packet(DATA_BASE + i);
        end

        // Drain any remaining buffered transaction.
        s_valid = 0;
        repeat (10) @(negedge clk);

        if (accepted_count != NUM_PACKETS)
            $fatal(1, "Accepted %0d packets, expected %0d",
                   accepted_count, NUM_PACKETS);

        if (received_count != NUM_PACKETS)
            $fatal(1, "Received %0d packets, expected %0d",
                   received_count, NUM_PACKETS);

        $display("PASS: Accepted transactions = %0d", accepted_count);
        $display("PASS: Received transactions = %0d", received_count);
        $display("PASS: Payload integrity and ordering");
        $display("ALL RANDOMIZED TESTS PASSED");
        $finish;
    end

    initial begin
        #100000;
        $fatal(1, "Randomized test timed out");
    end

endmodule
