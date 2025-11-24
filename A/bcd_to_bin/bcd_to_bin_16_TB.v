`timescale 1ns / 1ps
`define SIMULATION
`define BENCH   

module bcd_to_bin_16_TB;

    reg clk;
    reg rst;
    reg start;
    reg [19:0] bcd;
    wire [15:0] bin;
    wire done;

    bcd_to_bin_16 uut (.clk(clk), .rst(rst), .init(start), .bcd(bcd), .bin(bin), .done(done));

    parameter PERIOD = 20;
    parameter real DUTY_CYCLE = 0.5;
    parameter OFFSET = 0;

    // Clock
    initial begin
        clk = 0;
        #OFFSET;
        forever begin
            #(PERIOD * (1 - DUTY_CYCLE)) clk = 1;
            #(PERIOD * DUTY_CYCLE) clk = 0;
        end
    end

    initial begin
        rst = 1;
        start = 0;

        bcd = 20'b0000_0000_0001_0010_0011;

        #40;
        rst = 0;

        #40 start = 1;
        #20 start = 0;

        wait(done == 1);
        #20;

        $display("BIN Output = %0d", bin);

        #40 $finish;
    end

    initial begin
        $dumpfile("bcd_to_bin_16_TB.vcd");
        $dumpvars(0, bcd_to_bin_16_TB);
    end

endmodule
