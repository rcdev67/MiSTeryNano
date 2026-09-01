//
// drive_sound.v
//
// Floppy drive sound emulation for MiSTeryNano.
//
// Plays a small set of samples of a real 3.5" drive:
//
//   startup - the spindle coming up to speed, once when the drive starts
//   spin    - the hum, looped for as long as it runs
//   click   - one head step
//   seek    - a continuous run of steps, for a real seek
//
// The two channels are motor and head; each holds its two sounds in one memory
// and switches between them, which keeps the mixing to two multipliers.
//
// Samples are plain 8 bit PCM at 16kHz, using 14 of the 46 block RAMs of a Tang
// Nano 20k. An earlier revision packed them as 4 bit IMA ADPCM to save memory,
// which is the wrong trade on this device: the Atari ST core alone already
// fills 97% of the logic clusters while two thirds of the block RAM sits idle,
// and the decoders cost about 600 LUTs.
//
// The head is deliberately louder than the hum, following the levels of the
// original recordings -- a spindle a desk away is quieter than the mechanism
// moving.
//
// The samples are the "Basic" drive sound set shipped with the Steem SSE
// emulator, resampled to 16kHz and requantised. Worth confirming with its
// authors before this goes anywhere public.
//
module drive_sound #(
    parameter integer CLK_HZ     = 32_084_988,
    parameter integer SAMPLE_HZ  = 16000,
    // Two sounds per channel, stored back to back in one memory each, so that
    // neither memory is ever read from two places at once -- inferring a dual
    // port ROM crashes GowinSynthesis V1.9.11.
    parameter integer STARTUP_LEN = 7882,   // spin up, then
    parameter integer SPIN_LEN    = 3253,   // ... the hum, looped
    parameter integer MOTOR_LEN   = 11135,
    parameter integer CLICK_LEN   = 3257,   // one head step, then
    parameter integer SEEK_SND_LEN= 13446,  // ... a run of them, looped
    parameter integer SEEK_LEN    = 16703,
    // Gains follow the levels of the original recordings relative to each
    // other, anchored on the hum at the level the previous revision used.
    parameter [7:0]   STARTUP_GAIN = 8'd167,
    parameter [7:0]   SPIN_GAIN    = 8'd66,
    parameter [7:0]   CLICK_GAIN   = 8'd209,
    parameter [7:0]   SEEK_GAIN    = 8'd255,
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
    $readmemh("../../misc/motor.hex", motor_rom);
    $readmemh("../../misc/seek.hex",  seek_rom);
end



// index adjustment per code, the usual IMA table
// five bits, not four: +8 does not fit into a signed 4 bit value and would
// wrap to -8, which keeps the step index near zero and the decoder silent

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

reg [7:0]  hold;
reg        step_seen;
reg [14:0] motor_hold;      // ~1s at 16kHz, bridges the gaps between sectors
reg        motor_seen;      // sticky: sector transfer since the last tick
reg [7:0]  act_level;       // leaky bucket, see below
reg [6:0]  act_decay;
reg        motor_on_d;     // sd_rd is a level, not a pulse
always @(posedge clk) begin
    if(!resetn) begin
        hold       <= 8'd0;
        step_seen  <= 1'b0;
        motor_seen <= 1'b0;
        act_level  <= 8'd0;
        act_decay  <= 7'd0;
        motor_on_d <= 1'b0;
        motor_hold <= 15'd0;
    end else begin
        // Both inputs are short pulses in the system clock domain, far shorter
        // than the 62.5us between sample ticks. They have to be latched, or
        // most of them are simply never seen.
        // Gated by the activity level: TOS moves the head while polling for a
        // disk change, which would otherwise leave the seek sound clicking on
        // an idle desktop forever. Gating the pulse rather than the envelope
        // keeps the test in the block that already evaluates motor_hold.
        if(step && motor_hold != 0) step_seen <= 1'b1;
        // Count accesses, not time spent accessing: sd_rd stays asserted until
        // the card has delivered, so sampling the level would turn one slow
        // sector read into dozens of counts and swamp any rate measurement.
        motor_on_d <= motor_on;
        if(motor_on && !motor_on_d) motor_seen <= 1'b1;

        if(tick) begin
            if(step_seen)      hold <= HOLD_SAMPLES[7:0];
            else if(hold != 0) hold <= hold - 8'd1;
            step_seen <= 1'b0;

            // Telling a real access from TOS polling for a disk change is a
            // matter of rate, not of kind. Once a disk has been read, TOS polls
            // with both head movement and sector reads, just rarely: one or two
            // sectors per second against thirty or more while loading. So
            // accumulate activity in a leaky bucket and run the hum only above
            // a threshold. This is why a freshly booted desktop is silent while
            // one reached after loading a disk was not.
            //
            // Numbers: +64 per sector, -1 every 16 ticks at 16kHz, so the
            // balance point sits at about 15 sectors per second. Polling stays
            // well below it, loading saturates the bucket immediately.
            if(motor_seen)
               act_level <= (act_level > 8'd191) ? 8'd255 : act_level + 8'd64;
            else if(act_decay == 7'd15) begin
               act_decay <= 7'd0;
               if(act_level != 0) act_level <= act_level - 8'd1;
            end else
               act_decay <= act_decay + 7'd1;
            motor_seen <= 1'b0;

            // One threshold, and a high one. A load keeps the bucket pinned at
            // its ceiling, so 200 is never in its way; anything sparser cannot
            // hold it there. An earlier revision lowered the bar once the hum
            // was running, to keep it from stuttering between sectors -- but
            // that is exactly what let stray activity keep it alive forever
            // after the load had finished. Better a rare gap than a hum that
            // never stops.
            if(act_level > 8'd200)   motor_hold <= 15'd8000;    // ~500ms
            else if(motor_hold != 0) motor_hold <= motor_hold - 15'd1;
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
        // motor: ~16ms in and out, avoids a click when the spindle starts.
        // motor_hold bridges the short gaps while TOS deselects the drive
        // between sectors, otherwise the hum would stutter during a load.
        if(motor_hold != 0) begin
            if(motor_env < 8'd255) motor_env <= motor_env + 8'd1;
        end else if(motor_env != 8'd0)
            motor_env <= motor_env - 8'd1;

        // seek: fast attack, short decay. The decay is coarser than intended
        // because an 8 bit envelope cannot step by less than one per sample;
        // refining this needs a wider counter and thus more logic, which this
        // board does not tolerate.
        // The head follows its own channel rather than the step hold, so a
        // single click is allowed to ring out instead of being cut off after
        // the 10ms hold expires.
        if(head_active) begin
            if(seek_env < 8'd247) seek_env <= seek_env + 8'd8;
            else                  seek_env <= 8'd255;
        end else if(seek_env != 8'd0)
            seek_env <= seek_env - 8'd2;
    end
end

// -------------------------------------------------------- sample playback --
// Each channel plays one of two sounds held in its memory. The motor spins up
// once and then loops the hum; the head clicks for a single step and switches
// to the continuous seek sound when steps keep coming, which is what a drive
// actually does -- a seek is a run of steps, not a longer click.
reg [15:0] motor_pos, seek_pos;
reg        motor_spin;      // 0 = spinning up, 1 = looping the hum
reg        motor_was_on;
reg        head_seek;       // 0 = single click, 1 = continuous seek
reg        head_active;     // channel is sounding
reg signed [7:0] motor_s, seek_s;

always @(posedge clk) begin
    if(!resetn) begin
        motor_pos <= 16'd0; seek_pos <= 16'd0;
        motor_s   <= 8'sd0; seek_s   <= 8'sd0;
        motor_spin <= 1'b0; motor_was_on <= 1'b0;
        head_seek  <= 1'b0; head_active  <= 1'b0;
    end else if(tick) begin
        motor_s <= motor_rom[motor_pos];
        seek_s  <= seek_rom [seek_pos];

        // ---- motor -----------------------------------------------------
        motor_was_on <= (motor_hold != 0);
        if(motor_hold != 0) begin
            if(!motor_was_on) begin                    // starts turning
                motor_pos  <= 16'd0;
                motor_spin <= 1'b0;
            end else if(!motor_spin) begin
                if(motor_pos == STARTUP_LEN[15:0] - 16'd1) begin
                    motor_spin <= 1'b1;
                    motor_pos  <= STARTUP_LEN[15:0];
                end else
                    motor_pos <= motor_pos + 16'd1;
            end else
                motor_pos <= (motor_pos == MOTOR_LEN[15:0] - 16'd1) ?
                             STARTUP_LEN[15:0] : motor_pos + 16'd1;
        end

        // ---- head ------------------------------------------------------
        if(step_seen && !head_active) begin             // isolated step
            seek_pos    <= 16'd0;
            head_seek   <= 1'b0;
            head_active <= 1'b1;
        end else if(step_seen && !head_seek) begin      // they keep coming
            seek_pos  <= CLICK_LEN[15:0];
            head_seek <= 1'b1;
        end else if(head_active) begin
            if(!head_seek) begin
                if(seek_pos == CLICK_LEN[15:0] - 16'd1) head_active <= 1'b0;
                else                                    seek_pos <= seek_pos + 16'd1;
            end else begin
                seek_pos <= (seek_pos == SEEK_LEN[15:0] - 16'd1) ?
                            CLICK_LEN[15:0] : seek_pos + 16'd1;
                if(hold == 0) head_active <= 1'b0;      // stopped stepping
            end
        end
    end
end

// -------------------------------------------------------------- mixing -----
wire [7:0] m_gain = motor_spin ? SPIN_GAIN  : STARTUP_GAIN;
wire [7:0] h_gain = head_seek  ? SEEK_GAIN  : CLICK_GAIN;
wire signed [23:0] m_mul = motor_s * $signed({1'b0, m_gain}) * $signed({1'b0, motor_env});
wire signed [23:0] s_mul = seek_s  * $signed({1'b0, h_gain}) * $signed({1'b0, seek_env });
wire signed [23:0] sum   = (m_mul + s_mul) >>> OUT_SHIFT;

// volume 0 mutes entirely, so the feature can be switched off from the OSD
wire signed [23:0] scaled = (volume == 2'd0) ? 24'sd0 :
                            (volume == 2'd1) ? (sum >>> 2) :
                            (volume == 2'd2) ? (sum >>> 1) : sum;

assign snd = scaled[15:0];

endmodule
