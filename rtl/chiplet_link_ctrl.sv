module chiplet_link_ctrl (
    input  logic clk,
    input  logic rst_n,
    input  logic training_done,
    input  logic recoverable_fault,
    input  logic fatal_fault,
    input  logic retry_done,
    output logic link_up,
    output logic [2:0] state
);

    localparam logic [2:0] RESET    = 3'd0;
    localparam logic [2:0] TRAINING = 3'd1;
    localparam logic [2:0] ACTIVE   = 3'd2;
    localparam logic [2:0] RECOVERY = 3'd3;
    localparam logic [2:0] FAILED   = 3'd4;

    always_ff @(posedge clk) begin
        if (!rst_n)
            state <= RESET;
        else begin
            case (state)
                RESET:
                    state <= TRAINING;

                TRAINING: begin
                    if (fatal_fault)
                        state <= FAILED;
                    else if (training_done)
                        state <= ACTIVE;
                end

                ACTIVE: begin
                    if (fatal_fault)
                        state <= FAILED;
                    else if (recoverable_fault)
                        state <= RECOVERY;
                end

                RECOVERY: begin
                    if (fatal_fault)
                        state <= FAILED;
                    else if (retry_done)
                        state <= TRAINING;
                end

                FAILED:
                    state <= FAILED;

                default:
                    state <= FAILED;
            endcase
        end
    end

    always_comb begin
        link_up = (state == ACTIVE);
    end

endmodule
