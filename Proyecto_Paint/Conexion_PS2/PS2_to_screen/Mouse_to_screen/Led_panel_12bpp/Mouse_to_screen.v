module Mouse_to_screen#(
    parameter X_MAX = 63,
    parameter Y_MAX = 63,
    parameter IMG_WIDTH = 16'd64,
    parameter IMG_DIV = 32,
    parameter PIXEL_COLOR = 12'h004
)(
    input              clk,
    input              reset,
    input              packet_ready,
    input [8:0]        PS2_Xdata,
    input [8:0]        PS2_Ydata,
    input  [11:0]      b_rdata0,
    input  [11:0]      b_rdata1,
    output reg         wr0,
    output reg         wr1,
    output reg [11:0]  wdata,
    output reg [11:0]  address
);

reg [2:0] estado; 
localparam START        = 3'b000;
localparam START_MULT   = 3'b001; 
localparam WAIT_MULT    = 3'b010; 
localparam RESTORE      = 3'b011; 
localparam PAINT        = 3'b100; 
reg [11:0] dir_anterior; 
reg        mem_anterior; 
reg [6:0] x_fin, y_fin, y_offset;
reg       sel_mem_actual;

//Calculo de valor final de X,Y
always @(*) begin
    if ($signed(PS2_Xdata) > $signed(X_MAX))
        x_fin = X_MAX;
    else if ($signed(PS2_Xdata) < 0)
        x_fin = 0;
    else
        x_fin = PS2_Xdata[6:0];

    if ($signed(PS2_Ydata) > $signed(Y_MAX))
        y_fin = Y_MAX;
    else if ($signed(PS2_Ydata) < 0)
        y_fin = 0;
    else
        y_fin = PS2_Ydata[6:0];

    sel_mem_actual = (y_fin > IMG_DIV);

    if (sel_mem_actual)
        y_offset = y_fin - (IMG_DIV + 1);
    else
        y_offset = y_fin;
end

reg init_mult;
wire done_mult;
wire [31:0] result_mult;
wire [11:0] y_mult_result = result_mult[11:0];
wire [11:0] dir_actual = y_mult_result + x_fin;
wire movimiento_detectado = packet_ready && (estado == START);

//Aplicaciòn del modulo de multiplicaciòn
mult u_multiplier (
    .clk    (clk),
    .reset  (reset),
    .init   (init_mult),             
    .op_A   ({9'b0, y_offset}),      
    .op_B   (IMG_WIDTH),             
    .result (result_mult),           
    .done   (done_mult)              
);

//Maquina de control
always @(posedge clk) begin
    wr0 <= 0;
    wr1 <= 0;
    init_mult <= 0;
    
    if (reset) begin
        estado <= START;
        dir_anterior <= 12'h0;
        mem_anterior <= 1'b0;
    end else begin
        
        case (estado)
            START: begin
                if (movimiento_detectado) begin
                    estado <= START_MULT; 
                end
            end

            START_MULT: begin
                init_mult <= 1;
                estado <= WAIT_MULT;
            end

            WAIT_MULT: begin
                if (done_mult) begin
                    
                    estado <= RESTORE;
                end else begin
                    estado <= WAIT_MULT; 
                end
            end

            RESTORE: begin 
                address <= dir_anterior; 
                
                if (mem_anterior == 0) begin 
                    wdata <= b_rdata0; 
                    wr0 <= 1;
                end 
                else begin 
                    wdata <= b_rdata1;
                    wr1 <= 1;
                end
                
                estado <= PAINT; 
            end

            PAINT: begin 
                address <= dir_actual; 
                wdata <= PIXEL_COLOR; 
                
                if (sel_mem_actual == 0) begin 
                    wr0 <= 1;
                end 
                else begin 
                    wr1 <= 1;
                end

                dir_anterior <= dir_actual;
                mem_anterior <= sel_mem_actual;
                
                estado <= START; 
            end
            
            default: estado <= START;
        endcase
    end
end

endmodule