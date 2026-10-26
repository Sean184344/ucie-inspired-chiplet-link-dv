module chiplet_packet_channel #(
    parameter int DATA_WIDTH = 32
) (
    input  logic                  clk,
    input  logic                  rst_n,
    input  logic                  link_up,

    input  logic                  s_valid,
    output logic                  s_ready,
    input  logic [DATA_WIDTH-1:0] s_data,

    output logic                  m_valid,
    input  logic                  m_ready,
    output logic [DATA_WIDTH-1:0] m_data
);

    logic                  valid_q;
    logic [DATA_WIDTH-1:0] data_q;

    // Accept input when the buffer is empty or its current
    // contents will be consumed on this clock edge.
    always_comb begin
        s_ready = link_up && (!valid_q || m_ready);
        m_valid = link_up && valid_q;
        m_data  = data_q;
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            valid_q <= 1'b0;
            data_q  <= '0;
        end else if (link_up && (!valid_q || m_ready)) begin
            valid_q <= s_valid;

            if (s_valid)
                data_q <= s_data;
        end
    end

endmodule
