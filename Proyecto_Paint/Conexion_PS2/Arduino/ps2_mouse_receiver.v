/*
 * Receptor UART para datos de mouse PS/2 desde ESP32
 * Compatible con Tang Primer 25K
 * 
 * Protocolo de entrada (115200 baud):
 * Byte 0: 0xFF (inicio de trama)
 * Byte 1: Botones (bit 0=L, bit 1=R, bit 2=M)
 * Byte 2: Movimiento X (signed 8-bit)
 * Byte 3: Movimiento Y (signed 8-bit)
 * Byte 4: Checksum (XOR de bytes 1-3)
 */

module ps2_mouse_receiver (
    input wire clk,           // 27 MHz para Tang Primer 25K
    input wire rst_n,
    input wire uart_rx,       // Señal UART desde ESP32
    
    // Salidas de datos del mouse
    output reg [7:0] mouse_x,
    output reg [7:0] mouse_y,
    output reg mouse_left,
    output reg mouse_right,
    output reg mouse_middle,
    output reg data_valid,    // Pulso cuando hay datos nuevos
    output reg error_flag     // Flag de error
);

    // Parámetros UART para 115200 baud @ 27MHz
    localparam BAUD_RATE = 115200;
    localparam CLK_FREQ = 27000000;
    localparam CLKS_PER_BIT = CLK_FREQ / BAUD_RATE; // ~234
    
    // Estados del receptor UART
    localparam IDLE = 3'd0;
    localparam START_BIT = 3'd1;
    localparam DATA_BITS = 3'd2;
    localparam STOP_BIT = 3'd3;
    
    // Estados del parser de paquetes
    localparam WAIT_HEADER = 3'd0;
    localparam RX_BUTTONS = 3'd1;
    localparam RX_X = 3'd2;
    localparam RX_Y = 3'd3;
    localparam RX_CHECKSUM = 3'd4;
    
    // Señales del receptor UART
    reg [2:0] uart_state;
    reg [15:0] clk_count;
    reg [2:0] bit_index;
    reg [7:0] rx_byte;
    reg rx_done;
    reg uart_rx_sync1, uart_rx_sync2;
    
    // Señales del parser
    reg [2:0] parser_state;
    reg [7:0] buttons_reg;
    reg [7:0] x_reg;
    reg [7:0] y_reg;
    reg [7:0] checksum_reg;
    reg [7:0] checksum_calc;
    
    // Sincronización de entrada
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            uart_rx_sync1 <= 1'b1;
            uart_rx_sync2 <= 1'b1;
        end else begin
            uart_rx_sync1 <= uart_rx;
            uart_rx_sync2 <= uart_rx_sync1;
        end
    end
    
    // Receptor UART
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            uart_state <= IDLE;
            clk_count <= 0;
            bit_index <= 0;
            rx_byte <= 0;
            rx_done <= 0;
        end else begin
            rx_done <= 0; // Pulso de un ciclo
            
            case (uart_state)
                IDLE: begin
                    clk_count <= 0;
                    bit_index <= 0;
                    
                    if (uart_rx_sync2 == 1'b0) begin // Detectar start bit
                        uart_state <= START_BIT;
                    end
                end
                
                START_BIT: begin
                    if (clk_count == (CLKS_PER_BIT - 1) / 2) begin
                        if (uart_rx_sync2 == 1'b0) begin // Confirmar start bit
                            clk_count <= 0;
                            uart_state <= DATA_BITS;
                        end else begin
                            uart_state <= IDLE; // Falso start
                        end
                    end else begin
                        clk_count <= clk_count + 1;
                    end
                end
                
                DATA_BITS: begin
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1;
                    end else begin
                        clk_count <= 0;
                        rx_byte[bit_index] <= uart_rx_sync2;
                        
                        if (bit_index < 7) begin
                            bit_index <= bit_index + 1;
                        end else begin
                            bit_index <= 0;
                            uart_state <= STOP_BIT;
                        end
                    end
                end
                
                STOP_BIT: begin
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1;
                    end else begin
                        clk_count <= 0;
                        rx_done <= 1'b1;
                        uart_state <= IDLE;
                    end
                end
                
                default: uart_state <= IDLE;
            endcase
        end
    end
    
    // Parser de paquetes del mouse
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            parser_state <= WAIT_HEADER;
            mouse_x <= 0;
            mouse_y <= 0;
            mouse_left <= 0;
            mouse_right <= 0;
            mouse_middle <= 0;
            data_valid <= 0;
            error_flag <= 0;
            buttons_reg <= 0;
            x_reg <= 0;
            y_reg <= 0;
            checksum_reg <= 0;
            checksum_calc <= 0;
        end else begin
            data_valid <= 0; // Pulso de un ciclo
            
            if (rx_done) begin
                case (parser_state)
                    WAIT_HEADER: begin
                        if (rx_byte == 8'hFF) begin
                            parser_state <= RX_BUTTONS;
                            error_flag <= 0;
                        end
                    end
                    
                    RX_BUTTONS: begin
                        buttons_reg <= rx_byte;
                        checksum_calc <= rx_byte;
                        parser_state <= RX_X;
                    end
                    
                    RX_X: begin
                        x_reg <= rx_byte;
                        checksum_calc <= checksum_calc ^ rx_byte;
                        parser_state <= RX_Y;
                    end
                    
                    RX_Y: begin
                        y_reg <= rx_byte;
                        checksum_calc <= checksum_calc ^ rx_byte;
                        parser_state <= RX_CHECKSUM;
                    end
                    
                    RX_CHECKSUM: begin
                        checksum_reg <= rx_byte;
                        
                        // Verificar checksum
                        if (rx_byte == checksum_calc) begin
                            // Checksum correcto - actualizar salidas
                            mouse_x <= x_reg;
                            mouse_y <= y_reg;
                            mouse_left <= buttons_reg[0];
                            mouse_right <= buttons_reg[1];
                            mouse_middle <= buttons_reg[2];
                            data_valid <= 1'b1;
                            error_flag <= 0;
                        end else begin
                            // Checksum incorrecto
                            error_flag <= 1'b1;
                        end
                        
                        parser_state <= WAIT_HEADER;
                    end
                    
                    default: parser_state <= WAIT_HEADER;
                endcase
            end
        end
    end

endmodule


/*
 * Módulo de ejemplo: Integrador de posición del mouse
 * Mantiene coordenadas X,Y absolutas basadas en los deltas del mouse
 */
module mouse_position_integrator (
    input wire clk,
    input wire rst_n,
    
    // Entradas del receptor
    input wire [7:0] mouse_dx,
    input wire [7:0] mouse_dy,
    input wire data_valid,
    
    // Salidas de posición absoluta
    output reg [15:0] pos_x,
    output reg [15:0] pos_y,
    
    // Límites de pantalla
    input wire [15:0] max_x,
    input wire [15:0] max_y
);

    // Convertir deltas de 8-bit signed a 16-bit signed
    wire signed [15:0] delta_x = {{8{mouse_dx[7]}}, mouse_dx};
    wire signed [15:0] delta_y = {{8{mouse_dy[7]}}, mouse_dy};
    
    // Posiciones temporales con signo
    wire signed [16:0] temp_x = $signed({1'b0, pos_x}) + delta_x;
    wire signed [16:0] temp_y = $signed({1'b0, pos_y}) + delta_y;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pos_x <= max_x / 2; // Iniciar en el centro
            pos_y <= max_y / 2;
        end else if (data_valid) begin
            // Actualizar X con límites
            if (temp_x < 0)
                pos_x <= 0;
            else if (temp_x > max_x)
                pos_x <= max_x;
            else
                pos_x <= temp_x[15:0];
            
            // Actualizar Y con límites
            if (temp_y < 0)
                pos_y <= 0;
            else if (temp_y > max_y)
                pos_y <= max_y;
            else
                pos_y <= temp_y[15:0];
        end
    end

endmodule


/*
 * Top module de ejemplo para Tang Primer 25K
 */
module mouse_top (
    input wire clk_27mhz,
    input wire rst_n,
    input wire uart_rx,
    
    // LEDs para debug
    output wire [5:0] led,
    
    // Salidas para usar en tu proyecto
    output wire [15:0] mouse_pos_x,
    output wire [15:0] mouse_pos_y,
    output wire mouse_left_out,
    output wire mouse_right_out,
    output wire mouse_middle_out,
    output wire mouse_valid_out
);

    // Señales internas
    wire [7:0] mouse_dx, mouse_dy;
    wire mouse_left, mouse_right, mouse_middle;
    wire data_valid, error;
    
    // Instanciar receptor
    ps2_mouse_receiver receiver (
        .clk(clk_27mhz),
        .rst_n(rst_n),
        .uart_rx(uart_rx),
        .mouse_x(mouse_dx),
        .mouse_y(mouse_dy),
        .mouse_left(mouse_left),
        .mouse_right(mouse_right),
        .mouse_middle(mouse_middle),
        .data_valid(data_valid),
        .error_flag(error)
    );
    
    // Instanciar integrador de posición
    mouse_position_integrator integrator (
        .clk(clk_27mhz),
        .rst_n(rst_n),
        .mouse_dx(mouse_dx),
        .mouse_dy(mouse_dy),
        .data_valid(data_valid),
        .pos_x(mouse_pos_x),
        .pos_y(mouse_pos_y),
        .max_x(16'd639),  // Ajustar según tu resolución
        .max_y(16'd479)
    );
    
    // Salidas
    assign mouse_left_out = mouse_left;
    assign mouse_right_out = mouse_right;
    assign mouse_middle_out = mouse_middle;
    assign mouse_valid_out = data_valid;
    
    // LEDs de debug
    assign led[0] = mouse_left;
    assign led[1] = mouse_right;
    assign led[2] = mouse_middle;
    assign led[3] = data_valid;
    assign led[4] = error;
    assign led[5] = uart_rx;

endmodule
