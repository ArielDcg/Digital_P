module led_panel_8(clk , rst , init , ZR, ZC, ZD , RST_R, RST_C, RST_D, INC_R, INC_C, INC_D, LATCH, NOE, PX_CLK_EN, ROW, RGB0, RGB1);

    input         rst;
    input         clk;
    input         init;
    input         ZR;
    input         ZC;
    input         ZD;
    output        RST_R;
    output        RST_C;
    output        RST_D;
    output        INC_R;
    output        INC_C;
    output        INC_D;
    output        LATCH;
    output        NOE;
    output        PX_CLK_EN;
    output  [4:0] ROW;
    output  [2:0] RGB0;
    output  [2:0] RGB1;


    wire w_ZR;
    wire w_ZC;
    wire w_ZD;
    wire w_RST_R;
    wire w_RST_C;
    wire w_RST_D;
    wire w_INC_R;
    wire w_INC_C;
    wire w_INC_D;

    parameter  DELAY = 1024;

    wire PIX_ADDR[10:0];
    wire COL [5:0];

    assign PIX_ADDR = {ROW, COL};



    count #(.width(5))    count_row( .clk(clk), .reset(RST_R), .inc(INC_R), .outc(ROW), .zero(w_ZR) );
    count #(.width(6))    count_col( .clk(clk), .reset(RST_C), .inc(INC_C), .outc(COL), .zero(w_ZC) );
    count #(.width (10))  count_delay( .clk(clk), .out(w_ZD));
    memory  mem0 (.clk(clk), .address(PIX_ADDR), .rd(1'b1), .rdata({RGB0, RGB1}));
    ctrl_lp8 ctrl0 (.clk(clk), .init(init), .ZR(w_ZR), .ZC(w_ZC), .ZD(w_ZD), .RST_R(w_RST_R), .RST_C(w_RST_C), .RST_D(w_RST_D)
                    .INC_R(w_INC_R),  .INC_C(w_INC_C), .INC_D(w_INC_D), .LATCH(LATCH), .NOE(NOE), .PX_CLK_EN(PX_CLK_EN)) ;

endmodule
