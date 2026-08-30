// Dauertest des Flash-Lesepfads: liest das komplette TOS 1.04 (98304 Worte)
// ueber den Controller des Cores und prueft die Summe. Laeuft in Endlosschleife.
// LED0 = PLL      LED2 = >=1 Durchlauf fertig   LED4 = FAIL (klebt)
// LED1 = ready    LED3 = alle Durchlaeufe korrekt LED5 = Aktivitaet
module flash_stress (
    input        clk,
    output [5:0] leds_n,
    output       mspi_cs,
    output       mspi_clk,
    inout        mspi_di,
    inout        mspi_hold,
    inout        mspi_wp,
    inout        mspi_do
);

localparam [31:0] EXPECTED = 32'h76919605;
localparam [16:0] LAST     = 17'h17fff;      // 98304 Worte - 1

wire flash_clk, pll_lock_flash;
flash_pll pll_flash (.clkout(flash_clk), .clkoutp(mspi_clk),
                     .lock(pll_lock_flash), .clkin(clk));
wire resetn = pll_lock_flash;

wire        flash_ready, flash_busy;
wire [15:0] flash_dout;
reg  [21:0] address;
reg         cs;

flash flash_i (
    .clk(flash_clk), .resetn(resetn), .ready(flash_ready),
    .address(address), .cs(cs), .dout(flash_dout),
    .mspi_cs(mspi_cs), .mspi_di(mspi_di), .mspi_hold(mspi_hold),
    .mspi_wp(mspi_wp), .mspi_do(mspi_do), .busy(flash_busy)
);

reg [16:0] widx;
reg [31:0] sum;
reg [2:0]  fsm;
reg        fail, any_done, ok;
reg [7:0]  passes;

always @(posedge flash_clk or negedge resetn) begin
    if(!resetn) begin
        widx <= 17'd0; sum <= 32'd0; fsm <= 3'd0; cs <= 1'b0;
        fail <= 1'b0; any_done <= 1'b0; ok <= 1'b0; passes <= 8'd0;
    end else if(flash_ready) begin
        case(fsm)
        3'd0: begin address <= { 5'b00100, widx }; fsm <= 3'd1; end
        3'd1: begin cs <= 1'b1; fsm <= 3'd2; end
        3'd2: if(flash_busy) fsm <= 3'd3;
        3'd3: if(!flash_busy) begin
                  sum <= sum + { 16'd0, flash_dout };
                  cs  <= 1'b0;
                  fsm <= 3'd4;
              end
        3'd4: begin
                  if(widx == LAST) begin
                      any_done <= 1'b1;
                      passes   <= passes + 8'd1;
                      if((sum + 32'd0) != EXPECTED) begin fail <= 1'b1; ok <= 1'b0; end
                      else if(!fail) ok <= 1'b1;
                      sum  <= 32'd0;
                      widx <= 17'd0;
                  end else
                      widx <= widx + 17'd1;
                  fsm <= 3'd0;
              end
        default: ;
        endcase
    end
end

reg [24:0] hb;
always @(posedge clk) hb <= hb + 25'd1;

wire [5:0] leds;
assign leds[0] = pll_lock_flash;
assign leds[1] = flash_ready;
assign leds[2] = any_done;
assign leds[3] = ok && !fail;
assign leds[4] = fail;
assign leds[5] = passes[3];   // blinkt sichtbar, ca. alle 0,27 s ein Wechsel
assign leds_n  = ~leds;

endmodule
