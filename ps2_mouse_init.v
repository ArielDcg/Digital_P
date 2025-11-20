// ps2_mouse_init.v
// Módulo para inicializar un mouse PS/2 enviando el comando 0xF4 (Enable Data Reporting)

module ps2_mouse_init (
    input  wire clk,           // Clock del sistema (27MHz en Tang Primer 25K)
    input  wire rst_n,         // Reset activo en bajo
    
    // Interfaz PS/2 bidireccional
    inout  wire ps2_clk,       // Clock PS/2 (bidireccional)
    inout  wire ps2_data,      // Data PS/2 (bidireccional)
    
    // Señales de debug para analizador lógico
    output wire [7:0] debug_state,    // Estado actual de la FSM
    output wire [7:0] debug_data,     // Datos siendo transmitidos/recibidos
    output wire debug_busy,            // Indicador de transmisión activa
    output wire debug_ack,             // ACK recibido del mouse
    output wire init_done,             // Inicialización completa
    output wire [7:0] rx_data,         // Datos recibidos del mouse
    output wire rx_data_valid          // Pulso cuando hay datos válidos
);

    // Estados de la máquina de estados
    localparam STATE_IDLE           = 8'h00;
    localparam STATE_RESET_WAIT     = 8'h01;
    localparam STATE_SEND_RESET     = 8'h02;
    localparam STATE_WAIT_BAT       = 8'h03;
    localparam STATE_WAIT_ID        = 8'h04;
    localparam STATE_SEND_F4        = 8'h05;
    localparam STATE_WAIT_F4_ACK    = 8'h06;
    localparam STATE_STREAM_MODE    = 8'h07;
    
    // Registros de estado
    reg [7:0] state, next_state;
    reg [31:0] delay_counter;
    reg [7:0] tx_data_reg;
    reg tx_start;
    reg init_complete;
    
    // Señales del transmisor PS/2
    wire tx_busy;
    wire tx_ack;
    wire tx_error;
    
    // Señales del receptor PS/2
    wire [7:0] rx_byte;
    wire rx_ready;
    
    // Control bidireccional de las líneas PS/2
    wire ps2_clk_out, ps2_data_out;
    wire ps2_clk_oe, ps2_data_oe;   // Output enable
    
    // Implementación de pines bidireccionales
    assign ps2_clk  = ps2_clk_oe  ? ps2_clk_out  : 1'bz;
    assign ps2_data = ps2_data_oe ? ps2_data_out : 1'bz;
    
    // Instancia del transmisor PS/2
    ps2_transmitter ps2_tx (
        .clk(clk),
        .rst_n(rst_n),
        .tx_data(tx_data_reg),
        .tx_start(tx_start),
        .ps2_clk_in(ps2_clk),
        .ps2_data_in(ps2_data),
        .ps2_clk_out(ps2_clk_out),
        .ps2_data_out(ps2_data_out),
        .ps2_clk_oe(ps2_clk_oe),
        .ps2_data_oe(ps2_data_oe),
        .busy(tx_busy),
        .ack_received(tx_ack),
        .error(tx_error)
    );
    
    // Instancia del receptor PS/2
    ps2_receiver ps2_rx (
        .clk(clk),
        .rst_n(rst_n),
        .ps2_clk(ps2_clk),
        .ps2_data(ps2_data),
        .rx_data(rx_byte),
        .rx_ready(rx_ready)
    );
    
    // Máquina de estados principal
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= STATE_IDLE;
            delay_counter <= 32'd0;
            tx_data_reg <= 8'h00;
            tx_start <= 1'b0;
            init_complete <= 1'b0;
        end else begin
            state <= next_state;

            // Control del contador de delay (decrementar o cargar nuevo valor)
            case (state)
                STATE_IDLE: begin
                    if (delay_counter == 0) begin
                        delay_counter <= 32'd2700000; // ~100ms @ 27MHz
                    end else begin
                        delay_counter <= delay_counter - 1;
                    end
                end

                STATE_RESET_WAIT: begin
                    if (delay_counter == 0) begin
                        tx_data_reg <= 8'hFF;  // Comando RESET
                        tx_start <= 1'b1;
                    end else begin
                        delay_counter <= delay_counter - 1;
                    end
                end

                STATE_SEND_RESET: begin
                    if (tx_start)
                        tx_start <= 1'b0;
                end

                STATE_WAIT_ID: begin
                    if (rx_ready) begin
                        delay_counter <= 32'd270000; // ~10ms
                    end else if (delay_counter > 0) begin
                        delay_counter <= delay_counter - 1;
                    end
                end

                STATE_SEND_F4: begin
                    if (delay_counter == 0 && !tx_busy && !tx_start) begin
                        tx_data_reg <= 8'hF4;  // Enable Data Reporting
                        tx_start <= 1'b1;
                    end else begin
                        if (tx_start)
                            tx_start <= 1'b0;
                        if (delay_counter > 0)
                            delay_counter <= delay_counter - 1;
                    end
                end

                STATE_WAIT_F4_ACK: begin
                    if (tx_start)
                        tx_start <= 1'b0;
                    if (!tx_busy && tx_ack && rx_ready && rx_byte == 8'hFA) begin
                        init_complete <= 1'b1;
                    end
                end

                default: begin
                    if (tx_start)
                        tx_start <= 1'b0;
                    if (delay_counter > 0)
                        delay_counter <= delay_counter - 1;
                end
            endcase
        end
    end

    // Lógica combinacional de siguiente estado (solo calcula next_state)
    always @(*) begin
        next_state = state;

        case (state)
            STATE_IDLE: begin
                if (delay_counter == 0) begin
                    next_state = STATE_RESET_WAIT;
                end
            end

            STATE_RESET_WAIT: begin
                if (delay_counter == 0) begin
                    next_state = STATE_SEND_RESET;
                end
            end

            STATE_SEND_RESET: begin
                if (!tx_busy && tx_ack) begin
                    next_state = STATE_WAIT_BAT;
                end
            end

            STATE_WAIT_BAT: begin
                if (rx_ready && rx_byte == 8'hAA) begin  // BAT completion code
                    next_state = STATE_WAIT_ID;
                end
            end

            STATE_WAIT_ID: begin
                if (rx_ready) begin  // Mouse ID (típicamente 0x00)
                    next_state = STATE_SEND_F4;
                end
            end

            STATE_SEND_F4: begin
                if (delay_counter == 0 && !tx_busy) begin
                    next_state = STATE_WAIT_F4_ACK;
                end
            end

            STATE_WAIT_F4_ACK: begin
                if (!tx_busy && tx_ack) begin
                    if (rx_ready && rx_byte == 8'hFA) begin  // ACK del mouse
                        next_state = STATE_STREAM_MODE;
                    end
                end
            end

            STATE_STREAM_MODE: begin
                // Mouse está en stream mode, listo para enviar datos
                // Permanecemos aquí recibiendo datos
            end

            default: begin
                next_state = STATE_IDLE;
            end
        endcase
    end
    
    // Salidas de debug
    assign debug_state = state;
    assign debug_data = (state == STATE_STREAM_MODE) ? rx_byte : tx_data_reg;
    assign debug_busy = tx_busy;
    assign debug_ack = tx_ack;
    assign init_done = init_complete;
    assign rx_data = rx_byte;
    assign rx_data_valid = rx_ready;

endmodule

// Módulo transmisor PS/2 (host to device)
module ps2_transmitter (
    input  wire clk,
    input  wire rst_n,
    input  wire [7:0] tx_data,
    input  wire tx_start,
    input  wire ps2_clk_in,
    input  wire ps2_data_in,
    output reg  ps2_clk_out,
    output reg  ps2_data_out,
    output reg  ps2_clk_oe,
    output reg  ps2_data_oe,
    output reg  busy,
    output reg  ack_received,
    output reg  error
);
    
    // Estados del transmisor
    localparam TX_IDLE = 0;
    localparam TX_INHIBIT = 1;
    localparam TX_REQUEST = 2;
    localparam TX_CLOCK_WAIT = 3;
    localparam TX_SEND_BIT = 4;
    localparam TX_RELEASE = 5;
    localparam TX_WAIT_ACK = 6;
    
    reg [3:0] tx_state;
    reg [15:0] timer;
    reg [3:0] bit_count;
    reg [10:0] tx_shift_reg;
    reg ps2_clk_sync, ps2_clk_prev;
    reg parity;
    
    // Sincronización del clock PS/2
    always @(posedge clk) begin
        ps2_clk_sync <= ps2_clk_in;
        ps2_clk_prev <= ps2_clk_sync;
    end
    
    // Detección de flanco de bajada
    wire ps2_clk_negedge = ps2_clk_prev & ~ps2_clk_sync;
    
    // Cálculo de paridad (impar)
    always @(*) begin
        parity = ~^tx_data;  // Paridad impar
    end
    
    // Máquina de estados del transmisor
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_state <= TX_IDLE;
            timer <= 0;
            bit_count <= 0;
            busy <= 0;
            ack_received <= 0;
            error <= 0;
            ps2_clk_oe <= 0;
            ps2_data_oe <= 0;
            ps2_clk_out <= 1;
            ps2_data_out <= 1;
        end else begin
            case (tx_state)
                TX_IDLE: begin
                    if (tx_start) begin
                        busy <= 1;
                        ack_received <= 0;
                        error <= 0;
                        // Preparar frame: start(0) + data + parity + stop(1)
                        tx_shift_reg <= {1'b1, parity, tx_data, 1'b0};
                        bit_count <= 0;
                        timer <= 3000; // ~111µs @ 27MHz
                        // Inhibir comunicación
                        ps2_clk_oe <= 1;
                        ps2_clk_out <= 0;
                        ps2_data_oe <= 0;
                        tx_state <= TX_INHIBIT;
                    end
                end
                
                TX_INHIBIT: begin
                    if (timer > 0) begin
                        timer <= timer - 1;
                    end else begin
                        // Request to send
                        ps2_data_oe <= 1;
                        ps2_data_out <= 0;
                        timer <= 20;
                        tx_state <= TX_REQUEST;
                    end
                end
                
                TX_REQUEST: begin
                    if (timer > 0) begin
                        timer <= timer - 1;
                    end else begin
                        // Liberar clock
                        ps2_clk_oe <= 0;
                        tx_state <= TX_CLOCK_WAIT;
                    end
                end
                
                TX_CLOCK_WAIT: begin
                    // Esperar flanco de bajada del clock
                    if (ps2_clk_negedge) begin
                        ps2_data_out <= tx_shift_reg[0];
                        tx_shift_reg <= {1'b0, tx_shift_reg[10:1]};
                        bit_count <= bit_count + 1;
                        tx_state <= TX_SEND_BIT;
                    end
                end
                
                TX_SEND_BIT: begin
                    if (bit_count < 11) begin
                        if (ps2_clk_negedge) begin
                            ps2_data_out <= tx_shift_reg[0];
                            tx_shift_reg <= {1'b0, tx_shift_reg[10:1]};
                            bit_count <= bit_count + 1;
                        end
                    end else begin
                        // Liberar línea de datos
                        ps2_data_oe <= 0;
                        tx_state <= TX_WAIT_ACK;
                    end
                end
                
                TX_WAIT_ACK: begin
                    if (ps2_clk_negedge) begin
                        // El mouse debe poner data en bajo (ACK)
                        if (!ps2_data_in) begin
                            ack_received <= 1;
                        end else begin
                            error <= 1;
                        end
                        busy <= 0;
                        tx_state <= TX_IDLE;
                    end
                end
                
                default: tx_state <= TX_IDLE;
            endcase
        end
    end

endmodule

// Módulo receptor PS/2 (device to host)
module ps2_receiver (
    input  wire clk,
    input  wire rst_n,
    input  wire ps2_clk,
    input  wire ps2_data,
    output reg  [7:0] rx_data,
    output reg  rx_ready
);
    
    reg [10:0] rx_shift_reg;
    reg [3:0] bit_count;
    reg ps2_clk_sync, ps2_clk_prev;
    reg ps2_data_sync;
    reg receiving;
    
    // Sincronización
    always @(posedge clk) begin
        ps2_clk_sync <= ps2_clk;
        ps2_clk_prev <= ps2_clk_sync;
        ps2_data_sync <= ps2_data;
    end
    
    // Detección de flanco de bajada
    wire ps2_clk_negedge = ps2_clk_prev & ~ps2_clk_sync;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_shift_reg <= 0;
            bit_count <= 0;
            rx_data <= 0;
            rx_ready <= 0;
            receiving <= 0;
        end else begin
            rx_ready <= 0;  // Pulso de un ciclo
            
            if (!receiving) begin
                // Detectar bit de start
                if (ps2_clk_negedge && !ps2_data_sync) begin
                    receiving <= 1;
                    bit_count <= 0;
                    rx_shift_reg <= 0;
                end
            end else begin
                if (ps2_clk_negedge) begin
                    if (bit_count < 10) begin
                        rx_shift_reg <= {ps2_data_sync, rx_shift_reg[10:1]};
                        bit_count <= bit_count + 1;
                    end else begin
                        // Frame completo
                        if (rx_shift_reg[10]) begin  // Verificar stop bit
                            rx_data <= rx_shift_reg[8:1];  // Extraer datos
                            rx_ready <= 1;
                        end
                        receiving <= 0;
                    end
                end
            end
        end
    end

endmodule