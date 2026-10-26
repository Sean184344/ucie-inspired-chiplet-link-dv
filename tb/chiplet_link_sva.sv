module chiplet_link_sva #(
    parameter logic [2:0] FAILED_STATE = 3'd4
) (
    input logic clk,
    input logic rst_n,
    input logic link_up,
    input logic [2:0] link_state,
    input logic m_valid,
    input logic m_ready,
    input logic [31:0] m_data
);

    // A down link must never expose a valid output transaction.
    property p_no_valid_when_link_down;
        @(posedge clk)
        disable iff (!rst_n)
        !link_up |-> !m_valid;
    endproperty

    a_no_valid_when_link_down:
        assert property (p_no_valid_when_link_down)
        else $error("SVA FAIL: m_valid asserted while link is down");

    // A stalled packet must retain its payload.
    // If the link drops, m_valid may be suppressed.
    property p_stalled_payload_stable;
        @(posedge clk)
        disable iff (!rst_n)
        (m_valid && !m_ready)
        |=> (!link_up || (m_valid && $stable(m_data)));
    endproperty

    a_stalled_payload_stable:
        assert property (p_stalled_payload_stable)
        else $error("SVA FAIL: stalled packet payload changed");

    // FAILED must persist unless reset disables the property.
    property p_failed_state_sticky;
        @(posedge clk)
        disable iff (!rst_n)
        (link_state == FAILED_STATE)
        |=> (link_state == FAILED_STATE);
    endproperty

    a_failed_state_sticky:
        assert property (p_failed_state_sticky)
        else $error("SVA FAIL: FAILED state was not sticky");

endmodule
