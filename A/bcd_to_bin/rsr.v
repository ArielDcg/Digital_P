module rsr(clk, rst, init, sh, sub, bcd, A_in, A);
    input clk; 
    input rst;
    input init;
    input sh;
    input sub;
    input [19:0] bcd;
    input [35:0] A_in;     
    output reg [35:0] A;

    always @(posedge clk or posedge rst) begin
        if (rst)
            A <= 36'd0;
        else if (init)
            A <= {bcd, 16'd0};
        else if (sub)
            A <= A_in;
        else if (sh)
            A <= A >> 1; 
    end
endmodule