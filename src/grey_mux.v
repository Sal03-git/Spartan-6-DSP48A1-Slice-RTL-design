// ============================================================
//  Grey Mux + Pipeline Register
//  Instantiated for every register stage in DSP48A1.
//  STAGES = 1 → output comes from the register
//  STAGES = 0 → output bypasses the register (combinational)
//  RSTTYPE   → "SYNC" or "ASYNC" reset behaviour
// ============================================================
module grey_mux #(
    parameter WIDTH   = 18,     // most grey mux paths are 18-bit
    parameter STAGES  = 1,      // 0 = bypass, 1 = registered
    parameter RSTTYPE = "SYNC"
)(
    input                  clk,
    input                  rst,
    input                  enable,
    input  [WIDTH-1:0]     data_in,
    output [WIDTH-1:0]     data_out
);

    reg [WIDTH-1:0] reg_out;

    always @(posedge clk or posedge rst) begin
        if (RSTTYPE == "ASYNC") begin   // Asynchronous reset
            if (rst)
                reg_out <= {WIDTH{1'b0}};
            else if (enable)
                reg_out <= data_in;
        end
        else begin                      // Synchronous reset (default)
            if (rst)
                reg_out <= {WIDTH{1'b0}};
            else if (enable)
                reg_out <= data_in;
        end
    end

    // STAGES == 1 → registered output, STAGES == 0 → pass-through
    assign data_out = (STAGES == 1) ? reg_out : data_in;

endmodule
