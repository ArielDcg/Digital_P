`timescale 1ns / 1ps
`define SIMULATION
module led_panel_4k_TB();
reg  clk;
reg  rst;
reg  init;
wire  LATCH;
wire  NOE;
wire  [4:0] ROW;
wire  [2:0] RGB0;
wire  [2:0] RGB1;
reg  mouse_data_valid_sim; 
reg  [11:0] write_data_sim; 
reg  [11:0] write_addr_sim;

led_panel_4k uut (
      .clk(clk),
      .rst(rst),
      .init(init),
      .LATCH(LATCH),
      .NOE(NOE),
      .ROW(ROW),
      .RGB0(RGB0),
      .RGB1(RGB1)
   );

parameter PERIOD = 20;

// Initialize Inputs
initial begin  
      clk = 0; rst = 0; init = 0;
end

// clk generation
initial         clk <= 0;
always #(PERIOD/2) clk <= ~clk;

initial begin 
// Reset 
     @ (posedge clk);
      rst = 1;
      @ (posedge clk);
      rst = 0;
     #(PERIOD*4)
      init = 1;
end

initial begin: TEST_WRITE
    #(PERIOD*100);  // Espera 2μs
    @ (posedge clk);
    
    // Forzar una ESCRITURA correctamente
    force uut.mem0.wr0 = 1;              // Activa escritura en MEM0
    force uut.mem0.address = 12'd100;    // Dirección 100
    force uut.mem0.wdata = 12'h004;      // Dato: color azul
    
    @ (posedge clk);  // Espera que se escriba
    
    // Liberar señales
    release uut.mem0.wr0;
    release uut.mem0.address;
    release uut.mem0.wdata;
    
    #(PERIOD*10);  // Espera unos ciclos
    
    // Ahora LEER para verificar
    @ (posedge clk);
    force uut.mem0.rd = 1;
    force uut.mem0.address = 12'd100;
    
    @ (posedge clk);
    @ (posedge clk);  // Espera que se complete la lectura
    
    release uut.mem0.rd;
    release uut.mem0.address;
end

initial begin: TEST_CASE
$dumpfile("led_panel_4k_TB.vcd");
$dumpvars(0, led_panel_4k_TB);
     #(PERIOD*1000000) $finish;
end

endmodule