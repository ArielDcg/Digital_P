// top_ps2_test.v
module top_ps2_test (
    input  wire clk,
    input  wire rst_n,

    // PS/2 interface
    inout  wire ps2_clk,
    inout  wire ps2_data,

    // Debug outputs para analizador lógico
    output wire [7:0] debug_state,
    output wire [7:0] debug_pins,  // Para ver datos en pines adicionales

    // LEDs
    output wire led_init_done,
    output wire led_activity,
    output wire led_error,

    // Salidas del mouse
    output wire [8:0] mouse_x,
    output wire [8:0] mouse_y,
    output wire [2:0] buttons,
    output wire packet_ready,

    // UART para debug (opcional)
    output wire uart_tx
);

    wire [7:0] rx_data;
    wire rx_valid;
    wire init_done;
    wire [7:0] debug_data;
    wire debug_busy, debug_ack;
    wire rx_error;

    // Instancia del módulo PS/2
    ps2_mouse_init mouse_ctrl (
        .clk(clk),
        .rst_n(1'b1),
        .ps2_clk(ps2_clk),
        .ps2_data(ps2_data),
        .debug_state(debug_state),
        .debug_data(debug_data),
        .debug_busy(debug_busy),
        .debug_ack(debug_ack),
        .init_done(init_done),
        .rx_data(rx_data),
        .rx_data_valid(rx_valid),
        .mouse_x(mouse_x),
        .mouse_y(mouse_y),
        .buttons(buttons),
        .packet_ready(packet_ready),
        .rx_error(rx_error)
    );

    // Asignar señales de debug adicionales
    assign debug_pins = rx_data;

    // LEDs indicadores
    assign led_init_done = init_done;
    assign led_activity = packet_ready;  // Actividad = paquete recibido
    assign led_error = rx_error;         // Error de paridad
    
    // UART para debug (implementación simplificada)
    // Puedes agregar un módulo UART aquí si necesitas debug serial
    assign uart_tx = 1'b1;  // Idle high cuando no se usa

endmodule