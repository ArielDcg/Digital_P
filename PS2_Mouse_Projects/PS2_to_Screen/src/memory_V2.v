module memory#(
    parameter size = 2047,
    parameter width = 11
)(
  input             clk,
  input  [width:0]  address,
  input             rd,
  input             wr0,
  input             wr1,
  input  [11:0]     wdata,
  output reg [23:0]  rdata,
  output wire [11:0] b_rdata0,
  output wire [11:0] b_rdata1
);

reg [11:0] MEM0 [0:size];
reg [11:0] MEM1 [0:size];
reg [11:0] B_MEM0 [0:size];
reg [11:0] B_MEM1 [0:size];

assign b_rdata0 = B_MEM0[address];
assign b_rdata1 = B_MEM1[address];


initial begin
    $readmemh("./image0.hex",MEM0);
    $readmemh("./image1.hex",MEM1);
    $readmemh("./image0.hex", B_MEM0);
    $readmemh("./image1.hex", B_MEM1);
end

//Escritura de datos en la memoria
always @(posedge clk) begin
  if (wr0) begin 
      MEM0[address] <= wdata;
  end
  if (wr1) begin 
      MEM1[address] <= wdata;
  end
end

//Lectura de datos
always @(negedge clk) begin
    if(rd) begin
        rdata[23:12] <= MEM0[address];     //{RGB0,RGB1}
        rdata[11:0] <= MEM1[address];      //{RGB0,RGB1}
    end
end
endmodule
