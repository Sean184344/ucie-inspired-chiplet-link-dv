module tb_sva_stall_negative;

    logic clk = 0;
    logic rst_n = 0;
    logic link_up = 1;
    logic [2:0] link_state = 3'd2;
    logic m_valid = 0;
    logic m_ready = 0;
    logic [31:0] m_data = 32'h1111_AAAA;

    always #5 clk <= ~clk;

    chiplet_link_sva #(
        .FAILED_STATE(3'd4)
    ) sva_checker (
        .clk(clk),
        .rst_n(rst_n),
        .link_up(link_up),
        .link_state(link_state),
        .m_valid(m_valid),
        .m_ready(m_ready),
        .m_data(m_data)
    );

    initial begin
        @(negedge clk);
        rst_n = 1;

        @(negedge clk);
        m_valid = 1;
        m_ready = 0;
        m_data = 32'h1111_AAAA;

        // Keep the packet stalled for one sampled clock edge.
        @(negedge clk);
        m_data = 32'h2222_BBBB;

        // Allow the consequent of the assertion to be evaluated.
        repeat (3) @(negedge clk);

        $fatal(1, "Negative test failed: stalled-payload assertion did not fire");
    end

endmodule
