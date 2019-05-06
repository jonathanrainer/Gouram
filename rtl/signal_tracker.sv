module signal_tracker_value_find
#(
    parameter BUFFER_WIDTH = 8
)
(
    // Externally Required Signals
    signal_tracker_if.ValueFind port
);

    (* ram_style = "block" *) bit [port.TRACKED_SIGNAL_WIDTH-1:0] buffer [BUFFER_WIDTH-1:0];
    bit signed [$clog2(BUFFER_WIDTH):0] rear;
 
    
    // Enum to denote the source of the previous_end measurement (i.e. Did it result
    // from a memory transaction or not?)
    
    // Clocked Part (Data Collection)
    always_ff@(posedge port.clk)
    begin
        // Data Acquisition Part (Runs Every Cycle)
        rear <= (rear + 1) % BUFFER_WIDTH;
        buffer[rear] <= port.tracked_signal;
        if (port.recalculate_back_cycle) 
        begin
            port.data_valid <= 1'b1;
            port.signal_recall <= buffer[$unsigned(rear-(port.cycles_back_to_recall)) % BUFFER_WIDTH];
        end
        if (port.recalculate_back_cycle && port.data_valid) port.data_valid <= 1'b0;
        if (!port.rst_n)
        begin
            initialise_module();
        end 
    end
    
    initial 
    begin
        initialise_module();
    end
    
    task initialise_module();
        rear <= 0;
        buffer <= '{default:0};
    endtask
    
endmodule

module signal_tracker_time_test
#(
    parameter BUFFER_WIDTH = 8
)
(
    // Externally Required Signals
    signal_tracker_if.TimeTest port
);

    (* ram_style = "block" *) bit [port.TRACKED_SIGNAL_WIDTH-1:0] buffer [BUFFER_WIDTH-1:0];
    bit [$clog2(BUFFER_WIDTH)-1:0] rear;
    
    // Method to track the previous end of tracked signal
    (* dont_touch = "yes" *) integer previous_end;
    
    // Clocked Part (Data Collection)
    always_ff@(posedge port.clk)
    begin
        // Data Acquisition Part (Runs Every Cycle)
        rear <= (rear + 1) % BUFFER_WIDTH;
        buffer[rear] <= port.tracked_signal;
        // Timing Check (Finding start and end times)
            
        // SEMANTIC DECISION //
        // The input to this always block is the number of cycles back in time you want to look. 
        // So if the current time is 
        // 12 and you set value_in as 3 cycles 11, 10 and 9 will be checked.
        if (port.recalculate_time && !port.data_valid)
        begin
            port.time_out <= {-1,-1};
            if (!(port.counter < BUFFER_WIDTH && port.value_in > port.counter || port.value_in > BUFFER_WIDTH))
            begin
                // Calculate the index for the signal entry at the START of the interval to be checked
                automatic integer buffer_index = 0;
                // Declare a set of booleans to track the success of finding a start and end point
                automatic bit found_start = 1'b0;
                // Check through to see if it's possible to find a starting point in the required
                // period. If it isn't then return [-1,-1] meaning that nothing has started or stopped yet.
                for (int i=0; i <= BUFFER_WIDTH; i++)
                begin
                    buffer_index = rear - port.value_in + i;
                    if (buffer_index >= BUFFER_WIDTH) buffer_index = buffer_index % BUFFER_WIDTH;
                    // If that value turns out to be negative because of wrap around, treat it as unsigned,
                    // and then modulo by BUFFER_SIZE (a power of 2^n) to strip off the bottom n bits of the
                    // negative number. 
                    if (buffer_index < 0) buffer_index = $unsigned(buffer_index) % BUFFER_WIDTH;
                    if (buffer_index == rear)
                    begin
                        port.data_valid <= 1;
                        break;
                    end
                    // Check if the current slot is the start (is high) or
                    // check to make sure that it's low and the previous cycle is high (in the case of a ready
                    // signal it's a 0 = activity type measure).
                    if (!found_start && buffer[buffer_index] && ((port.counter - (port.value_in - i)) >= previous_end)) 
                    begin
                        port.time_out[0] <= port.counter - (port.value_in - i);
                        if ( // Is it the case that the signal looks like a single peak over 1 cycle? If so then record it as such.
                            ((($unsigned(buffer_index - 1) % BUFFER_WIDTH != rear) && !buffer[$unsigned(buffer_index - 1) % BUFFER_WIDTH]) && 
                            (($unsigned(buffer_index + 1) % BUFFER_WIDTH != rear) && !buffer[$unsigned(buffer_index + 1) % BUFFER_WIDTH])) ||
                            // Alternatively is it the case that this is a one cycle thing if you consider the start of where we're looking as one cycle
                            ((($unsigned(buffer_index + 1) % BUFFER_WIDTH != rear) && !buffer[$unsigned(buffer_index + 1) % BUFFER_WIDTH]) && i == 0)
                            )
                        begin
                            port.time_out[1] <= port.counter - (port.value_in - i);
                            previous_end <= port.counter - (port.value_in - i);
                            port.data_valid <= 1;
                            break;
                            
                        end
                        else found_start = 1'b1;
                    end
                    else if (found_start)
                    begin
                        if (buffer[buffer_index] && ((buffer_index + 1) % BUFFER_WIDTH) != (rear + 1) % BUFFER_WIDTH && !buffer[(buffer_index + 1) % BUFFER_WIDTH]) 
                        begin
                            port.time_out[1] <= port.counter - (port.value_in - i);
                            previous_end <= port.counter - (port.value_in - i);
                            port.data_valid <= 1;
                            break;
                        end
                    end   
                end
            end
        end
        if (port.recalculate_time && port.data_valid) port.data_valid <= 0;
        if (!port.rst_n)
        begin
            initialise_module();
        end 
    end
    
    initial
    begin
        initialise_module();
    end
    
    task initialise_module();
        rear <= 0;
        buffer <= '{default:0};
        previous_end <= 0;
    endtask

endmodule
