module ex_tracker
#(
    parameter DATA_ADDR_WIDTH = 32,
    parameter SIGNAL_BUFFER_SIZE = 256,
    parameter TRACE_BUFFER_SIZE = 32,
    parameter type trace_format = int
)
(
    input logic clk,
    input logic rst,
    
    // Inputs from Counter
    input integer counter,

    // Inputs from ID Tracker
    input logic id_data_ready,
    trace_format id_data_i,
    
    // Inputs from EX Pipelining Stage
    input logic ex_ready,
    
    // Inputs from Memory Phase
    input logic data_mem_req,
    input logic data_mem_grant,
    input logic [DATA_ADDR_WIDTH-1:0] data_mem_addr,
    
    // Inputs from WB Tracker for Previous End
    input integer wb_previous_end_i,
    
    // Outputs to EX Tracker
    trace_format ex_data_o,
    output logic ex_data_ready
);

    trace_format trace_element;
    
    // State Machine to Control Unit
    enum logic [3:0] {
            EXECUTION_START =       4'b0000,
            GET_DATA_FROM_BUFFER =  4'b0001,
            CHECK_MEMORY_REQS =     4'b0010,
            CHECK_PAST_TIME =       4'b0011,
            CHECK_GRANT =           4'b0100,
            CHECK_START =           4'b0101,
            CHECK_END =             4'b0110,
            CHECK_MEMORY_STATUS =   4'b0111,
            OUTPUT_RESULT =         4'b1000
         } state;
         
    integer previous_end_ex = 0;
    integer previous_end_to_buffer = 0;
    bit previous_end_memory = 0;
    bit update_end = 0;
    
    integer ex_ready_value_in = 0;
    integer ex_ready_time_out [1:0] = {0,0};
    bit ex_ready_recalculate_time = 1'b0;
    signal_tracker  #(1, SIGNAL_BUFFER_SIZE) ex_ready_buffer (
        .clk(clk), .rst(rst), .counter(counter), .tracked_signal(ex_ready), .value_in(ex_ready_value_in),
        .time_out(ex_ready_time_out), .recalculate_time(ex_ready_recalculate_time),
         .previous_end_i(previous_end_to_buffer), .update_end(update_end), .previous_end_memory(previous_end_memory),
         .ready_flag(1'b1), .ex_ready_flag(1'b1), .data_mem_req_flag(1'b0)
        );
    logic ex_ready_present = 0;
    
    // Buffer to track Memory Accesses
    integer data_mem_req_value_in = 0;
    integer data_mem_req_time_out [1:0] = {0,0};
    bit data_mem_req_recalculate_time = 1'b0;
    signal_tracker  #(1, SIGNAL_BUFFER_SIZE) data_mem_req_buffer (
        .clk(clk), .rst(rst), .counter(counter), .tracked_signal(data_mem_req), .value_in(data_mem_req_value_in),
        .time_out(data_mem_req_time_out), .recalculate_time(data_mem_req_recalculate_time), 
        .previous_end_i(previous_end_to_buffer), .update_end(update_end), .previous_end_memory(previous_end_memory),
        .ready_flag(1'b0), .ex_ready_flag(1'b0), .data_mem_req_flag(1'b1)
        );
    logic data_mem_req_present = 0;
    
    // Buffer to track Memory Addresses
    integer data_mem_addr_cycles_back = 0;
    bit data_mem_addr_recalculate_back_cycle = 1'b0;
    bit [DATA_ADDR_WIDTH-1:0] recalled_addr = 0;
    signal_tracker  #(DATA_ADDR_WIDTH, SIGNAL_BUFFER_SIZE) data_mem_addr_buffer (
        .clk(clk), .rst(rst), .counter(counter), .tracked_signal(data_mem_addr), 
        .cycles_back_to_recall(data_mem_addr_cycles_back), 
        .recalculate_back_cycle(data_mem_addr_recalculate_back_cycle),
        .signal_recall(recalled_addr), .ready_flag(1'b0), .ex_ready_flag(1'b0), .data_mem_req_flag(1'b0));
    
    // Trace Buffer
     bit data_request = 1'b0;
     bit data_present;
     trace_format buffer_output;
     trace_buffer #(TRACE_BUFFER_SIZE, trace_format) t_buffer (
        .clk(clk), .rst(rst), .ready_signal(id_data_ready), .trace_element_in(id_data_i), 
        .data_request(data_request), .data_present(data_present), .trace_element_out(buffer_output)
     );
    
    always @(posedge rst)
    begin
        initialise_module();
    end
            
    initial
    begin
        initialise_module();
    end
         
    always_ff @(posedge clk)
    begin
        unique case(state)
            EXECUTION_START:
            begin
                ex_data_ready <= 1'b0;
                if (data_present)
                begin
                    data_request <= 1'b1;
                    state <= GET_DATA_FROM_BUFFER;
                end
            end
            GET_DATA_FROM_BUFFER:
            begin
                data_request <= 1'b0;
                if (buffer_output.pass_through)
                begin
                    ex_data_o <= buffer_output;
                    ex_data_ready <= 1'b1;
                    state <= EXECUTION_START;
                end
                else
                begin
                    // Copy in data to the internal trace buffer
                    trace_element <= buffer_output;
                    // Set ex_ready queue input values to read back in next cycle.
                    check_past_ex_ready_values(counter - buffer_output.id_data.time_end);
                    state <= CHECK_PAST_TIME;
                end
            end
            CHECK_PAST_TIME:
            begin
                state <= OUTPUT_RESULT;
                ex_ready_recalculate_time <= 1'b0;
                // If no start time is found in the past
                if (ex_ready_time_out[0] == -1)
                begin
                    // Check the last ex_ready signal that won't be caught by the buffer
                    if (ex_ready_present)
                    begin
                        // If this is valid then the start point has been found. It's still possible 
                        // and end point may have been tracked also so then check for that
                        trace_element.ex_data.time_start <= counter - 1;
                        trace_element.ex_data.mem_access_req.time_start <= counter - 1;
                        if (!ex_ready)
                        begin
                            // If the above conditions are met then the end point was tracked.
                            trace_element.ex_data.time_end <= counter - 1;
                            trace_element.ex_data.mem_access_req.time_start <= 0;
                            previous_end_ex <= counter - 1;
                            update_end <= 1'b1;
                            state <= OUTPUT_RESULT;
                        end
                        // If no end time is found then move to the state that constantly checks for a grant
                        // signal because, as it's not a single cycle EX it must be a memory access
                        // of some form.
                        else state <= CHECK_END; 
                    end
                    // If the is_decoding_present variable didn't get the start point there's a chance the 
                    // current value of is_decoding still holds the data we need solve
                    if (ex_ready)
                    begin
                        trace_element.ex_data.time_start <= counter;
                        trace_element.ex_data.mem_access_req.time_start <= counter;
                        // A start time has been found but as yet no end time so jump to a new state 
                        // to wait for that.
                        state <= CHECK_END;
                    end
                    // If none of this happens then move on and check whether the memory
                    // signals will have more of an idea
                    else 
                    begin
                       check_past_data_mem_req_values(counter - buffer_output.id_data.time_end);
                       state <= CHECK_MEMORY_REQS;
                    end   
                end
                // If either of these branches succeeds then the start time was in the past.
                else if (ex_ready_time_out[1] == -1) 
                begin
                    trace_element.ex_data.time_start <= ex_ready_time_out[0];
                    if (ex_ready_present)
                    begin
                        trace_element.ex_data.time_end <= counter - 1;
                        if (!(counter - 1 == ex_ready_time_out[0]) 
                            && data_mem_req_present && !data_mem_req)
                        begin
                            trace_element.ex_data.mem_access_req.time_start <= ex_ready_time_out[0];
                            trace_element.ex_data.mem_access_req.time_end <= counter -1;
                            previous_end_ex <= counter -1;
                            update_end <= 1'b1;
                            check_past_data_mem_addr_values(1);
                        end
                    end
                    else if (ex_ready)
                    begin
                        trace_element.ex_data.time_end <= counter;
                        if (data_mem_req) 
                        begin
                            // This ensures that the whole interval covered already is checked.
                            check_past_data_mem_req_values(counter - ex_ready_time_out[0] + 2);
                            state <= CHECK_MEMORY_STATUS;
                        end
                        else state <= OUTPUT_RESULT;
                    end
                    else state <= CHECK_END;
                end
                else
                begin
                    trace_element.ex_data.time_start <= ex_ready_time_out[0];
                    trace_element.ex_data.time_end <= ex_ready_time_out[1];
                    if (ex_ready_time_out[0] != ex_ready_time_out[1])
                    begin
                        // This ensures that the whole interval covered already is checked.
                        check_past_data_mem_req_values(counter - ex_ready_time_out[0] + 1);
                        state <= CHECK_MEMORY_STATUS;
                    end 
                end
            end
            CHECK_MEMORY_REQS:
            begin
                data_mem_req_recalculate_time <= 1'b0;
                // If no start point has been found then the signal cannot have started so 
                // either it started in one of the two tracked signals or we're still waiting
                // for it to start.
                if (data_mem_req_time_out[0] == -1)
                begin
                    if (data_mem_req_present)
                    begin
                        // If this is valid then the start point has been found. It's still possible 
                        // and end point may have been tracked also so then check for that
                        trace_element.ex_data.time_start <= counter - 1;
                        trace_element.ex_data.mem_access_req.time_start <= counter - 1;
                        if (!data_mem_req)
                        begin
                            // If the above conditions are met then the end point was tracked also so there's
                            // no need to change the state variable as CHECK_JUMP is the correct next location.
                            trace_element.ex_data.time_end <= counter;
                            trace_element.ex_data.mem_access_req.time_end <= counter;
                            check_past_data_mem_addr_values(0);
                            previous_end_ex <= counter;
                            update_end <= 1'b1;
                            state <= OUTPUT_RESULT;
                        end
                        // If no end time is found then move to the state that constantly checks for an end.
                        else state <= CHECK_GRANT; 
                    end
                    // If the is_decoding_present variable didn't get the start point there's a chance the 
                    // current value of is_decoding still holds the data we need solve
                    if (data_mem_req)
                    begin
                        trace_element.ex_data.time_start <= counter;
                        trace_element.ex_data.mem_access_req.time_start <= counter;
                        // A start time has been found but as yet no end time so jump to a new state 
                        // to wait for that.
                        state <= CHECK_GRANT;
                    end
                    // If none of this happens then you need to just check for a start time constantly
                    else 
                    begin
                       check_past_data_mem_req_values(counter - buffer_output.id_data.time_end);
                       state <= CHECK_START;
                    end
                end
                else if (data_mem_req_time_out[1] == -1)
                begin
                    trace_element.ex_data.time_start <= data_mem_req_time_out[0];
                    trace_element.ex_data.mem_access_req.time_start <= data_mem_req_time_out[0];
                    // If you have a start point but as yet no end point you need to check through the
                    // other saved values to see whether the end point has been tracked or it needs to 
                    // be checked for.
                    if (!data_mem_req_present)
                    begin
                        trace_element.ex_data.time_end <= counter;
                        trace_element.ex_data.mem_access_req.time_end <= counter;
                        check_past_data_mem_addr_values(0);
                        previous_end_ex <= counter;
                        update_end <= 1'b1;
                        state <= OUTPUT_RESULT;
                    end
                    else if (!data_mem_req)
                    begin
                        trace_element.ex_data.time_end <= counter + 1;
                        trace_element.ex_data.mem_access_req.time_end  <= counter + 1;
                        trace_element.ex_data.mem_addr <= data_mem_addr;
                        previous_end_ex <= counter + 1;
                        update_end <= 1'b1;
                        state <= OUTPUT_RESULT;
                    end
                    else state <= CHECK_GRANT;
                end
                else
                begin
                    trace_element.ex_data.time_start <= data_mem_req_time_out[0];
                    trace_element.ex_data.mem_access_req.time_start <= data_mem_req_time_out[0];
                    trace_element.ex_data.time_end <= data_mem_req_time_out[1];
                    trace_element.ex_data.mem_access_req.time_end <= data_mem_req_time_out[0];
                    check_past_data_mem_addr_values(counter-data_mem_req_time_out[0]);
                    previous_end_ex <= data_mem_req_time_out[1];
                    update_end <= 1'b1;
                    state <= OUTPUT_RESULT;
                end
            end 
            CHECK_START:
            begin
                if (ex_ready)
                begin
                    trace_element.ex_data.time_start <= counter;
                    state <= CHECK_END;
                end
                else if (data_mem_req)
                begin
                    trace_element.ex_data.time_start <= counter;
                    trace_element.ex_data.mem_access_req.time_start <= counter;
                    state <= CHECK_GRANT;
                end
            end
            CHECK_END:
            begin
                if (!ex_ready)
                begin
                    trace_element.ex_data.time_end <= counter;
                    state <= OUTPUT_RESULT;
                    previous_end_ex <= counter - 1;
                    update_end <= 1'b1;
                    if (trace_element.ex_data.time_start == counter - 1)
                    begin
                        trace_element.ex_data.time_end <= counter - 1;
                    end
                    else if (data_mem_grant)
                    begin
                        trace_element.ex_data.mem_access_req.time_start <= trace_element.ex_data.time_start;
                        trace_element.ex_data.mem_access_req.time_end <= counter;
                        check_past_data_mem_addr_values(0);
                    end
                end
                else if (data_mem_grant)
                begin
                    trace_element.ex_data.time_end <= counter;
                    trace_element.ex_data.mem_access_req.time_start <= trace_element.ex_data.time_start;
                    trace_element.ex_data.mem_access_req.time_end <= counter;
                    check_past_data_mem_addr_values(0);
                    previous_end_ex <= counter;
                    update_end <= 1'b1;
                    state <= OUTPUT_RESULT;
                end
            end
            CHECK_MEMORY_STATUS:
            begin
                data_mem_req_recalculate_time <= 1'b0;
                state <= OUTPUT_RESULT;
                if (trace_element.instruction ==? 32'h??????83 || 
                    trace_element.instruction ==? 32'h??????03 || 
                    trace_element.instruction ==? 32'h??????23 ||
                    trace_element.instruction ==? 32'h??????a3
                    )
                begin
                    if ((data_mem_req_time_out[0] != trace_element.ex_data.time_start) &&
                        (data_mem_req_time_out[1] > trace_element.ex_data.time_end))
                    begin
                        trace_element.ex_data.mem_access_req.time_start <= trace_element.ex_data.time_start;
                        trace_element.ex_data.mem_access_req.time_end <= trace_element.ex_data.time_end;
                        check_past_data_mem_addr_values(counter - trace_element.ex_data.time_end);
                    end
                    else
                    begin
                        if (trace_element.ex_data.time_start == data_mem_req_time_out[0])
                        begin
                            trace_element.ex_data.mem_access_req.time_start <= data_mem_req_time_out[0];
                        end
                        else if (data_mem_req_time_out[0] != -1 
                                    && data_mem_req_time_out[1] <= trace_element.ex_data.time_end
                                    )
                        begin
                            trace_element.ex_data.time_start <= data_mem_req_time_out[0];
                            trace_element.ex_data.mem_access_req.time_start <= data_mem_req_time_out[0];
                        end
                        if (data_mem_req_time_out[1] == -1)
                        begin
                            if (data_mem_req_present && trace_element.ex_data.time_end == counter - 1)
                            begin
                                trace_element.ex_data.mem_access_req.time_end <= counter - 1;
                                previous_end_ex <= trace_element.ex_data.time_end;
                                update_end <= 1'b1;
                                check_past_data_mem_addr_values(1);
                            end
                            else if (data_mem_req && trace_element.ex_data.time_end == counter)
                            begin
                                trace_element.ex_data.mem_access_req.time_end <= counter;
                                previous_end_ex <= trace_element.ex_data.time_end;
                                update_end <= 1'b1;
                                check_past_data_mem_addr_values(0);
                            end
                        end
                        else if (trace_element.ex_data.time_end == data_mem_req_time_out[1])
                        begin
                            trace_element.ex_data.mem_access_req.time_end <= data_mem_req_time_out[1];
                            previous_end_ex <= trace_element.ex_data.time_end;
                            update_end <= 1'b1;
                            check_past_data_mem_addr_values(counter-data_mem_req_time_out[1]); 
                        end
                   end
               end
               else
               begin
                    previous_end_ex <=  trace_element.ex_data.time_end;   
                    update_end <= 1'b1;      
               end      
            end
            CHECK_GRANT:
            begin
                if (data_mem_grant)
                    begin
                        trace_element.ex_data.time_end <= counter;
                        trace_element.ex_data.mem_access_req.time_start <= trace_element.ex_data.time_start;
                        trace_element.ex_data.mem_access_req.time_end <= counter;
                        check_past_data_mem_addr_values(0);
                        previous_end_ex <= counter;
                        update_end <= 1'b1;
                        state <= OUTPUT_RESULT;
                    end
                end
            OUTPUT_RESULT:
            begin
                if (data_mem_addr_recalculate_back_cycle == 1'b1)
                begin
                    data_mem_addr_recalculate_back_cycle <= 1'b0;
                    trace_element.ex_data.mem_addr <= recalled_addr;
                end
                else
                begin
                    if (trace_element.ex_data.mem_access_req.time_end != 0) previous_end_memory <= 1'b1;
                    else previous_end_memory <= 1'b0;
                    ex_data_o <= trace_element;
                    ex_data_ready <= 1'b1;
                    state <= EXECUTION_START;
                end
            end
        endcase
    end
    
    always @(update_end)
    begin
        if (update_end) update_end <= 1'b0;
    end
        
    always @(wb_previous_end_i, update_end)
    begin
        if (previous_end_ex <= wb_previous_end_i)
        begin
            previous_end_to_buffer <= wb_previous_end_i;
        end
        else previous_end_to_buffer <= previous_end_ex + 1;
    end
        
    task initialise_module();
        state <= EXECUTION_START;
        ex_data_ready <= 0;
        ex_ready_value_in <= 0;
        ex_ready_recalculate_time <= 0;
        previous_end_ex <= 0;
        previous_end_to_buffer <= 0;
        trace_element <= '{default:0};
    endtask
        
    task check_past_ex_ready_values(input integer queue_input);
        ex_ready_value_in <= queue_input;
        ex_ready_present <= ex_ready;
        ex_ready_recalculate_time <= 1'b1;
    endtask
        
    task check_past_data_mem_req_values(input integer queue_input);
        data_mem_req_value_in <= queue_input;
        data_mem_req_present <= data_mem_req;
        data_mem_req_recalculate_time <= 1'b1;
    endtask
    
    task check_past_data_mem_addr_values(input integer queue_input);
        data_mem_addr_cycles_back <= queue_input;
        data_mem_addr_recalculate_back_cycle <= 1'b1;
    endtask
    
        
endmodule
