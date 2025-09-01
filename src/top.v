module top (
    input  wire clk,    // 12 MHz vom Board
    output wire LED
);
    // LED-Blink (1 Hz aus 12 MHz)
    reg [23:0] div = 24'd0;
    reg        led = 1'b0;
    assign LED = led;

    always @(posedge clk) begin
        div <= div + 1;
        if (div == 24'd6_000_000) begin
            led <= ~led;
            div <= 24'd0;
        end
    end
endmodule
