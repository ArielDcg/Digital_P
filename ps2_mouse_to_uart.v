// ps2_mouse_to_uart.v
// Módulo que integra mouse PS/2 con comunicación UART
// Lee posición X, Y y botones del mouse y los transmite por UART
//
// Formato del paquete UART (6 bytes):
//   Byte 0: 0xAA (Sincronización/inicio de paquete)
//   Byte 1: X[7:0] (8 bits bajos de posición X)
//   Byte 2: {7'b0, X[8]} (bit de signo de X)
//   Byte 3: Y[7:0] (8 bits bajos de posición Y)
//   Byte 4: {7'b0, Y[8]} (bit de signo de Y)
//   Byte 5: {5'b0, buttons[2:0]} (botones: [Middle, Right, Left])

module ps2_mouse_to_uart #(
    parameter FREQ_HZ = 27000000,   // Frecuencia del reloj del sistema
    parameter BAUD = 115200         // Velocidad UART
) (
    input  wire       clk,          // Reloj del sistema
    input  wire       rst_n,        // Reset activo bajo

    // Interfaz PS/2
    inout  wire       ps2_clk,      // Reloj PS/2 (bidireccional)
    inout  wire       ps2_data,     // Datos PS/2 (bidireccional)

    // Interfaz UART
    output wire       uart_txd,     // Línea TX de UART
    input  wire       uart_rxd,     // Línea RX de UART (no usada)

    // Señales de depuración (opcionales)
    output wire       init_done,    // Inicialización PS/2 completa
    output wire       packet_sent,  // Pulso cuando paquete enviado por UART
    output wire [3:0] led           // LEDs de estado
);

    // Señales del mouse PS/2
    wire [8:0] mouse_x;              // Posición X (9 bits con signo)
    wire [8:0] mouse_y;              // Posición Y (9 bits con signo)
    wire [2:0] buttons;              // Botones [2:0] = [Middle, Right, Left]
    wire packet_ready;               // Pulso cuando hay datos nuevos del mouse
    wire rx_error;

    // Señales internas del UART
    wire [7:0] uart_rx_data;
    wire uart_rx_avail;
    wire uart_rx_error;
    reg uart_rx_ack;
    reg [7:0] uart_tx_data;
    reg uart_tx_wr;
    wire uart_tx_busy;

    // Máquina de estados para envío de paquetes UART
    localparam STATE_IDLE       = 3'd0;
    localparam STATE_SEND_SYNC  = 3'd1;
    localparam STATE_SEND_XL    = 3'd2;
    localparam STATE_SEND_XH    = 3'd3;
    localparam STATE_SEND_YL    = 3'd4;
    localparam STATE_SEND_YH    = 3'd5;
    localparam STATE_SEND_BTN   = 3'd6;
    localparam STATE_WAIT       = 3'd7;

    reg [2:0] uart_state;
    reg [2:0] next_state;

    // Registros para almacenar datos del mouse
    reg [8:0] mouse_x_reg;
    reg [8:0] mouse_y_reg;
    reg [2:0] buttons_reg;
    reg packet_sent_reg;

    // Contador de delay entre transmisiones
    reg [15:0] tx_delay_counter;

    //-----------------------------------------------------
    // Instancia del controlador PS/2
    //-----------------------------------------------------
    ps2_mouse_init ps2_mouse (
        .clk(clk),
        .rst_n(rst_n),
        .ps2_clk(ps2_clk),
        .ps2_data(ps2_data),
        .mouse_x(mouse_x),
        .mouse_y(mouse_y),
        .buttons(buttons),
        .packet_ready(packet_ready),
        .rx_error(rx_error),
        .init_done(init_done),
        .debug_state(),
        .debug_data(),
        .debug_busy(),
        .debug_ack(),
        .rx_data(),
        .rx_data_valid()
    );

    //-----------------------------------------------------
    // Instancia del módulo UART
    //-----------------------------------------------------
    uart #(
        .freq_hz(FREQ_HZ),
        .baud(BAUD)
    ) uart_inst (
        .reset(~rst_n),
        .clk(clk),
        .uart_rxd(uart_rxd),
        .uart_txd(uart_txd),
        .rx_data(uart_rx_data),
        .rx_avail(uart_rx_avail),
        .rx_error(uart_rx_error),
        .rx_ack(uart_rx_ack),
        .tx_data(uart_tx_data),
        .tx_wr(uart_tx_wr),
        .tx_busy(uart_tx_busy)
    );

    //-----------------------------------------------------
    // Captura de datos del mouse cuando llega un paquete
    //-----------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mouse_x_reg <= 9'd0;
            mouse_y_reg <= 9'd0;
            buttons_reg <= 3'd0;
        end else begin
            if (packet_ready) begin
                mouse_x_reg <= mouse_x;
                mouse_y_reg <= mouse_y;
                buttons_reg <= buttons;
            end
        end
    end

    //-----------------------------------------------------
    // Máquina de estados para envío por UART
    //-----------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            uart_state <= STATE_IDLE;
        end else begin
            uart_state <= next_state;
        end
    end

    // Lógica combinacional de la FSM
    always @(*) begin
        next_state = uart_state;

        case (uart_state)
            STATE_IDLE: begin
                if (packet_ready && init_done) begin
                    next_state = STATE_SEND_SYNC;
                end
            end

            STATE_SEND_SYNC: begin
                if (!uart_tx_busy) begin
                    next_state = STATE_SEND_XL;
                end
            end

            STATE_SEND_XL: begin
                if (!uart_tx_busy) begin
                    next_state = STATE_SEND_XH;
                end
            end

            STATE_SEND_XH: begin
                if (!uart_tx_busy) begin
                    next_state = STATE_SEND_YL;
                end
            end

            STATE_SEND_YL: begin
                if (!uart_tx_busy) begin
                    next_state = STATE_SEND_YH;
                end
            end

            STATE_SEND_YH: begin
                if (!uart_tx_busy) begin
                    next_state = STATE_SEND_BTN;
                end
            end

            STATE_SEND_BTN: begin
                if (!uart_tx_busy) begin
                    next_state = STATE_WAIT;
                end
            end

            STATE_WAIT: begin
                // Pequeño delay antes de volver a IDLE
                if (tx_delay_counter == 0) begin
                    next_state = STATE_IDLE;
                end
            end

            default: next_state = STATE_IDLE;
        endcase
    end

    //-----------------------------------------------------
    // Lógica de transmisión UART y control
    //-----------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            uart_tx_data <= 8'd0;
            uart_tx_wr <= 1'b0;
            packet_sent_reg <= 1'b0;
            tx_delay_counter <= 16'd0;
        end else begin
            // Pulso de tx_wr solo dura 1 ciclo
            uart_tx_wr <= 1'b0;
            packet_sent_reg <= 1'b0;

            case (uart_state)
                STATE_IDLE: begin
                    tx_delay_counter <= 16'd100; // Delay para STATE_WAIT
                end

                STATE_SEND_SYNC: begin
                    if (!uart_tx_busy && !uart_tx_wr) begin
                        uart_tx_data <= 8'hAA;  // Byte de sincronización
                        uart_tx_wr <= 1'b1;
                    end
                end

                STATE_SEND_XL: begin
                    if (!uart_tx_busy && !uart_tx_wr) begin
                        uart_tx_data <= mouse_x_reg[7:0];  // 8 bits bajos de X
                        uart_tx_wr <= 1'b1;
                    end
                end

                STATE_SEND_XH: begin
                    if (!uart_tx_busy && !uart_tx_wr) begin
                        uart_tx_data <= {7'b0, mouse_x_reg[8]};  // Bit de signo de X
                        uart_tx_wr <= 1'b1;
                    end
                end

                STATE_SEND_YL: begin
                    if (!uart_tx_busy && !uart_tx_wr) begin
                        uart_tx_data <= mouse_y_reg[7:0];  // 8 bits bajos de Y
                        uart_tx_wr <= 1'b1;
                    end
                end

                STATE_SEND_YH: begin
                    if (!uart_tx_busy && !uart_tx_wr) begin
                        uart_tx_data <= {7'b0, mouse_y_reg[8]};  // Bit de signo de Y
                        uart_tx_wr <= 1'b1;
                    end
                end

                STATE_SEND_BTN: begin
                    if (!uart_tx_busy && !uart_tx_wr) begin
                        uart_tx_data <= {5'b0, buttons_reg};  // Botones
                        uart_tx_wr <= 1'b1;
                    end
                end

                STATE_WAIT: begin
                    if (tx_delay_counter > 0) begin
                        tx_delay_counter <= tx_delay_counter - 1'b1;
                    end
                    if (tx_delay_counter == 1) begin
                        packet_sent_reg <= 1'b1;  // Pulso de confirmación
                    end
                end
            endcase
        end
    end

    //-----------------------------------------------------
    // Asignaciones de salida
    //-----------------------------------------------------
    assign packet_sent = packet_sent_reg;

    // LEDs de depuración
    assign led[0] = init_done;           // LED0: Inicialización completa
    assign led[1] = packet_ready;        // LED1: Paquete PS/2 recibido
    assign led[2] = uart_tx_busy;        // LED2: UART transmitiendo
    assign led[3] = rx_error;            // LED3: Error de paridad PS/2

endmodule
