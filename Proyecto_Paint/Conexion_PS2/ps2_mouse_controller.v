// ps2_mouse_controller.v
// Controlador para inicializar un mouse PS/2
// Envia comandos RESET y Enable Data Reporting

module ps2_mouse_controller (
    input  wire clk,
    input  wire rst_n,

    // Interfaz PS/2 bidireccional
    inout  wire ps2_clk,
    inout  wire ps2_data,

    // Senales de debug
    output wire [7:0] debug_state,
    output wire [7:0] debug_data,
    output wire debug_busy,
    output wire debug_ack,
    output wire init_done,
    output wire [7:0] rx_data,
    output wire rx_data_valid
);

    // Estados de la maquina de estados
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

    // Senales del transmisor PS/2
    wire tx_busy;
    wire tx_ack;
    wire tx_error;

    // Senales del receptor PS/2
    wire [7:0] rx_byte;
    wire rx_ready;

    // Control bidireccional de las lineas PS/2
    wire ps2_clk_out, ps2_data_out;
    wire ps2_clk_oe, ps2_data_oe;

    // Implementacion de pines bidireccionales
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

    // Maquina de estados principal
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= STATE_IDLE;
            delay_counter <= 32'd2700000;  // Iniciar con delay de IDLE
            tx_data_reg <= 8'h00;
            tx_start <= 1'b0;
            init_complete <= 1'b0;
        end else begin
            state <= next_state;

            // Control del contador de delay
            case (state)
                STATE_IDLE: begin
                    if (delay_counter > 0) begin
                        delay_counter <= delay_counter - 1;
                    end
                end

                STATE_RESET_WAIT: begin
                    if (state != next_state) begin
                        // Entrando a RESET_WAIT, cargar delay
                        delay_counter <= 32'd27000; // ~1ms
                    end else if (delay_counter > 0) begin
                        delay_counter <= delay_counter - 1;
                    end else begin
                        // delay_counter == 0, enviar comando
                        tx_data_reg <= 8'hFF;  // Comando RESET
                        tx_start <= 1'b1;
                    end
                end

                STATE_SEND_RESET: begin
                    if (tx_start)
                        tx_start <= 1'b0;
                end

                STATE_WAIT_ID: begin
                    if (rx_ready) begin
                        delay_counter <= 32'd270; // ~10ms
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

    // Logica combinacional de siguiente estado
    always @(*) begin
        next_state = state;

        case (state)
            STATE_IDLE: begin
                if (delay_counter == 0) begin
                    next_state = STATE_RESET_WAIT;
                end
            end

            STATE_RESET_WAIT: begin
                if (tx_start) begin
                    next_state = STATE_SEND_RESET;
                end
            end

            STATE_SEND_RESET: begin
                if (!tx_busy && tx_ack) begin
                    next_state = STATE_WAIT_BAT;
                end
            end

            STATE_WAIT_BAT: begin
                if (rx_ready && rx_byte == 8'hAA) begin  // BAT completion
                    next_state = STATE_WAIT_ID;
                end
            end

            STATE_WAIT_ID: begin
                if (rx_ready) begin  // Mouse ID
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
                    if (rx_ready && rx_byte == 8'hFA) begin
                        next_state = STATE_STREAM_MODE;
                    end
                end
            end

            STATE_STREAM_MODE: begin
                // Mouse en stream mode
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
