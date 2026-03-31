// ============================================================
//  DSP48A1 Testbench
//  Covers 5 test cases:
//    Section 2.1 — Synchronous reset check
//    Section 2.2 — Path 1: OPMODE = 8'hDD  (Z+X, accumulate via C)
//    Section 2.3 — Path 2: OPMODE = 8'h10  (pre-adder bypass)
//    Section 2.4 — Path 3: OPMODE = 8'h0A  (P accumulator via X)
//    Section 2.5 — Path 4: OPMODE = 8'hA7  (PCIN cascade, subtract)
// ============================================================

`timescale 1ns/1ps

module DSP48A1_tb ();

    // ── DUT parameters ────────────────────────────────────────
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
    parameter CARRYINSEL  = "OPMODE5";
    parameter B_INPUT     = "DIRECT";
    parameter RSTTYPE     = "SYNC";

    // ── Inputs ────────────────────────────────────────────────
    reg [17:0] A, B, D, BCIN;
    reg [47:0] C, PCIN;
    reg [7:0]  OPMODE;
    reg        CLK;
    reg        CARRYIN;
    reg        RSTA, RSTB, RSTC, RSTD, RSTM, RSTP;
    reg        RSTCARRYIN, RSTOPMODE;
    reg        CEA, CEB, CEC, CED, CEM, CEP;
    reg        CECARRYIN, CEOPMODE;

    // ── Outputs ───────────────────────────────────────────────
    wire [47:0] P, PCOUT;
    wire [35:0] M;
    wire [17:0] BCOUT;
    wire        CARRYOUT, CARRYOUTF;

    // ── DUT instantiation ─────────────────────────────────────
    DSP48A1 #(
        .A0REG(A0REG),         .A1REG(A1REG),
        .B0REG(B0REG),         .B1REG(B1REG),
        .CREG(CREG),           .DREG(DREG),
        .MREG(MREG),           .PREG(PREG),
        .CARRYINREG(CARRYINREG), .CARRYOUTREG(CARRYOUTREG),
        .OPMODEREG(OPMODEREG), .CARRYINSEL(CARRYINSEL),
        .B_INPUT(B_INPUT),     .RSTTYPE(RSTTYPE)
    ) DUT (
        .A(A), .B(B), .C(C), .D(D),
        .BCIN(BCIN), .PCIN(PCIN), .CARRYIN(CARRYIN),
        .OPMODE(OPMODE), .CLK(CLK),
        .CEA(CEA),         .CEB(CEB),
        .CEC(CEC),         .CED(CED),
        .CEM(CEM),         .CEP(CEP),
        .CECARRYIN(CECARRYIN), .CEOPMODE(CEOPMODE),
        .RSTA(RSTA),       .RSTB(RSTB),
        .RSTC(RSTC),       .RSTD(RSTD),
        .RSTM(RSTM),       .RSTP(RSTP),
        .RSTCARRYIN(RSTCARRYIN), .RSTOPMODE(RSTOPMODE),
        .P(P), .M(M), .BCOUT(BCOUT), .PCOUT(PCOUT),
        .CARRYOUT(CARRYOUT), .CARRYOUTF(CARRYOUTF)
    );

    // ── Clock: 10 ns period (100 MHz) ────────────────────────
    initial CLK = 0;
    always  #5 CLK = ~CLK;

    // ── Stimulus ─────────────────────────────────────────────
    initial begin

        // ── Section 2.1 — Reset check ────────────────────────
        A       = $random;
        B       = $random;
        C       = $random;
        D       = $random;
        BCIN    = $random;
        PCIN    = $random;
        CARRYIN = $random;
        OPMODE  = $random;

        // Disable all clock enables, assert all resets
        CEA = 0; CEB = 0; CEC = 0; CED = 0;
        CEM = 0; CEP = 0; CECARRYIN = 0; CEOPMODE = 0;

        RSTA = 1; RSTB = 1; RSTC = 1; RSTD = 1;
        RSTM = 1; RSTP = 1; RSTCARRYIN = 1; RSTOPMODE = 1;

        @(negedge CLK);

        if (P == 0 && M == 0 && BCOUT == 0 && PCOUT == 0 && CARRYOUT == 0)
            $display("PASS  Section 2.1 — Reset");
        else
            $display("FAIL  Section 2.1 — Reset: P=%0h M=%0h BCOUT=%0h CARRYOUT=%0b",
                      P, M, BCOUT, CARRYOUT);

        // De-assert all resets, enable all clock enables
        RSTA = 0; RSTB = 0; RSTC = 0; RSTD = 0;
        RSTM = 0; RSTP = 0; RSTCARRYIN = 0; RSTOPMODE = 0;

        CEA = 1; CEB = 1; CEC = 1; CED = 1;
        CEM = 1; CEP = 1; CECARRYIN = 1; CEOPMODE = 1;

        // ── Section 2.2 — Path 1 ─────────────────────────────
        //  OPMODE = 8'b1101_1101
        //    [1:0]=01 → X = multiplier  [3:2]=11 → Z = C
        //    [4]=1    → pre-adder used  [6]=1    → D-B
        //    [7]=1    → subtract: Z-(X+CIN)
        //  A=20, B=10, C=350, D=25
        //  pre-adder: D-B = 25-10 = 15 = 18'hf  → B1
        //  multiplier: A1×B1 = 20×15 = 300 = 36'h12c
        //  Z = C = 350 = 48'h15e, X = 300 extended
        //  post-adder (subtract): 350 - 300 = 50 = 48'h32
        //  Pipeline depth = 4 clock edges
        OPMODE  = 8'b11011101;
        A = 20; B = 10; C = 350; D = 25;
        BCIN    = $random;
        PCIN    = $random;
        CARRYIN = $random;

        repeat(4) @(negedge CLK);

        if (BCOUT == 18'hf && M == 36'h12c && P == 48'h32 && CARRYOUT == 0)
            $display("PASS  Section 2.2 — Path 1");
        else
            $display("FAIL  Section 2.2 — Path 1: BCOUT=%0h M=%0h P=%0h CARRYOUT=%0b",
                      BCOUT, M, P, CARRYOUT);

        // ── Section 2.3 — Path 2 ─────────────────────────────
        //  OPMODE = 8'b0001_0000
        //    [1:0]=00 → X = 0   [3:2]=00 → Z = 0
        //    [4]=1    → pre-adder used  [6]=0 → D+B
        //    [7]=0    → add: Z+X+CIN = 0
        //  pre-adder: D+B = 25+10 = 35 = 18'h23  → B1
        //  multiplier: A1×B1 = 20×35 = 700 = 36'h2bc  → M
        //  P = 0  (X=0, Z=0)
        OPMODE  = 8'b00010000;
        A = 20; B = 10; C = 350; D = 25;
        BCIN    = $random;
        PCIN    = $random;
        CARRYIN = $random;

        repeat(3) @(negedge CLK);

        if (BCOUT == 18'h23 && M == 36'h2bc && P == 0 && CARRYOUT == 0)
            $display("PASS  Section 2.3 — Path 2");
        else
            $display("FAIL  Section 2.3 — Path 2: BCOUT=%0h M=%0h P=%0h CARRYOUT=%0b",
                      BCOUT, M, P, CARRYOUT);

        // ── Section 2.4 — Path 3 ─────────────────────────────
        //  OPMODE = 8'b0000_1010
        //    [1:0]=10 → X = P (accumulator)  [3:2]=00 → Z = 0
        //    [4]=0    → pre-adder bypassed    [6]=0    → D+B (unused)
        //    [7]=0    → add: Z+X+CIN = 0+P+0
        //  B goes directly: B1 = 10 = 18'ha
        //  multiplier: A1×B1 = 20×10 = 200 = 36'hc8  → M
        //  X = P (previous path P=0), Z=0  → new P = 0
        OPMODE  = 8'b00001010;
        A = 20; B = 10; C = 350; D = 25;
        BCIN    = $random;
        PCIN    = $random;
        CARRYIN = $random;

        repeat(3) @(negedge CLK);

        if (BCOUT == 18'ha && M == 36'hc8 && P == 0 && CARRYOUT == 0)
            $display("PASS  Section 2.4 — Path 3");
        else
            $display("FAIL  Section 2.4 — Path 3: BCOUT=%0h M=%0h P=%0h CARRYOUT=%0b",
                      BCOUT, M, P, CARRYOUT);

        // ── Section 2.5 — Path 4 ─────────────────────────────
        //  OPMODE = 8'b1010_0111
        //    [1:0]=11 → X = D:A:B concat  [3:2]=10 → Z = P
        //    [4]=0    → pre-adder bypass   [6]=0    → D+B (unused)
        //    [7]=1    → subtract: Z-(X+CIN)
        //  A=5, B=6, PCIN=3000
        //  BCOUT = B1 = 6 = 18'h6
        //  multiplier: 5×6 = 30 = 36'h1e  → M
        //  concat: {D[11:0], A[17:0], B[17:0]} = {25, 5, 6}
        //  Z = P (previous run's P=0), subtract → P = 0 - concat - 0
        OPMODE  = 8'b10100111;
        A = 5; B = 6; C = 350; D = 25;
        PCIN    = 3000;
        BCIN    = $random;
        CARRYIN = $random;

        repeat(3) @(negedge CLK);

        if (BCOUT == 18'h6 && M == 36'h1e && P == 48'hfe6fffec0bb1 && CARRYOUT == 1)
            $display("PASS  Section 2.5 — Path 4");
        else
            $display("FAIL  Section 2.5 — Path 4: BCOUT=%0h M=%0h P=%0h CARRYOUT=%0b",
                      BCOUT, M, P, CARRYOUT);

        $stop;
    end

endmodule
