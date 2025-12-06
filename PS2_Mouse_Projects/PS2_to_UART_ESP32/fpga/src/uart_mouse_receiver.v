// uart_mouse_receiver.v
// Módulo FPGA que recibe datos del mouse PS/2 desde ESP32 vía UART
//
// Arquitectura:
//   Mouse PS/2 → ESP32 (lee PS/2) → UART → FPGA (este módulo)
//
// Protocolo UART (6 bytes por paquete):
//   Byte 0: 0xAA (sincronización)
//   Byte 1: X[7:0]
//   Byte 2: {7'b0, X[8]} (signo de X)
//   Byte 3: Y[7:0]
//   Byte 4: {7'b0, Y[8]} (signo de Y)
//   Byte 5: {5'b0, buttons[2:0]} [Middle, Right, Left]

module uart_mouse_receiver #(
    parameter FREQ_HZ = 27000000,   // Frecuencia del reloj del sistema
    parameter BAUD = 115200         // Velocidad UART
) (
    input  wire       clk,          // Reloj del sistema
    input  wire       rst_n,        // Reset activo bajo

    // Interfaz UART
    input  wire       uart_rxd,     // Línea RX de UART (desde ESP32)

    // Salidas del mouse
    output reg  [8:0] mouse_x,      // Movimiento X (9 bits con signo)
    output reg  [8:0] mouse_y,      // Movimiento Y (9 bits con signo)
    output reg  [2:0] buttons,      // Botones [Middle, Right, Left]
    output reg        packet_ready, // Pulso cuando hay paquete válido

    // Señales de depuración
    output wire [3:0] led           // LEDs de estado
);

    //=========================================================================
    // INSTANCIA DEL MÓDULO UART
    //=========================================================================

    wire [7:0] rx_data;
    wire rx_avail;
    wire rx_error;
    reg rx_ack;

    uart #(
        .freq_hz(FREQ_HZ),
        .baud(BAUD)
    ) uart_inst (
        .reset(~rst_n),
        .clk(clk),
        .uart_rxd(uart_rxd),
        .uart_txd(),            // No usado
        .rx_data(rx_data),
        .rx_avail(rx_avail),
        .rx_error(rx_error),
        .rx_ack(rx_ack),
        .tx_data(8'h00),        // No usado
        .tx_wr(1'b0),           // No usado
        .tx_busy()              // No usado
    );

    //=========================================================================
    // MÁQUINA DE ESTADOS PARA RECEPCIÓN DE PAQUETES
    //=========================================================================

    localparam STATE_WAIT_SYNC  = 3'd0;
    localparam STATE_WAIT_XL    = 3'd1;
    localparam STATE_WAIT_XH    = 3'd2;
    localparam STATE_WAIT_YL    = 3'd3;
    localparam STATE_WAIT_YH    = 3'd4;
    localparam STATE_WAIT_BTN   = 3'd5;
    localparam STATE_PROCESS    = 3'd6;

    reg [2:0] state;
    reg [2:0] next_state;

    // Buffer para paquete
    reg [7:0] packet_buffer[0:5];
    reg [2:0] byte_index;

    //=========================================================================
    // LÓGICA DE ESTADO
    //=========================================================================

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= STATE_WAIT_SYNC;
        end else begin
            state <= next_state;
        end
    end

    //=========================================================================
    // LÓGICA COMBINACIONAL DE TRANSICIÓN
    //=========================================================================

    always @(*) begin
        next_state = state;

        case (state)
            STATE_WAIT_SYNC: begin
                if (rx_avail && rx_data == 8'hAA) begin
                    next_state = STATE_WAIT_XL;
                end
            end

            STATE_WAIT_XL: begin
                if (rx_avail) begin
                    next_state = STATE_WAIT_XH;
                end
            end

            STATE_WAIT_XH: begin
                if (rx_avail) begin
                    next_state = STATE_WAIT_YL;
                end
            end

            STATE_WAIT_YL: begin
                if (rx_avail) begin
                    next_state = STATE_WAIT_YH;
                end
            end

            STATE_WAIT_YH: begin
                if (rx_avail) begin
                    next_state = STATE_WAIT_BTN;
                end
            end

            STATE_WAIT_BTN: begin
                if (rx_avail) begin
                    next_state = STATE_PROCESS;
                end
            end

            STATE_PROCESS: begin
                next_state = STATE_WAIT_SYNC;
            end

            default: next_state = STATE_WAIT_SYNC;
        endcase
    end

    //=========================================================================
    // LÓGICA DE RECEPCIÓN Y PROCESAMIENTO
    //=========================================================================

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_ack <= 1'b0;
            packet_ready <= 1'b0;
            mouse_x <= 9'd0;
            mouse_y <= 9'd0;
            buttons <= 3'd0;
            byte_index <= 3'd0;
        end else begin
            // Default: rx_ack = 0, packet_ready = 0 (pulsos)
            rx_ack <= 1'b0;
            packet_ready <= 1'b0;

            case (state)
                STATE_WAIT_SYNC: begin
                    if (rx_avail) begin
                        rx_ack <= 1'b1;
                        if (rx_data == 8'hAA) begin
                            packet_buffer[0] <= rx_data;
                            byte_index <= 3'd1;
                        end
                    end
                end

                STATE_WAIT_XL: begin
                    if (rx_avail) begin
                        rx_ack <= 1'b1;
                        packet_buffer[1] <= rx_data;
                        byte_index <= 3'd2;
                    end
                end

                STATE_WAIT_XH: begin
                    if (rx_avail) begin
                        rx_ack <= 1'b1;
                        packet_buffer[2] <= rx_data;
                        byte_index <= 3'd3;
                    end
                end

                STATE_WAIT_YL: begin
                    if (rx_avail) begin
                        rx_ack <= 1'b1;
                        packet_buffer[3] <= rx_data;
                        byte_index <= 3'd4;
                    end
                end

                STATE_WAIT_YH: begin
                    if (rx_avail) begin
                        rx_ack <= 1'b1;
                        packet_buffer[4] <= rx_data;
                        byte_index <= 3'd5;
                    end
                end

                STATE_WAIT_BTN: begin
                    if (rx_avail) begin
                        rx_ack <= 1'b1;
                        packet_buffer[5] <= rx_data;
                    end
                end

                STATE_PROCESS: begin
                    // Decodificar paquete
                    // Byte 1: X[7:0]
                    // Byte 2: {7'b0, X[8]} (signo)
                    // Byte 3: Y[7:0]
                    // Byte 4: {7'b0, Y[8]} (signo)
                    // Byte 5: {5'b0, buttons[2:0]}

                    mouse_x <= {packet_buffer[2][0], packet_buffer[1]};
                    mouse_y <= {packet_buffer[4][0], packet_buffer[3]};
                    buttons <= packet_buffer[5][2:0];

                    packet_ready <= 1'b1;  // Pulso de dato válido
                    byte_index <= 3'd0;
                end

                default: begin
                    byte_index <= 3'd0;
                end
            endcase
        end
    end

    //=========================================================================
    // CONTADOR DE PAQUETES Y LEDS
    //=========================================================================

    reg [31:0] packet_counter;
    reg led_toggle;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            packet_counter <= 32'd0;
            led_toggle <= 1'b0;
        end else begin
            if (packet_ready) begin
                packet_counter <= packet_counter + 1'b1;
                led_toggle <= ~led_toggle;
            end
        end
    end

    //=========================================================================
    // ASIGNACIÓN DE LEDS DE DEPURACIÓN
    //=========================================================================

    assign led[0] = led_toggle;              // LED0: Toggle con cada paquete
    assign led[1] = rx_error;                // LED1: Error UART
    assign led[2] = (state != STATE_WAIT_SYNC);  // LED2: Recibiendo paquete
    assign led[3] = buttons[0];              // LED3: Botón izquierdo

endmodule
