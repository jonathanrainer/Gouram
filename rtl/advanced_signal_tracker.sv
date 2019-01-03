module advanced_signal_tracker 
#(
    parameter TRACKED_SIGNAL_WIDTH = 1,
    parameter CORROBORATING_SIGNAL_WIDTH = 1,
    parameter BUFFER_WIDTH = 8
)
(
    // Externally Required Signals

    input logic clk,
    input logic rst,
    input integer counter,
    input logic [TRACKED_SIGNAL_WIDTH-1:0] tracked_signal,
    input logic [CORROBORATING_SIGNAL_WIDTH-1:0] corroborating_signal,
    input integer value_in,
    input bit recalculate_time,
    input integer previous_end_i,
    input bit update_end,
    
    // Outputs
    
    output integer signed time_out [1:0]
);

    // Implementation Details of Actual Buffers

    bit [TRACKED_SIGNAL_WIDTH-1:0] tracked_signal_buffer [BUFFER_WIDTH-1:0];
    bit [$clog2(BUFFER_WIDTH)-1:0] front_tracked_signal; 
    bit signed [$clog2(BUFFER_WIDTH):0] rear_tracked_signal;
    bit buffer_full = 1'b0;
    bit [CORROBORATING_SIGNAL_WIDTH-1:0] corroborating_signal_buffer [BUFFER_WIDTH-1:0];
    bit [$clog2(BUFFER_WIDTH)-1:0] front_corroborating_signal; 
    bit signed [$clog2(BUFFER_WIDTH):0] rear_corroborating_signal;
    
    // Tracker to keep record of the previous location of a timing interval
    
    integer previous_end;
        
    
    // Clocked Part (Data Collection)
    always@(negedge clk)
    begin
        rear_tracked_signal = (rear_tracked_signal + 1) % BUFFER_WIDTH;
        rear_corroborating_signal = (rear_corroborating_signal + 1) % BUFFER_WIDTH;
        tracked_signal_buffer[rear_tracked_signal] = tracked_signal;
        corroborating_signal_buffer[rear_corroborating_signal] = corroborating_signal;
        if (rear_tracked_signal == front_tracked_signal && (counter > BUFFER_WIDTH - 1)) 
        begin
            front_tracked_signal = (front_tracked_signal + 1) % BUFFER_WIDTH;
            buffer_full = 1'b1;
        end
        if (rear_corroborating_signal == front_corroborating_signal && (counter > BUFFER_WIDTH -1 )) front_corroborating_signal = (front_corroborating_signal + 1) % BUFFER_WIDTH;
    end
    
    // Timing Check (Finding start and end times)
    
    // SEMANTIC DECISION //
    // The input to this always block is the number of cycles back in time you want to look
    // including the cycle the timer is currently pointing to. So if the current time is 
    // 12 and you set value_in as 3 cycles 12, 11 and 10 will be checked NOT 11 - 9 or 
    // anything similar.
    
    always@ (posedge recalculate_time)
    begin
        time_out = {-1,-1};
        if (
            (!buffer_full && (value_in <= (rear_tracked_signal + 1'b1))) || 
            (buffer_full && (value_in <= BUFFER_WIDTH))
            )
        begin 
            // Declare a boolean to track the success of finding a start point
            automatic bit found_start = 1'b0;
            // Declare a second boolean that tracks the state of the coroborating signal when the 
            // start point is found.
            automatic bit corrob_high = 1'b0;
            // Check through the buffer to attempt to identify start and end points of the signal that matters
            for (int i=0; i < value_in; i++)
            begin
                // Calculate the index for the signal entry at the START of the interval to be checked
                automatic integer buffer_index = rear_tracked_signal - value_in + 1 + i;     
                // If that value turns out to be negative because of wrap around, treat it as unsigned,
                // and then modulo by BUFFER_SIZE (a power of 2^n) to strip off the bottom n bits of the
                // negative number. 
                if (buffer_index < 0) buffer_index = $unsigned(buffer_index) % BUFFER_WIDTH;  
                // If it's the case that the currently considered buffer entry is high and the 
                // previous entry is 0 (i.e. there's a 0 -> 1 transition occuring then that is 
                // a starting point .
                // Alternatively if the tracked signal is high and the signal in the previous clock cycle
                // was allocated to another process then this is also a valid starting point.
                if (!found_start && ((tracked_signal_buffer[buffer_index]
                     && (((counter - (value_in - i)) >= previous_end + 1)) || previous_end == 0))) 
                begin
                    time_out[0] = counter - (value_in - i);
                    found_start = 1'b1;
                    corrob_high = corroborating_signal_buffer[buffer_index];
                end
                // To find end points we need to check that either the current tracked signal is low or 
                // that the signal that corroborates the tracked signal is low.
                else if (found_start)
                begin
                    if  ((!tracked_signal_buffer[buffer_index]) ||
                    corrob_high && !corroborating_signal_buffer[buffer_index] || 
                    corrob_high && corroborating_signal_buffer[buffer_index] && tracked_signal_buffer[buffer_index]) 
                    begin
                        time_out[1] = counter - (value_in - i) - 1;
                        break;
                    end
                    else if (!corrob_high && corroborating_signal_buffer[buffer_index])
                    begin
                        time_out[1] = counter - (value_in - i);
                        break;
                    end
                end 
            end
            if (time_out[1] != -1) previous_end = time_out[1];
        end
    end
    
    always@(negedge clk)
    begin
        if (update_end)
        begin
            previous_end <= previous_end_i;
        end
    end
        
    // Reset behaviour
    
    always@(posedge rst)
    begin
        if (rst)
        begin
            front_tracked_signal <= 0;
            front_corroborating_signal <= 0;
            rear_tracked_signal <= -1;
            rear_corroborating_signal <= -1;
            tracked_signal_buffer <= '{default:0};
            corroborating_signal_buffer <= '{default:0};
            buffer_full <= 0;
            previous_end <= 0;
        end
    end

endmodule
