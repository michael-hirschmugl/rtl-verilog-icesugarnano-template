module top (
    input  wire CLK_IN,    // 12 MHz vom Board
    output wire GPIO_08
);
    // LED-Blink (1 Hz aus 12 MHz)
    reg [23:0] div = 24'd0;
    reg        led = 1'b0;
    assign GPIO_08 = led;

    always @(posedge CLK_IN) begin
        div <= div + 1;
        if (div == 24'd6_000_000) begin
            led <= ~led;
            div <= 24'd0;
        end
    end
endmodule
