 module bench();
   // Testbench para protocolo PS/2
   // Clock del sistema: 27 MHz (periodo ~37ns)
   parameter tck = 37;  // 27 MHz system clock

   // Timing del protocolo PS/2
   // PS/2 clock: ~10-16.7 kHz (periodo de 60-100us)
   parameter PS2_CLK_PERIOD = 60000;  // 60us en nanosegundos
   parameter PS2_CLK_HALF = PS2_CLK_PERIOD / 2;  // 30us

   reg CLK;
   reg RST_N;

   // Señales PS/2 bidireccionales
   wire ps2_clk;
   wire ps2_data;

   // Registros para controlar las líneas PS/2 desde el testbench (simulando el mouse)
   reg ps2_clk_tb = 1'bz;   // Alta impedancia (pullup)
   reg ps2_data_tb = 1'bz;  // Alta impedancia (pullup)

   // Pullups débiles para las líneas PS/2
   assign (weak1, weak0) ps2_clk = 1'b1;
   assign (weak1, weak0) ps2_data = 1'b1;

   // Cuando el testbench controla las líneas
   assign ps2_clk = ps2_clk_tb;
   assign ps2_data = ps2_data_tb;

   // Señales de debug
   wire [7:0] debug_state;
   wire [7:0] debug_pins;
   wire led_init_done;
   wire led_activity;
   wire led_error;
   wire uart_tx;

   // Instancia del módulo bajo prueba
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

   // Generación del clock del sistema
   initial CLK = 0;
   always #(tck/2) CLK = ~CLK;

   // Tarea para enviar un byte por PS/2 (Mouse -> Host)
   // Según el protocolo: Start bit (0) + 8 data bits + Parity (odd) + Stop bit (1)
   task PS2_SEND_BYTE;
      input [7:0] data;
      integer i;
      reg parity;
      begin
         // Calcular paridad impar
         parity = ~^data;  // XOR de todos los bits, negado

         $display("[%0t] PS2_SEND_BYTE: Enviando 0x%02h (paridad=%b)", $time, data, parity);

         // Tomar control del clock (bajarlo para indicar inicio)
         ps2_clk_tb = 1'b0;
         #PS2_CLK_HALF;

         // Start bit (data = 0)
         ps2_data_tb = 1'b0;
         ps2_clk_tb = 1'b1;  // Clock alto
         #PS2_CLK_HALF;
         ps2_clk_tb = 1'b0;  // Clock bajo
         #PS2_CLK_HALF;

         // Enviar 8 bits de datos (LSB primero)
         for (i = 0; i < 8; i = i + 1) begin
            ps2_data_tb = data[i];
            ps2_clk_tb = 1'b1;  // Clock alto
            #PS2_CLK_HALF;
            ps2_clk_tb = 1'b0;  // Clock bajo
            #PS2_CLK_HALF;
         end

         // Bit de paridad
         ps2_data_tb = parity;
         ps2_clk_tb = 1'b1;
         #PS2_CLK_HALF;
         ps2_clk_tb = 1'b0;
         #PS2_CLK_HALF;

         // Stop bit (data = 1)
         ps2_data_tb = 1'b1;
         ps2_clk_tb = 1'b1;
         #PS2_CLK_HALF;
         ps2_clk_tb = 1'b0;
         #PS2_CLK_HALF;

         // Liberar las líneas (volver a alta impedancia)
         ps2_clk_tb = 1'bz;
         ps2_data_tb = 1'bz;

         $display("[%0t] PS2_SEND_BYTE: Byte enviado completamente", $time);
      end
   endtask

   // Tarea para recibir un byte del host (Host -> Mouse)
   // El host toma control inhibiendo el clock, luego pone data=0 (request to send)
   task PS2_WAIT_HOST_COMMAND;
      output [7:0] cmd;
      integer i;
      reg parity_received;
      reg parity_calc;
      begin
         cmd = 8'h00;

         // Esperar a que el host tome control del clock (lo baje)
         wait(ps2_clk == 1'b0);
         $display("[%0t] PS2_WAIT_HOST_COMMAND: Host tomó control del clock", $time);

         // Esperar a que el host ponga data=0 (request to send)
         wait(ps2_data == 1'b0);
         $display("[%0t] PS2_WAIT_HOST_COMMAND: Host puso data=0 (request)", $time);

         // Esperar a que el host libere el clock
         wait(ps2_clk == 1'b1);

         // Ahora el mouse toma control del clock para leer datos
         // Start bit (debe ser 0)
         wait(ps2_clk == 1'b0);  // Flanco de bajada
         #(PS2_CLK_HALF/2);
         if (ps2_data != 1'b0) begin
            $display("[%0t] ERROR: Start bit no es 0!", $time);
         end

         // Leer 8 bits de datos
         for (i = 0; i < 8; i = i + 1) begin
            wait(ps2_clk == 1'b1);  // Flanco de subida
            wait(ps2_clk == 1'b0);  // Flanco de bajada
            #(PS2_CLK_HALF/2);
            cmd[i] = ps2_data;
         end

         // Leer bit de paridad
         wait(ps2_clk == 1'b1);
         wait(ps2_clk == 1'b0);
         #(PS2_CLK_HALF/2);
         parity_received = ps2_data;

         // Verificar paridad
         parity_calc = ~^cmd;
         if (parity_received != parity_calc) begin
            $display("[%0t] ERROR: Paridad incorrecta! Recibida=%b, Calculada=%b",
                     $time, parity_received, parity_calc);
         end

         // Leer stop bit
         wait(ps2_clk == 1'b1);
         wait(ps2_clk == 1'b0);
         #(PS2_CLK_HALF/2);
         if (ps2_data != 1'b1) begin
            $display("[%0t] ERROR: Stop bit no es 1!", $time);
         end

         // Enviar ACK (poner data=0 durante un ciclo de clock)
         wait(ps2_clk == 1'b1);
         ps2_data_tb = 1'b0;  // ACK
         wait(ps2_clk == 1'b0);
         ps2_data_tb = 1'bz;  // Liberar

         $display("[%0t] PS2_WAIT_HOST_COMMAND: Comando recibido: 0x%02h", $time, cmd);
      end
   endtask

   // Proceso que simula el comportamiento del mouse PS/2
   initial begin
      reg [7:0] cmd;

      // Esperar el reset
      wait(RST_N == 1'b1);
      $display("[%0t] Mouse PS/2: Reset liberado, esperando comandos...", $time);

      // Esperar 200ms después del power-on (tiempo de auto-test del mouse)
      #200000000;  // 200ms

      // Esperar comando de reset (0xFF) del host
      $display("[%0t] Mouse PS/2: Esperando comando RESET...", $time);
      PS2_WAIT_HOST_COMMAND(cmd);

      if (cmd == 8'hFF) begin
         $display("[%0t] Mouse PS/2: RESET recibido, ejecutando BAT...", $time);

         // Enviar ACK
         #100000;  // Pequeño delay
         PS2_SEND_BYTE(8'hFA);  // ACK

         // Ejecutar BAT (Basic Assurance Test) - toma ~500ms
         #500000000;

         // Enviar BAT completion code
         PS2_SEND_BYTE(8'hAA);
         $display("[%0t] Mouse PS/2: BAT completado (0xAA)", $time);

         // Enviar device ID
         #10000;
         PS2_SEND_BYTE(8'h00);  // Mouse ID
         $display("[%0t] Mouse PS/2: Device ID enviado (0x00)", $time);
      end

      // Esperar comando Enable Data Reporting (0xF4)
      $display("[%0t] Mouse PS/2: Esperando comando Enable Data Reporting...", $time);
      PS2_WAIT_HOST_COMMAND(cmd);

      if (cmd == 8'hF4) begin
         $display("[%0t] Mouse PS/2: Enable Data Reporting recibido", $time);

         // Enviar ACK
         #100000;
         PS2_SEND_BYTE(8'hFA);
         $display("[%0t] Mouse PS/2: ACK enviado, entrando en Stream Mode", $time);

         // Ahora el mouse está en Stream Mode
         // Enviar algunos paquetes de datos de prueba
         #1000000;  // 1ms

         // Paquete 1: Botón izquierdo presionado, movimiento X=+5, Y=-3
         PS2_SEND_BYTE(8'b00001001);  // Byte 1: Y_overflow=0, X_overflow=0, Y_sign=1, X_sign=0, Always1=1, Middle=0, Right=0, Left=1
         #100000;
         PS2_SEND_BYTE(8'd5);         // Byte 2: X movement
         #100000;
         PS2_SEND_BYTE(8'd253);       // Byte 3: Y movement (-3 en complemento a 2)

         #2000000;  // 2ms

         // Paquete 2: Sin botones, movimiento X=+10, Y=+8
         PS2_SEND_BYTE(8'b00001000);  // Byte 1: Sin botones presionados
         #100000;
         PS2_SEND_BYTE(8'd10);        // Byte 2: X movement
         #100000;
         PS2_SEND_BYTE(8'd8);         // Byte 3: Y movement

         $display("[%0t] Mouse PS/2: Paquetes de datos enviados", $time);
      end
   end

   // Monitor de señales de debug
   always @(debug_state) begin
      $display("[%0t] Estado FSM: 0x%02h", $time, debug_state);
   end

   always @(posedge led_init_done) begin
      $display("[%0t] *** INICIALIZACIÓN COMPLETADA ***", $time);
   end

   always @(posedge led_activity) begin
      $display("[%0t] Actividad detectada - Datos recibidos: 0x%02h", $time, debug_pins);
   end

   // Generación de archivos de forma de onda
   initial begin
      $dumpfile("bench.vcd");
      $dumpvars(0, bench);

      // Reset inicial
      RST_N = 0;
      #(tck*10);
      RST_N = 1;
      $display("[%0t] Reset liberado", $time);

      // Ejecutar simulación por 1 segundo
      #1000000000;  // 1 segundo

      $display("[%0t] Simulación completada", $time);
      $finish;
   end

endmodule   
 
