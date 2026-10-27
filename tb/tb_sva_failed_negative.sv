module tb_sva_failed_negative;

    logic clk = 0;
    logic rst_n = 0;
    logic link_up = 0;
    logic [2:0] link_state = 3'd0;
    logic m_valid = 0;
    logic m_ready = 0;
    logic [31:0] m_data = 32'h0;

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
        link_state = 3'd4; // Enter FAILED.

        @(negedge clk);
        link_state = 3'd2; // Deliberately violate sticky FAILED.

        repeat (3) @(negedge clk);

        $fatal(1, "Negative test failed: FAILED-state assertion did not fire");
    end

endmodule
