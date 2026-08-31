//
// drive_sound.v
//
// Floppy drive sound emulation for MiSTeryNano.
//
// Plays two looped samples taken from a CC0 recording of a real 3.5" drive
// (https://commons.wikimedia.org/wiki/File:Floppy_drive_sounds.ogg):
//
//   motor  - spindle hum, played while the drive motor runs
//   seek   - head movement, played while step pulses arrive and decaying
//            afterwards, so the length of the sound follows the length of
//            the actual head movement
//
// Samples are 8 bit signed at 16kHz. The seek sound is deliberately quieter
// than the hum: a drive sitting in a closed case a desk away sounds nothing
// like a bare mechanism next to a microphone.
//
module drive_sound #(
    parameter integer CLK_HZ     = 32_084_988,
    parameter integer SAMPLE_HZ  = 16000,
    parameter integer MOTOR_LEN  = 15040,
    parameter integer SEEK_LEN   = 5440,
    parameter [7:0]   MOTOR_GAIN = 8'd66,   // 0.26 of full scale
    parameter [7:0]   SEEK_GAIN  = 8'd49,   // 0.19 of full scale
    parameter integer OUT_SHIFT  = 10       // overall level
) (
    input                     clk,
    input                     resetn,

    input                     motor_on,    // spindle running
    input                     step,        // one clk wide pulse per head step
    input               [1:0] volume,      // 0 = off, 3 = loudest

    output signed      [15:0] snd
);

localparam integer TICK_DIV = CLK_HZ / SAMPLE_HZ;

// ---------------------------------------------------------------- samples --
reg signed [7:0] motor_rom [0:MOTOR_LEN-1];
reg signed [7:0] seek_rom  [0:SEEK_LEN-1];
initial begin
    $readmemh("misc/motor.hex", motor_rom);
    $readmemh("misc/seek.hex",  seek_rom);
end

// ------------------------------------------------------------ sample tick --
reg [15:0] tick_cnt;
reg        tick;
always @(posedge clk) begin
    if(!resetn) begin
        tick_cnt <= 16'd0;
        tick     <= 1'b0;
    end else if(tick_cnt == TICK_DIV[15:0] - 16'd1) begin
        tick_cnt <= 16'd0;
        tick     <= 1'b1;
    end else begin
        tick_cnt <= tick_cnt + 16'd1;
        tick     <= 1'b0;
    end
end

// ------------------------------------------------------- step retriggering --
// A step pulse holds the seek sound at full level. Only once no further step
// has arrived for a while does it start to decay. Without the hold a fast
// sequence of single track steps would sound like a loose contact.
localparam integer HOLD_SAMPLES = SAMPLE_HZ / 100;   // 10ms

reg [7:0] hold;
reg       step_seen;
always @(posedge clk) begin
    if(!resetn) begin
        hold      <= 8'd0;
        step_seen <= 1'b0;
    end else begin
        if(step) step_seen <= 1'b1;
        if(tick) begin
            if(step_seen)      hold <= HOLD_SAMPLES[7:0];
            else if(hold != 0) hold <= hold - 8'd1;
            step_seen <= 1'b0;
        end
    end
end

// ------------------------------------------------------------- envelopes ---
// Attack and release are exponential, which is what a mechanism does. Linear
// ramps sound switched, not moved.
reg [7:0] motor_env, seek_env;
always @(posedge clk) begin
    if(!resetn) begin
        motor_env <= 8'd0;
        seek_env  <= 8'd0;
    end else if(tick) begin
        // motor: ~50ms in and out, avoids a click when the spindle starts
        if(motor_on) begin
            if(motor_env < 8'd255) motor_env <= motor_env + 8'd1;
        end else if(motor_env != 8'd0)
            motor_env <= motor_env - 8'd1;

        // seek: ~35ms attack, ~160ms decay
        if(hold != 0) begin
            if(seek_env < 8'd247) seek_env <= seek_env + 8'd8;
            else                  seek_env <= 8'd255;
        end else if(seek_env != 8'd0)
            seek_env <= seek_env - 8'd2;
    end
end

// -------------------------------------------------------- sample playback --
reg [15:0] motor_pos, seek_pos;
reg signed [7:0] motor_s, seek_s;
always @(posedge clk) begin
    if(!resetn) begin
        motor_pos <= 16'd0;
        seek_pos  <= 16'd0;
        motor_s   <= 8'sd0;
        seek_s    <= 8'sd0;
    end else if(tick) begin
        motor_s   <= motor_rom[motor_pos];
        seek_s    <= seek_rom[seek_pos];
        motor_pos <= (motor_pos == MOTOR_LEN[15:0]-16'd1) ? 16'd0 : motor_pos + 16'd1;
        seek_pos  <= (seek_pos  == SEEK_LEN[15:0] -16'd1) ? 16'd0 : seek_pos  + 16'd1;
    end
end

// -------------------------------------------------------------- mixing -----
wire signed [23:0] m_mul = motor_s * $signed({1'b0, MOTOR_GAIN}) * $signed({1'b0, motor_env});
wire signed [23:0] s_mul = seek_s  * $signed({1'b0, SEEK_GAIN })  * $signed({1'b0, seek_env });
wire signed [23:0] sum   = (m_mul + s_mul) >>> OUT_SHIFT;

// volume 0 mutes entirely, so the feature can be switched off from the OSD
wire signed [23:0] scaled = (volume == 2'd0) ? 24'sd0 :
                            (volume == 2'd1) ? (sum >>> 2) :
                            (volume == 2'd2) ? (sum >>> 1) : sum;

assign snd = scaled[15:0];

endmodule
