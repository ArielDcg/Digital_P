// mouse_display_top.v
// Top module que recibe datos del mouse desde ESP32 vía UART
// y los puede usar para cualquier aplicación (LED, pantalla, etc.)
//
// Arquitectura:
//   Mouse PS/2 → ESP32 → UART → FPGA (este módulo)

module mouse_display_top #(
    parameter FREQ_HZ = 27000000,
    parameter BAUD = 115200
) (
    input  wire       clk,          // Reloj 27 MHz
    input  wire       rst_n,        // Reset activo bajo

    // UART desde ESP32
    input  wire       uart_rxd,     // RX desde ESP32

    // LEDs de depuración
    output wire [3:0] led,

    // Salidas opcionales para otros módulos
    output wire [8:0] mouse_x_out,  // Puede conectarse a display, etc.
    output wire [8:0] mouse_y_out,
    output wire [2:0] buttons_out,
    output wire       new_data      // Pulso cuando hay datos nuevos
);

    //=========================================================================
    // SEÑALES INTERNAS
    //=========================================================================

    wire [8:0] mouse_x;
    wire [8:0] mouse_y;
    wire [2:0] buttons;
    wire packet_ready;

    //=========================================================================
    // INSTANCIA DEL RECEPTOR UART
    //=========================================================================

    uart_mouse_receiver #(
        .FREQ_HZ(FREQ_HZ),
        .BAUD(BAUD)
    ) receiver (
        .clk(clk),
        .rst_n(rst_n),
        .uart_rxd(uart_rxd),
        .mouse_x(mouse_x),
        .mouse_y(mouse_y),
        .buttons(buttons),
        .packet_ready(packet_ready),
        .led(led)
    );

    //=========================================================================
    // CURSOR ACUMULATIVO (EJEMPLO)
    //=========================================================================

    reg signed [15:0] cursor_x;
    reg signed [15:0] cursor_y;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cursor_x <= 16'd512;  // Centro de pantalla (ejemplo 1024x768)
            cursor_y <= 16'd384;
        end else begin
            if (packet_ready) begin
                // Acumular movimiento
                cursor_x <= cursor_x + $signed(mouse_x);
                cursor_y <= cursor_y + $signed(mouse_y);

                // Limitar a rango de pantalla (ejemplo)
                if (cursor_x < 0) cursor_x <= 0;
                if (cursor_x > 1023) cursor_x <= 1023;
                if (cursor_y < 0) cursor_y <= 0;
                if (cursor_y > 767) cursor_y <= 767;
            end
        end
    end

    //=========================================================================
    // ASIGNACIONES DE SALIDA
    //=========================================================================

    // Salidas directas del mouse (movimiento relativo)
    assign mouse_x_out = mouse_x;
    assign mouse_y_out = mouse_y;
    assign buttons_out = buttons;
    assign new_data = packet_ready;

    // Aquí puedes agregar más lógica:
    // - Conectar cursor_x/cursor_y a un controlador de pantalla
    // - Usar buttons para controlar otros módulos
    // - Implementar funcionalidad de "paint" o dibujo
    // - etc.

endmodule
