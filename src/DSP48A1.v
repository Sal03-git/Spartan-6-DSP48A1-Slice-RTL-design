// ============================================================
//  DSP48A1 — Spartan-6 DSP Slice RTL Model
//  Digital IC Design Course — AASTMT
//  Author: Salaheldeen Abdelmoneim
// ============================================================
//  Arithmetic pipeline:
//    D / B  →  Pre-Adder/Subtracter
//    A / B  →  18×18 Multiplier
//    M      →  M Register
//    X / Z  →  Post-Adder/Subtracter
//    P      →  P Register
// ============================================================

module DSP48A1 (
    // Data inputs
    input  [17:0] A,
    input  [17:0] B,
    input  [47:0] C,
    input  [17:0] D,
    input  [47:0] PCIN,
    input  [17:0] BCIN,
    input         CARRYIN,

    // Control inputs
    input  [7:0]  OPMODE,
    input         CLK,

    // Reset inputs (active-high)
    input         RSTA, RSTB, RSTC, RSTD, RSTM, RSTP,
    input         RSTCARRYIN, RSTOPMODE,

    // Clock enables
    input         CEA, CEB, CEC, CED, CEM, CEP,
    input         CECARRYIN, CEOPMODE,

    // Outputs
    output [47:0] P,
    output [35:0] M,
    output [17:0] BCOUT,
    output [47:0] PCOUT,
    output        CARRYOUT,
    output        CARRYOUTF
);

    // ── Parameters (attributes) ──────────────────────────────
    parameter A0REG       = 0;
    parameter A1REG       = 1;
    parameter B0REG       = 0;
    parameter B1REG       = 1;
    parameter CREG        = 1;
    parameter DREG        = 1;
    parameter MREG        = 1;
    parameter PREG        = 1;
    parameter CARRYINREG  = 1;
    parameter CARRYOUTREG = 1;
    parameter OPMODEREG   = 1;
    parameter RSTTYPE     = "SYNC";
    parameter CARRYINSEL  = "OPMODE5";  // "CARRYIN" or "OPMODE5"
    parameter B_INPUT     = "DIRECT";   // "DIRECT"  or "CASCADE"

    // ── Input A pipeline: A → A0_REG → A1_REG ────────────────
    wire [17:0] a0_out, a1_out;

    grey_mux #(.WIDTH(18), .STAGES(A0REG), .RSTTYPE(RSTTYPE))
    a0_reg_inst (
        .clk(CLK), .rst(RSTA), .enable(CEA),
        .data_in(A), .data_out(a0_out)
    );

    grey_mux #(.WIDTH(18), .STAGES(A1REG), .RSTTYPE(RSTTYPE))
    a1_reg_inst (
        .clk(CLK), .rst(RSTA), .enable(CEA),
        .data_in(a0_out), .data_out(a1_out)
    );

    // ── Input B: select DIRECT or CASCADE (BCIN) ─────────────
    wire [17:0] b_mux_out;
    assign b_mux_out = (B_INPUT == "DIRECT") ? B : BCIN;

    wire [17:0] b0_out;
    grey_mux #(.WIDTH(18), .STAGES(B0REG), .RSTTYPE(RSTTYPE))
    b0_reg_inst (
        .clk(CLK), .rst(RSTB), .enable(CEB),
        .data_in(b_mux_out), .data_out(b0_out)
    );

    // ── Input D pipeline: D → D_REG ──────────────────────────
    wire [17:0] d_out;
    grey_mux #(.WIDTH(18), .STAGES(DREG), .RSTTYPE(RSTTYPE))
    d_reg_inst (
        .clk(CLK), .rst(RSTD), .enable(CED),
        .data_in(D), .data_out(d_out)
    );

    // ── Pre-Adder / Subtracter: D ± B0 ───────────────────────
    //    OPMODE[6] = 0 → add (D+B), 1 → subtract (D-B)
    wire [17:0] pre_adder_out;
    assign pre_adder_out = (OPMODE[6]) ? (d_out - b0_out)
                                       : (d_out + b0_out);

    // ── B1 input mux: bypass pre-adder or use it ─────────────
    //    OPMODE[4] = 0 → B goes directly to multiplier
    //              = 1 → pre-adder output goes to multiplier
    wire [17:0] b1_mux_out;
    assign b1_mux_out = (OPMODE[4]) ? pre_adder_out : b0_out;

    wire [17:0] b1_out;
    grey_mux #(.WIDTH(18), .STAGES(B1REG), .RSTTYPE(RSTTYPE))
    b1_reg_inst (
        .clk(CLK), .rst(RSTB), .enable(CEB),
        .data_in(b1_mux_out), .data_out(b1_out)
    );

    assign BCOUT = b1_out;

    // ── Input C pipeline: C → C_REG ──────────────────────────
    wire [47:0] c_out;
    grey_mux #(.WIDTH(48), .STAGES(CREG), .RSTTYPE(RSTTYPE))
    c_reg_inst (
        .clk(CLK), .rst(RSTC), .enable(CEC),
        .data_in(C), .data_out(c_out)
    );

    // ── OPMODE register ───────────────────────────────────────
    wire [7:0] opmode_out;
    grey_mux #(.WIDTH(8), .STAGES(OPMODEREG), .RSTTYPE(RSTTYPE))
    opmode_reg_inst (
        .clk(CLK), .rst(RSTOPMODE), .enable(CEOPMODE),
        .data_in(OPMODE), .data_out(opmode_out)
    );

    // ── 18×18 Multiplier ──────────────────────────────────────
    wire [35:0] multiplier_product;
    assign multiplier_product = a1_out * b1_out;

    wire [35:0] m_reg_out;
    grey_mux #(.WIDTH(36), .STAGES(MREG), .RSTTYPE(RSTTYPE))
    m_reg_inst (
        .clk(CLK), .rst(RSTM), .enable(CEM),
        .data_in(multiplier_product), .data_out(m_reg_out)
    );

    assign M = m_reg_out;

    // ── D:A:B concatenation (for X mux option 3) ─────────────
    //    Order: D[11:0], A[17:0], B[17:0]  → 48 bits total
    wire [47:0] d_a_b_concat;
    assign d_a_b_concat = {d_out[11:0], a1_out[17:0], b1_out[17:0]};

    // Extend 36-bit multiplier output to 48 bits (zero-pad MSBs)
    wire [47:0] multiplier_extended;
    assign multiplier_extended = {12'b0, m_reg_out};

    // ── X Multiplexer (OPMODE[1:0]) ───────────────────────────
    //    00 → 0   01 → multiplier product   10 → P   11 → D:A:B
    reg [47:0] X_mux_out;
    always @(*) begin
        case (opmode_out[1:0])
            2'b00: X_mux_out = 48'b0;
            2'b01: X_mux_out = multiplier_extended;
            2'b10: X_mux_out = P;
            2'b11: X_mux_out = d_a_b_concat;
        endcase
    end

    // ── Z Multiplexer (OPMODE[3:2]) ───────────────────────────
    //    00 → 0   01 → PCIN   10 → P   11 → C
    reg [47:0] Z_mux_out;
    always @(*) begin
        case (opmode_out[3:2])
            2'b00: Z_mux_out = 48'b0;
            2'b01: Z_mux_out = PCIN;
            2'b10: Z_mux_out = P;
            2'b11: Z_mux_out = c_out;
        endcase
    end

    // ── Carry-in selection ────────────────────────────────────
    //    CARRYINSEL = "CARRYIN"  → use CARRYIN port
    //    CARRYINSEL = "OPMODE5"  → use OPMODE[5]
    wire carryin_mux;
    assign carryin_mux = (CARRYINSEL == "CARRYIN") ? CARRYIN
                                                    : opmode_out[5];

    wire cin_reg_out;
    grey_mux #(.WIDTH(1), .STAGES(CARRYINREG), .RSTTYPE(RSTTYPE))
    cyi_reg_inst (
        .clk(CLK), .rst(RSTCARRYIN), .enable(CECARRYIN),
        .data_in(carryin_mux), .data_out(cin_reg_out)
    );

    // ── Post-Adder / Subtracter ───────────────────────────────
    //    OPMODE[7] = 0 → Z + (X + CIN)
    //    OPMODE[7] = 1 → Z – (X + CIN)
    wire [48:0] post_adder_out;
    assign post_adder_out = (opmode_out[7])
                            ? (Z_mux_out - (X_mux_out + cin_reg_out))
                            : (Z_mux_out + (X_mux_out + cin_reg_out));

    // ── P output register ─────────────────────────────────────
    grey_mux #(.WIDTH(48), .STAGES(PREG), .RSTTYPE(RSTTYPE))
    p_reg_inst (
        .clk(CLK), .rst(RSTP), .enable(CEP),
        .data_in(post_adder_out[47:0]), .data_out(P)
    );

    // ── Carry-out register ────────────────────────────────────
    wire carryout_raw;
    assign carryout_raw = post_adder_out[48];

    grey_mux #(.WIDTH(1), .STAGES(CARRYOUTREG), .RSTTYPE(RSTTYPE))
    cyo_reg_inst (
        .clk(CLK), .rst(RSTCARRYIN), .enable(CECARRYIN),
        .data_in(carryout_raw), .data_out(CARRYOUT)
    );

    // CARRYOUTF is a copy of CARRYOUT for user FPGA logic
    assign CARRYOUTF = CARRYOUT;

    // PCOUT is a direct copy of P for DSP cascade
    assign PCOUT = P;

endmodule
