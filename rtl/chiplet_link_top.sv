module chiplet_link_top #(
    parameter int DATA_WIDTH = 32
) (
    input  logic                  clk,
    input  logic                  rst_n,

    input  logic                  training_done,
    input  logic                  recoverable_fault,
    input  logic                  fatal_fault,
    input  logic                  retry_done,

    input  logic                  s_valid,
    output logic                  s_ready,
    input  logic [DATA_WIDTH-1:0] s_data,

    output logic                  m_valid,
    input  logic                  m_ready,
    output logic [DATA_WIDTH-1:0] m_data,

    output logic                  link_up,
    output logic [2:0]            link_state
);

    chiplet_link_ctrl u_link_ctrl (
        .clk               (clk),
        .rst_n             (rst_n),
        .training_done     (training_done),
        .recoverable_fault (recoverable_fault),
        .fatal_fault       (fatal_fault),
        .retry_done        (retry_done),
        .link_up           (link_up),
        .state             (link_state)
    );

    chiplet_packet_channel #(
        .DATA_WIDTH(DATA_WIDTH)
    ) u_packet_channel (
        .clk     (clk),
        .rst_n   (rst_n),
        .link_up (link_up),
        .s_valid (s_valid),
        .s_ready (s_ready),
        .s_data  (s_data),
        .m_valid (m_valid),
        .m_ready (m_ready),
        .m_data  (m_data)
    );

endmodule
