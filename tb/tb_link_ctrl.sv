module tb_link_ctrl;

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
    logic link_up;
    logic [2:0] state;
    integer checks = 0;

    always #5 clk <= ~clk;

    chiplet_link_ctrl dut (.*);

    task automatic check_state(
        input logic [2:0] expected_state,
        input logic expected_link,
        input string name
    );
        if (state !== expected_state ||
            link_up !== expected_link) begin
            $error("FAIL: %s state=%0d link_up=%b",
                   name, state, link_up);
            $fatal(1);
        end
        checks = checks + 1;
        $display("PASS: %s", name);
    endtask

    initial begin
        repeat (2) @(negedge clk);
        check_state(RESET, 0, "Reset");

        rst_n = 1;
        @(negedge clk);
        check_state(TRAINING, 0, "Enter training");

        training_done = 1;
        @(negedge clk);
        training_done = 0;
        check_state(ACTIVE, 1, "Training completes");

        recoverable_fault = 1;
        @(negedge clk);
        recoverable_fault = 0;
        check_state(RECOVERY, 0, "Recoverable fault");

        retry_done = 1;
        @(negedge clk);
        retry_done = 0;
        check_state(TRAINING, 0, "Retry starts training");

        training_done = 1;
        @(negedge clk);
        training_done = 0;
        check_state(ACTIVE, 1, "Link returns active");

        fatal_fault = 1;
        @(negedge clk);
        fatal_fault = 0;
        check_state(FAILED, 0, "Fatal fault");

        repeat (2) @(negedge clk);
        check_state(FAILED, 0, "Failed state is sticky");

        rst_n = 0;
        @(negedge clk);
        check_state(RESET, 0, "Reset clears failure");

        $display("ALL TESTS PASSED: %0d checks", checks);
        $finish;
    end

endmodule
