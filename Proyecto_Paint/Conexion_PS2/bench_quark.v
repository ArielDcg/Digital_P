 module bench();

parameter tck = 37;  // clock 27MHz
parameter clk_ps2 = 60000;  // 60us

reg CLK;
reg RST_N;

wire ps2_clk;
wire ps2_data;

reg ps2_clk_tb = 1'bz;
reg ps2_data_tb = 1'bz;

// pullups
assign (weak1, weak0) ps2_clk = 1'b1;
assign (weak1, weak0) ps2_data = 1'b1;

assign ps2_clk = ps2_clk_tb;
assign ps2_data = ps2_data_tb;

wire [7:0] debug_state;
wire [7:0] debug_pins;
wire led_init_done;
wire led_activity;
wire led_error;
wire uart_tx;

top_ps2_test uut (
   .clk(CLK),
   .rst_n(RST_N),
   .ps2_clk(ps2_clk),
   .ps2_data(ps2_data),
   .debug_state(debug_state),
   .debug_pins(debug_pins),
   .led_init_done(led_init_done),
   .led_activity(led_activity),
   .led_error(led_error),
   .uart_tx(uart_tx)
);

initial CLK = 0;
always #(tck/2) CLK = ~CLK;

// enviar byte por ps2
task enviar_byte_ps2;
   input [7:0] dato;
   integer i;
   reg par;
   begin
      par = ~^dato;  // paridad

      ps2_clk_tb = 0;
      #30000;

      // start bit
      ps2_data_tb = 0;
      ps2_clk_tb = 1;
      #30000;
      ps2_clk_tb = 0;
      #30000;

      // 8 bits
      for (i = 0; i < 8; i = i + 1) begin
         ps2_data_tb = dato[i];
         ps2_clk_tb = 1;
         #30000;
         ps2_clk_tb = 0;
         #30000;
      end

      // paridad
      ps2_data_tb = par;
      ps2_clk_tb = 1;
      #30000;
      ps2_clk_tb = 0;
      #30000;

      // stop bit
      ps2_data_tb = 1;
      ps2_clk_tb = 1;
      #30000;
      ps2_clk_tb = 0;
      #30000;

      ps2_clk_tb = 1'bz;
      ps2_data_tb = 1'bz;
   end
endtask

// recibir comando del host
task recibir_cmd;
   output [7:0] cmd;
   integer i;
   begin
      cmd = 0;

      // esperar que host baje clock
      wait(ps2_clk == 0);
      // esperar request
      wait(ps2_data == 0);
      // esperar que libere clock
      wait(ps2_clk == 1);

      // leer start bit
      wait(ps2_clk == 0);
      #15000;

      // leer 8 bits
      for (i = 0; i < 8; i = i + 1) begin
         wait(ps2_clk == 1);
         wait(ps2_clk == 0);
         #15000;
         cmd[i] = ps2_data;
      end

      // leer paridad
      wait(ps2_clk == 1);
      wait(ps2_clk == 0);
      #15000;

      // leer stop bit
      wait(ps2_clk == 1);
      wait(ps2_clk == 0);
      #15000;

      // enviar ACK
      wait(ps2_clk == 1);
      ps2_data_tb = 0;
      wait(ps2_clk == 0);
      ps2_data_tb = 1'bz;
   end
endtask

// simular mouse
initial begin
   reg [7:0] cmd;

   wait(RST_N == 1);
   #200000000;  // esperar 200ms

   // recibir reset
   recibir_cmd(cmd);

   if (cmd == 8'hFF) begin
      #100000;
      enviar_byte_ps2(8'hFA);  // ACK
      #500000000;  // BAT
      enviar_byte_ps2(8'hAA);  // BAT ok
      #10000;
      enviar_byte_ps2(8'h00);  // ID
   end

   // recibir enable reporting
   recibir_cmd(cmd);

   if (cmd == 8'hF4) begin
      #100000;
      enviar_byte_ps2(8'hFA);  // ACK
      #1000000;

      // paquete 1
      enviar_byte_ps2(8'b00001001);
      #100000;
      enviar_byte_ps2(8'd5);
      #100000;
      enviar_byte_ps2(8'd253);
      #2000000;

      // paquete 2
      enviar_byte_ps2(8'b00001000);
      #100000;
      enviar_byte_ps2(8'd10);
      #100000;
      enviar_byte_ps2(8'd8);
   end
end

initial begin
   $dumpfile("bench.vcd");
   $dumpvars(0, bench);

   RST_N = 0;
   #(tck*10);
   RST_N = 1;

   #1000000000;
   $finish;
end

endmodule   
 
