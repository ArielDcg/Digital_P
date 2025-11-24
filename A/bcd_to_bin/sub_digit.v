module sub_digit(digit, ge5, sub, digit_out);
    input [3:0] digit;
    input ge5; 
    input sub;
    output reg [3:0] digit_out;

    always @(*) begin
        if (sub && ge5)
            digit_out = digit - 4'd3;
        else
            digit_out = digit;
    end
endmodule