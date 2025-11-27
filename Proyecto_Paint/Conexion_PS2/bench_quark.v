module bench();
// Testbench para mouse PS/2
// Clock del sistema 27 MHz
// Simula las respuestas del mouse a los comandos del host
parameter tck              = 37;   // 27 MHz
parameter PS2_CLK_PERIOD   = 60000; // 60us

   reg CLK;
   reg RST_N;

   wire ps2_clk;
   wire ps2_data;

   reg ps2_clk_tb = 1'bz;
   reg ps2_data_tb = 1'bz;

   wire [7:0] debug_state;
   wire [7:0] debug_pins;
   wire led_init_done;
   wire led_activity;
   wire led_error;
   wire uart_tx;

   // Pullups para simular resistencias en las lineas PS/2
   assign (weak1, weak0) ps2_clk = 1'b1;
   assign (weak1, weak0) ps2_data = 1'b1;

   assign ps2_clk = ps2_clk_tb;
   assign ps2_data = ps2_data_tb;


  // Simula el mouse enviando un byte al host
  task MOUSE_SEND_BYTE;
    input [7:0] data_byte;
    integer     i;
    reg         parity;
    begin
      // Calcular paridad impar
      parity = ~^data_byte;

      // Tomar control del clock
      ps2_clk_tb <= 1'b0;
      #(PS2_CLK_PERIOD/2);

      // Send Start Bit
      ps2_data_tb <= 1'b0;
      ps2_clk_tb <= 1'b1;
      #(PS2_CLK_PERIOD/2);
      ps2_clk_tb <= 1'b0;
      #(PS2_CLK_PERIOD/2);

      // Send Data Byte (LSB first)
      for (i=0; i<8; i=i+1)
        begin
          ps2_data_tb <= data_byte[i];
          ps2_clk_tb <= 1'b1;
          #(PS2_CLK_PERIOD/2);
          ps2_clk_tb <= 1'b0;
          #(PS2_CLK_PERIOD/2);
        end

      // Send Parity Bit
      ps2_data_tb <= parity;
      ps2_clk_tb <= 1'b1;
      #(PS2_CLK_PERIOD/2);
      ps2_clk_tb <= 1'b0;
      #(PS2_CLK_PERIOD/2);

      // Send Stop Bit
      ps2_data_tb <= 1'b1;
      ps2_clk_tb <= 1'b1;
      #(PS2_CLK_PERIOD/2);
      ps2_clk_tb <= 1'b0;
      #(PS2_CLK_PERIOD/2);

      // Liberar las lineas
      ps2_clk_tb <= 1'bz;
      ps2_data_tb <= 1'bz;
     end
  endtask // MOUSE_SEND_BYTE


   top_ps2_test uut(
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


initial         CLK <= 0;
always #(tck/2) CLK <= ~CLK;


   reg[7:0] prev_state = 0;
   initial begin
	 if(debug_state != prev_state) begin
	    $display("Estado = %h", debug_state);
	 end
	 prev_state <= debug_state;
   end


   initial begin

      $dumpfile("bench.vcd");
      $dumpvars(0,bench);

      #0   RST_N = 0;
      #80  RST_N = 0;
      #160 RST_N = 1;

      // El mouse espera despues del power-on
      @(posedge CLK);
      #(tck*5400000)  // ~200ms

      // Mouse responde al RESET del host con ACK
      MOUSE_SEND_BYTE(8'hFA);  // ACK
      #(tck*13500000)  // ~500ms BAT
      MOUSE_SEND_BYTE(8'hAA);  // BAT completion
      #(tck*270)
      MOUSE_SEND_BYTE(8'h00);  // Mouse ID

      // Mouse responde al Enable Data Reporting con ACK
      #(tck*2700)
      MOUSE_SEND_BYTE(8'hFA);  // ACK
      #(tck*27000)  // ~1ms

      // Mouse envia paquetes de movimiento
      // Paquete 1: boton izquierdo presionado, X=+5, Y=-3
      MOUSE_SEND_BYTE(8'b00001001);  // Status byte
      #(tck*2700)
      MOUSE_SEND_BYTE(8'd5);         // X movement
      #(tck*2700)
      MOUSE_SEND_BYTE(8'd253);       // Y movement (-3)
      #(tck*54000)  // ~2ms

      // Paquete 2: sin botones, X=+10, Y=+8
      MOUSE_SEND_BYTE(8'b00001000);  // Status byte
      #(tck*2700)
      MOUSE_SEND_BYTE(8'd10);        // X movement
      #(tck*2700)
      MOUSE_SEND_BYTE(8'd8);         // Y movement


      @(posedge CLK);
      #(tck*900000) $finish;
   end


endmodule

