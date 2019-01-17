module signal_tracker 
#(
    parameter TRACKED_SIGNAL_WIDTH = 1,
    parameter BUFFER_WIDTH = 8
)
(
    // Externally Required Signals

    input logic clk,
    input logic rst_n,
    input integer counter,
    input logic [TRACKED_SIGNAL_WIDTH-1:0] tracked_signal ,
    input integer value_in,
    input logic ready_flag,
    input logic ex_ready_flag,
    input logic data_mem_req_flag,
    input bit recalculate_time,
    input integer range_in [0:1],
    input bit recalculate_range,
    input bit update_end,
    input integer previous_end_i,
    input bit recalculate_single_cycle,
    input integer cycles_back_to_recall,
    input bit recalculate_back_cycle,
    
    // Outputs
    
    output integer signed time_out [1:0],
    output bit range_out,
    output integer single_cycle_out,
    output bit [TRACKED_SIGNAL_WIDTH-1:0] signal_recall
);

    bit [TRACKED_SIGNAL_WIDTH-1:0] buffer [BUFFER_WIDTH-1:0];
    bit [$clog2(BUFFER_WIDTH):0] front; 
    bit signed [$clog2(BUFFER_WIDTH):0] rear;
    bit buffer_full = 1'b0;
    
    // Method to track the previous end of tracked signal
    integer previous_end;
    
    // Enum to denote the source of the previous_end measurement (i.e. Did it result
    // from a memory transaction or not?)
    
    // Clocked Part (Data Collection)
    always@(negedge clk)
    begin
        rear = (rear + 1) % BUFFER_WIDTH;
        buffer[rear] = tracked_signal;
        if (rear == front && (counter > BUFFER_WIDTH - 1))
        begin
            front = (front + 1) % BUFFER_WIDTH;
            buffer_full = 1'b1;
        end
    end
    
    // Timing Check (Finding start and end times)
    
    // SEMANTIC DECISION //
    // The input to this always block is the number of cycles back in time you want to look
    // including the cycle the timer is currently pointing to. So if the current time is 
    // 12 and you set value_in as 3 cycles 12, 11 and 10 will be checked NOT 11 - 9 or 
    // anything similar.
    
    always@ (posedge recalculate_time)
    begin
        time_out <= {-1,-1};
        if (!((!buffer_full && (value_in - 1) > rear) || value_in > BUFFER_WIDTH))
        begin
            // Calculate the index for the signal entry at the START of the interval to be checked
            automatic integer buffer_index = 0;
            // Declare a set of booleans to track the success of finding a start and end point
            automatic bit found_start = 1'b0;
            // State of the signal that we're tracking a change of
            automatic bit sig_state = 1'b0;
            // Check through to see if it's possible to find a starting point in the required
            // period. If it isn't then return [-1,-1] meaning that nothing has started or stopped yet.
            for (int i=0; i <= BUFFER_WIDTH; i++)
            begin
                buffer_index = rear - value_in + 1 + i;
                if (buffer_index >= BUFFER_WIDTH) buffer_index = buffer_index % BUFFER_WIDTH;
                // If that value turns out to be negative because of wrap around, treat it as unsigned,
                // and then modulo by BUFFER_SIZE (a power of 2^n) to strip off the bottom n bits of the
                // negative number. 
                if (buffer_index < 0) buffer_index = $unsigned(buffer_index) % BUFFER_WIDTH;
                if (buffer_index > rear) break;
                // Check if the current slot is the start (is high) or
                // check to make sure that it's low and the previous cycle is high (in the case of a ready
                // signal it's a 0 = activity type measure).
                if (ready_flag)
                begin
                    if (
                        !found_start && 
                            ( 
                                buffer[buffer_index] || 
                                    (
                                        ($unsigned(buffer_index - 1) % BUFFER_WIDTH != rear) &&
                                        buffer[$unsigned(buffer_index - 1) % BUFFER_WIDTH] &&
                                        ((counter - 1 - (value_in - i)) >= previous_end)   
                                    ) ||
                                (!buffer[rear - (counter - previous_end)] && !buffer[buffer_index])
                            )
                         && ((counter - (value_in - i)) > previous_end) 
                       ) 
                    begin
                        time_out[0] <= counter - (value_in - i);
                        sig_state = buffer[buffer_index];
                        if ((($unsigned(buffer_index - 1) % BUFFER_WIDTH != rear) &&
                            !buffer[$unsigned(buffer_index - 1) % BUFFER_WIDTH]) ||
                            buffer_index == front || !buffer[buffer_index])
                        begin
                            // You have a defined edge
                            found_start = 1'b1;
                        end
                        else
                            // You have found a single cycle location
                            begin
                                time_out[1] <= counter - (value_in - i);
                                previous_end <= counter - (value_in - i);
                                break;
                            end
                    end
                    else if (found_start)
                    begin
                        if (buffer[buffer_index] && ((((buffer_index + 1) % BUFFER_WIDTH) != front &&
                            !buffer[(buffer_index + 1) % BUFFER_WIDTH]) || 
                            (buffer[buffer_index] != sig_state)))
                        begin
                            time_out[1] <= counter - (value_in - i);
                            if (!ex_ready_flag) previous_end <= counter - (value_in - i);
                            break;
                        end
                    end
                end
                else
                begin
                    if (!found_start && buffer[buffer_index] && ((counter - (value_in - i)) > previous_end)) 
                    begin
                        time_out[0] <= counter - (value_in - i);
                        if ((($unsigned(buffer_index - 1) % BUFFER_WIDTH != rear) &&
                            !buffer[$unsigned(buffer_index - 1) % BUFFER_WIDTH]) ||
                            buffer_index == front || !buffer[buffer_index])
                        begin
                            // You have a defined edge
                            found_start = 1'b1;
                        end
                        else
                            // You have found a single cycle location
                            begin
                                time_out[1] <= counter - (value_in - i);
                                previous_end <= counter - (value_in - i);
                                break;
                            end
                    end
                    else if (found_start)
                    begin
                        if (buffer[buffer_index] && ((buffer_index + 1) % BUFFER_WIDTH) != front && !buffer[(buffer_index + 1) % BUFFER_WIDTH]) 
                        begin
                            time_out[1] <= counter - (value_in - i);
                            if (!data_mem_req_flag) previous_end <= counter - (value_in - i);
                            break;
                        end
                    end  
                end   
            end
        end
    end
    
    // Occurence check (Did a signal occur in this period)
    
    always@ (posedge recalculate_range)
    begin
        
        if (range_in[1] > counter || 
            (!buffer_full && (range_in[0] > rear)) || 
            (buffer_full && (range_in[1] - range_in[0] > BUFFER_WIDTH))
             ) range_out = 0;
        else
        begin
            range_out = 0;
            if (range_in[0] == range_in[1]) 
            begin
                automatic integer single_cycle_index = rear - (counter - range_in[0]) + 1;
                if (single_cycle_index < 0) single_cycle_index  = $unsigned(single_cycle_index) % BUFFER_WIDTH;
                range_out = buffer[single_cycle_index];
            end
            else
            begin
                automatic integer limit = range_in[1] - range_in[0];
                if (limit < 0) limit = range_in[0] - range_in[1];
                for (int i=0; i <= BUFFER_WIDTH; i++)
                begin
                    automatic integer buffer_index = rear - (counter - range_in[0]) + 1 + i;
                    if (buffer_index < 0) buffer_index += BUFFER_WIDTH;
                    if (buffer_index > rear) break;
                    if (buffer[buffer_index])
                    begin
                         range_out = 1;
                         break;
                    end
                end
            end
        end
    end
    
    // Single Cycle check (Did a signal occur in this period)
        
    always@ (posedge recalculate_single_cycle)
    begin
        single_cycle_out = -1; 
        if (!(range_in[1] > counter || 
            (!buffer_full && (range_in[0] > rear)) || 
            (buffer_full && (range_in[1] - range_in[0] > BUFFER_WIDTH))
             )) 
        begin
            automatic integer limit = range_in[1] - range_in[0];
            if (limit < 0) limit = range_in[0] - range_in[1];
            for (int i=0; i <= BUFFER_WIDTH; i++)
            begin
                automatic integer buffer_index = rear - (counter - range_in[0]) + i + 1;
                if (buffer_index < 0) buffer_index += BUFFER_WIDTH;
                if (buffer_index > rear) break;
                if (buffer[buffer_index])
                begin
                     single_cycle_out = range_in[0] + i;
                     break;
                end
            end
        end 
    end
    
    // Recall single value at particular time
    always @(posedge recalculate_back_cycle)
    begin
        signal_recall <= buffer[$unsigned(rear-cycles_back_to_recall) % BUFFER_WIDTH];
    end
        
        
        
    // Reset behaviour
    
    always@(posedge rst_n)
    begin
        if (rst_n)
        begin
            front <= 0;
            rear <= -1;
            buffer <= '{default:0};
            buffer_full <= 1'b0;
            previous_end <= 1'b0;
        end
    end
    
    always@(negedge clk)
    begin
        if (update_end)
        begin
            previous_end <= previous_end_i;
        end
    end

endmodule
