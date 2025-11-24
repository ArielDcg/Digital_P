module comp_digit(digit, ge5);
    input [3:0] digit;
    output reg ge5;

    always @(*) begin
        if (digit > 4'd4)
            ge5 = 1;
        else
            ge5 = 0;
    end
endmodule