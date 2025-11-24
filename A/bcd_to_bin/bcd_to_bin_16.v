module bcd_to_bin_16(clk, rst, init, bcd, bin, done);
    input clk;
    input rst;
    input init;
    input [19:0] bcd;
    output [15:0] bin;    
    output done;

    wire [35:0] w_A;
    wire [35:0] w_A_next;
    wire [4:0] w_ge5;
    wire [4:0] w_sel_sub;
    wire w_sh;
    wire w_sub;
    wire w_dec;
    wire w_z;
    wire [3:0] dmill; 
    wire [3:0] mill; 
    wire [3:0] cent; 
    wire [3:0] dece; 
    wire [3:0] unit; 

    comp_digit c0(.digit(w_A[35:32]), .ge5(w_ge5[4])); 
    comp_digit c1(.digit(w_A[31:28]), .ge5(w_ge5[3])); 
    comp_digit c2(.digit(w_A[27:24]), .ge5(w_ge5[2])); 
    comp_digit c3(.digit(w_A[23:20]), .ge5(w_ge5[1])); 
    comp_digit c4(.digit(w_A[19:16]), .ge5(w_ge5[0])); 

    sub_digit s0(.digit(w_A[35:32]), .ge5(w_ge5[4]), .sub(w_sel_sub[4] & w_sub), .digit_out(dmill));
    sub_digit s1(.digit(w_A[31:28]), .ge5(w_ge5[3]), .sub(w_sel_sub[3] & w_sub), .digit_out(mill));
    sub_digit s2(.digit(w_A[27:24]), .ge5(w_ge5[2]), .sub(w_sel_sub[2] & w_sub), .digit_out(cent));
    sub_digit s3(.digit(w_A[23:20]), .ge5(w_ge5[1]), .sub(w_sel_sub[1] & w_sub), .digit_out(dece));
    sub_digit s4(.digit(w_A[19:16]), .ge5(w_ge5[0]), .sub(w_sel_sub[0] & w_sub), .digit_out(unit));

    rsr rsr0(.clk(clk), .rst(rst), .init(init), .sh(w_sh), .sub(w_sub), .bcd(bcd), 
        .A_in(w_A_next), .A(w_A));
    counter cnt0(.clk(clk), .rst(rst), .init(init), .dec(w_dec), .z(w_z));
    control_bcd_to_bin control0(.clk(clk), .rst(rst), .init(init), .ge5(w_ge5), .z(w_z),
        .w_sh(w_sh), .w_sub(w_sub), .sel_sub(w_sel_sub), .dec(w_dec), .done(done));
    
    assign w_A_next = {dmill, mill, cent, dece, unit, w_A[15:0]};
    assign bin = w_A[15:0];

endmodule