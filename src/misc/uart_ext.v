// uart_ext.v
//
// A plain 8N1 UART on two header pins, fed from the MFP's serial FIFOs.
// It takes the place of the companion MCU on the ST's RS232 port when the
// OSD selects the external port, so a WiFi modem (an ESP32 running an AT
// firmware, for instance) can hang directly off the Tang Nano 20K.
//
// The bit rate follows whatever the ST program has set up in the MFP: the
// MFP core already derives it from timer D and exports it in its status
// word. Rates it cannot derive fall back to 9600, the TOS default.
//
// The interface mirrors what sysctrl.v does on the MCU side: tx_data is the
// head of the MFP's transmit FIFO and tx_strobe pops it; rx_data with
// rx_strobe pushes a byte into the MFP's receive FIFO while rx_space is
// not zero. A byte arriving with no space left is dropped -- there is no
// flow control on this path (yet).

module uart_ext #(
    parameter integer CLK_HZ = 32_000_000
) (
    input             clk,
    input             resetn,
    input             enable,      // OSD: external port selected

    input      [23:0] bitrate,     // from the MFP status word

    // MFP transmit FIFO (ST -> outside)
    input      [7:0]  tx_available,
    input      [7:0]  tx_data,
    output reg        tx_strobe,

    // MFP receive FIFO (outside -> ST)
    input      [7:0]  rx_space,
    output reg [7:0]  rx_data,
    output reg        rx_strobe,

    // the pins
    output reg        txd,
    input             rxd
);

// ----------------------------------------------------------- bit period ---
// One comparison per rate the MFP can report; anything else is 9600.
reg [16:0] period;      // 300 baud needs 106667 clocks, more than 16 bits
always @(*) begin
    case(bitrate)
        24'd19200: period = CLK_HZ / 19200;
        24'd4800:  period = CLK_HZ / 4800;
        24'd2400:  period = CLK_HZ / 2400;
        24'd1200:  period = CLK_HZ / 1200;
        24'd600:   period = CLK_HZ / 600;
        24'd300:   period = CLK_HZ / 300;
        default:   period = CLK_HZ / 9600;
    endcase
end

// ------------------------------------------------------------ transmit ----
reg [16:0] tx_cnt;
reg [3:0]  tx_bit;      // 0 = idle, 1 = start, 2..9 = data, 10 = stop
reg [7:0]  tx_shift;

always @(posedge clk) begin
    tx_strobe <= 1'b0;
    if(!resetn || !enable) begin
        tx_bit   <= 4'd0;
        tx_cnt   <= 17'd0;
        txd      <= 1'b1;
    end else if(tx_bit == 4'd0) begin
        txd <= 1'b1;
        // pop the FIFO head and start the frame in the same clock
        if(tx_available != 8'd0 && !tx_strobe) begin
            tx_shift  <= tx_data;
            tx_strobe <= 1'b1;
            tx_bit    <= 4'd1;
            tx_cnt    <= period - 17'd1;
            txd       <= 1'b0;            // start bit
        end
    end else if(tx_cnt != 17'd0) begin
        tx_cnt <= tx_cnt - 17'd1;
    end else begin
        tx_cnt <= period - 17'd1;
        if(tx_bit == 4'd10) begin
            tx_bit <= 4'd0;               // stop bit done
        end else begin
            txd      <= (tx_bit == 4'd9) ? 1'b1 : tx_shift[0];
            tx_shift <= { 1'b1, tx_shift[7:1] };
            tx_bit   <= tx_bit + 4'd1;
        end
    end
end

// ------------------------------------------------------------- receive ----
// Two flip-flops against metastability, then a plain mid-bit sampler.
reg [1:0]  rx_sync;
always @(posedge clk) rx_sync <= { rx_sync[0], rxd };
wire rx_in = rx_sync[1];

reg [16:0] rx_cnt;
reg [3:0]  rx_bit;      // 0 = idle, 1 = start, 2..9 = data, 10 = stop
reg [7:0]  rx_shift;

always @(posedge clk) begin
    rx_strobe <= 1'b0;
    if(!resetn || !enable) begin
        rx_bit <= 4'd0;
        rx_cnt <= 17'd0;
    end else if(rx_bit == 4'd0) begin
        if(!rx_in) begin                  // falling edge: start bit
            rx_bit <= 4'd1;
            rx_cnt <= { 1'b0, period[16:1] } - 17'd1;   // half a bit
        end
    end else if(rx_cnt != 17'd0) begin
        rx_cnt <= rx_cnt - 17'd1;
    end else begin
        rx_cnt <= period - 17'd1;
        if(rx_bit == 4'd1) begin
            // middle of the start bit: still low, or it was a glitch
            rx_bit <= rx_in ? 4'd0 : 4'd2;
        end else if(rx_bit == 4'd10) begin
            // middle of the stop bit: deliver if it is a stop bit
            rx_bit <= 4'd0;
            if(rx_in && rx_space != 8'd0) begin
                rx_data   <= rx_shift;
                rx_strobe <= 1'b1;
            end
        end else begin
            rx_shift <= { rx_in, rx_shift[7:1] };   // LSB first
            rx_bit   <= rx_bit + 4'd1;
        end
    end
end

endmodule
