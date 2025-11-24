module counter(clk, rst, init, dec, z);
    input clk;
    input rst;
    input init;
    input dec;
    output reg z;
    reg [4:0] count;

    always @(posedge clk or posedge rst) begin
        if (rst) begin 
            count <= 5'd16; 
            z <= 0; 
        end
        else if (init) begin 
            count <= 5'd16; 
            z <= 0; 
        end
        else if (dec) begin
            z <= (count == 5'd1);
            count <= count - 1;
        end
    end
endmodule