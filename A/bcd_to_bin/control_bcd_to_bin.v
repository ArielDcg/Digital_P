module control_bcd_to_bin (clk,rst,init,z,ge5,w_sh,w_sub,dec,done,sel_sub);
input clk;
input rst;
input init;
input z;
input [4:0] ge5;

output reg w_sh;
output reg w_sub;
output reg dec;
output reg done;
output reg [4:0] sel_sub;

parameter START = 3'b000;
parameter SHIFT = 3'b001;
parameter CHECK = 3'b010;
parameter SUB   = 3'b011;
parameter END1  = 3'b100;

reg [2:0] state;

always @(posedge clk or posedge rst) begin
    if (rst)
        state <= START;
    else begin
        case (state)
            START:
                if (init) state <= SHIFT;
                else state <= START;
            SHIFT:
                state <= CHECK;
            CHECK:
                state <= SUB;
            SUB:
                if (z) state <= END1;
                else state <= SHIFT;
            END1:
                state <= START;
            default: state <= START;
        endcase
    end
end

always @(*) begin
    case (state)
        START: begin
            done    = 0;
            w_sh    = 0;
            w_sub   = 0;
            dec     = 0;
            sel_sub = 0;
        end

        SHIFT: begin
            done    = 0;
            w_sh    = 1;     
            w_sub   = 0;
            dec     = 1;
            sel_sub = 0;
        end

        CHECK: begin
            done    = 0;
            w_sh    = 0;
            w_sub   = 0;
            dec     = 0;
            sel_sub = ge5; 
        end

        SUB: begin
            done    = 0;
            w_sh    = 0;
            w_sub   = 1;     
            dec     = 0;     
            sel_sub = ge5;
        end

        END1: begin
            done    = 1;
            w_sh    = 0;
            w_sub   = 0;
            dec     = 0;
            sel_sub = 0;
        end
    endcase
end

`ifdef BENCH
reg [8*20:1] state_name;
always @(*) begin
    case (state)
        START: state_name = "START";
        SHIFT: state_name = "SHIFT";
        CHECK: state_name = "CHECK";
        SUB  : state_name = "SUB";
        END1 : state_name = "END1";
    endcase
end
`endif

endmodule