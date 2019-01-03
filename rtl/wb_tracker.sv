module wb_tracker
#(
    parameter TRACE_BUFFER_SIZE = 32,
    parameter type trace_output = int
)
(
    input logic clk,
    input logic rst,
    
    // Inputs from Counter
    input integer counter,

    // Inputs from EX Tracker
    input logic ex_data_ready,
    input trace_output ex_data_i,
    
    // Inputs from WB Phase hardware
    input logic wb_ready,
    input logic data_mem_rvalid,
    
    // Output from Tracker
    output trace_output wb_data_o,
    output logic wb_data_ready,
    
    // Output to enable EX phase to have knowledge of the end of memory phases
    output integer previous_end_o
);
    
    // Trace Element to Build up
    trace_output trace_element;
    
    // State Machine to Control Unit
    enum logic [3:0] {
            WRITEBACK_START =       4'b0000,
            GET_DATA_FROM_BUFFER =  4'b0001,
            CHECK_MEMORY_RESS =     4'b0010,
            CHECK_PAST_TIME =       4'b0011,
            CHECK_RVALID =          4'b0100,
            CHECK_START =           4'b0101,
            CHECK_END =             4'b0110,
            CHECK_MEMORY_STATUS =   4'b0111,
            OUTPUT_RESULT =         4'b1000
         } state;
         
    integer previous_end = 0;
    bit previous_end_memory = 0;
    bit update_end = 0;
         
    integer wb_ready_value_in = 0;
    integer wb_ready_time_out [1:0] = {0,0};
    bit wb_ready_recalculate_time = 1'b0;
    signal_tracker  #(1, 128) wb_ready_buffer (
        .clk(clk), .rst(rst), .counter(counter), .tracked_signal(wb_ready), .value_in(wb_ready_value_in),
        .time_out(wb_ready_time_out), .recalculate_time(wb_ready_recalculate_time),
        .previous_end_i(previous_end), .update_end(update_end), .previous_end_memory(previous_end_memory),
        .ready_flag(1'b1), .ex_ready_flag(1'b0), .data_mem_req_flag(1'b0)
    );
    logic wb_ready_present = 0;
    
    // Trace Buffer to track Memory Accesses
    integer data_mem_rvalid_range_in [0:1] = {0,0};
    integer data_mem_rvalid_single_cycle_out = 0;
    bit data_mem_rvalid_recalculate_single_cycle = 1'b0;
    signal_tracker  #(1, 128) data_mem_req_buffer (
        .clk(clk), .rst(rst), .counter(counter), .tracked_signal(data_mem_rvalid), .range_in(data_mem_rvalid_range_in),
        .previous_end_i(previous_end), .update_end(update_end), .recalculate_single_cycle(data_mem_rvalid_recalculate_single_cycle),
         .single_cycle_out(data_mem_rvalid_single_cycle_out), .previous_end_memory(previous_end_memory), .ready_flag(1'b0), .ex_ready_flag(1'b0),
         .data_mem_req_flag(1'b0));
    logic data_mem_rvalid_present = 0;
    
    // Trace Buffer
     bit data_request = 1'b0;
     bit data_present;
     trace_output buffer_output;
     trace_buffer #(TRACE_BUFFER_SIZE, trace_output) t_buffer (
        .clk(clk), .rst(rst), .ready_signal(ex_data_ready), .trace_element_in(ex_data_i), 
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
             WRITEBACK_START:
             begin
                 wb_data_ready <= 1'b0;
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
                     wb_data_o <= buffer_output;
                     wb_data_ready <= 1'b1;
                     state <= WRITEBACK_START;
                 end
                 else
                 begin
                     // Copy in data to the internal trace buffer
                     trace_element <= buffer_output;
                     // Set ex_ready queue input values to read back in next cycle.
                     check_past_wb_ready_values(counter - buffer_output.ex_data.time_end);
                     state <= CHECK_PAST_TIME;
                 end
             end
             CHECK_PAST_TIME:
             begin
                 state <= OUTPUT_RESULT;
                 wb_ready_recalculate_time <= 1'b0;
                 if (wb_ready_time_out[0] == -1)
                 begin
                     if (wb_ready_present)
                     begin
                         // If this is valid then the start point has been found. It's still possible 
                         // and end point may have been tracked also so then check for that
                         trace_element.wb_data.time_start <= counter - 1;
                         trace_element.wb_data.mem_access_res.time_start <= counter - 1;
                         if (!wb_ready)
                         begin
                             // If the above conditions are met then the end point was tracked.
                             trace_element.wb_data.time_end <= counter - 1;
                             trace_element.wb_data.mem_access_res.time_start <= 0;
                             previous_end <= counter - 1;
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
                     if (wb_ready)
                     begin
                         trace_element.wb_data.time_start <= counter;
                         trace_element.wb_data.mem_access_res.time_start <= counter;
                         // A start time has been found but as yet no end time so jump to a new state 
                         // to wait for that.
                         state <= CHECK_END;
                     end
                     // If none of this happens then move on and check whether the memory
                     // signals will have more of an idea
                     else 
                     begin
                        check_past_data_mem_res_values(buffer_output.ex_data.time_end+1, counter);
                        state <= CHECK_MEMORY_RESS;
                     end   
                 end
                 // If either of these branches succeeds then the start time was in the past.
                 else if (wb_ready_time_out[1] == -1) 
                 begin
                     trace_element.wb_data.time_start <= wb_ready_time_out[0];
                     if (wb_ready_present)
                     begin
                         trace_element.wb_data.time_end <= counter - 1;
                         previous_end <= counter - 1;
                         update_end <= 1'b1;
                         if (!(counter - 1 == wb_ready_time_out[0]) 
                             && data_mem_rvalid_present && !data_mem_rvalid)
                         begin
                             trace_element.wb_data.mem_access_res.time_start <= wb_ready_time_out[0];
                             trace_element.wb_data.mem_access_res.time_end <= counter -1;
                         end
                     end
                     else if (wb_ready)
                     begin
                         trace_element.wb_data.time_end <= counter;
                         previous_end <= counter;
                         update_end <= 1'b1;
                         if (data_mem_rvalid) 
                         begin
                             // This ensures that the whole interval covered already is checked.
                             check_past_data_mem_res_values(trace_element.wb_data.time_start + 2, counter);
                             state <= CHECK_MEMORY_STATUS;
                         end
                         else state <= OUTPUT_RESULT;
                     end
                     else state <= CHECK_END;
                 end
                 else
                 begin
                     trace_element.wb_data.time_start <= wb_ready_time_out[0];
                     trace_element.wb_data.time_end <= wb_ready_time_out[1];
                     previous_end <= wb_ready_time_out[1];
                     update_end <= 1'b1;
                     if (wb_ready_time_out[0] != wb_ready_time_out[1])
                     begin
                         // This ensures that the whole interval covered already is checked.
                         check_past_data_mem_res_values(wb_ready_time_out[0] + 2, counter);
                         state <= CHECK_MEMORY_STATUS;
                     end 
                 end
             end
             CHECK_MEMORY_RESS:
             begin
                 data_mem_rvalid_recalculate_single_cycle <= 1'b0;
                 // If no start point has been found then the signal cannot have started so 
                 // either it started in one of the two tracked signals or we're still waiting
                 // for it to start.
                 if (data_mem_rvalid_single_cycle_out == -1)
                 begin
                     if (!data_mem_rvalid_present)
                     begin
                         trace_element.wb_data.time_start <= trace_element.ex_data.mem_access_req.time_end + 1;
                         trace_element.wb_data.mem_access_res.time_start <= trace_element.ex_data.mem_access_req.time_end + 1;;
                         trace_element.wb_data.time_end <= counter;
                         trace_element.wb_data.mem_access_res.time_end <= counter;
                         previous_end <= counter;
                         update_end <= 1'b1;
                         state <= OUTPUT_RESULT;
                     end
                     else if (!data_mem_rvalid)
                     begin
                        trace_element.wb_data.time_start <= trace_element.ex_data.mem_access_req.time_end + 1;
                         trace_element.wb_data.mem_access_res.time_start <= trace_element.ex_data.mem_access_req.time_end + 1;;
                         trace_element.wb_data.time_end <= counter + 1;
                         trace_element.wb_data.mem_access_res.time_end  <= counter + 1;
                         previous_end <= counter + 1;
                         update_end <= 1'b1;
                         state <= OUTPUT_RESULT;
                     end
                     else state <= CHECK_RVALID;
                 end
                 else
                 begin
                     trace_element.wb_data.time_start <= trace_element.ex_data.mem_access_req.time_end + 1;
                     trace_element.wb_data.mem_access_res.time_start <= trace_element.ex_data.mem_access_req.time_end + 1;
                     trace_element.wb_data.time_end <= data_mem_rvalid_single_cycle_out;
                     trace_element.wb_data.mem_access_res.time_end <= data_mem_rvalid_single_cycle_out;
                     previous_end <= data_mem_rvalid_single_cycle_out;
                     update_end <= 1'b1;
                     state <= OUTPUT_RESULT;
                 end
             end 
             CHECK_START:
             begin
                 if (wb_ready)
                 begin
                     trace_element.wb_data.time_start <= counter;
                     state <= CHECK_END;
                 end
                 else if (data_mem_rvalid)
                 begin
                     trace_element.wb_data.time_start <= counter;
                     trace_element.wb_data.mem_access_res.time_start <= counter;
                     state <= CHECK_RVALID;
                 end
             end
             CHECK_END:
             begin
                 if (wb_ready)
                 begin
                     trace_element.wb_data.time_end <= counter;
                     state <= OUTPUT_RESULT;
                     previous_end <= counter;
                     update_end <= 1'b1;
                     if (trace_element.wb_data.time_start == counter)
                     begin
                         trace_element.wb_data.time_end <= counter;
                     end
                     else if (data_mem_rvalid)
                     begin
                         trace_element.wb_data.mem_access_res.time_start <= trace_element.wb_data.time_start;
                         trace_element.wb_data.mem_access_res.time_end <= counter;
                     end
                 end
                 else if (data_mem_rvalid)
                 begin
                     trace_element.wb_data.time_end <= counter;
                     trace_element.wb_data.mem_access_res.time_start <= trace_element.wb_data.time_start;
                     trace_element.wb_data.mem_access_res.time_end <= counter;
                     previous_end <= counter;
                     update_end <= 1'b1;
                     state <= OUTPUT_RESULT;
                 end
             end
             CHECK_MEMORY_STATUS:
             begin
                 update_end <= 1'b0;
                 data_mem_rvalid_recalculate_single_cycle <= 1'b0;
                 state <= OUTPUT_RESULT;
                 if (trace_element.wb_data.time_end == data_mem_rvalid_single_cycle_out)
                 begin
                     trace_element.wb_data.mem_access_res.time_start <= trace_element.wb_data.time_start;
                     trace_element.wb_data.mem_access_res.time_end <= data_mem_rvalid_single_cycle_out; 
                 end
             end
             CHECK_RVALID:
             begin
                 if (data_mem_rvalid)
                 begin
                         trace_element.wb_data.time_end <= counter;
                         trace_element.wb_data.mem_access_res.time_start <= trace_element.wb_data.time_start;
                         trace_element.wb_data.mem_access_res.time_end <= counter;
                         previous_end <= counter;
                         update_end <= 1'b1;
                         state <= OUTPUT_RESULT;
                     end
                 end
             OUTPUT_RESULT:
             begin
                 update_end <= 1'b0;
                 if (trace_element.wb_data.mem_access_res.time_end != 0) previous_end_memory = 1'b1;
                 else previous_end_memory = 1'b0;
                 wb_data_o <= trace_element;
                 wb_data_ready <= 1'b1;
                 state <= WRITEBACK_START;
             end
         endcase
     end
         
     always @(previous_end)
     begin
        previous_end_o <= previous_end;
     end
         
     task initialise_module();
         state <= WRITEBACK_START;
         wb_data_ready <= 0;
         wb_ready_value_in <= 0;
         wb_ready_recalculate_time <= 0;
         previous_end_o <= 0;
         data_mem_rvalid_recalculate_single_cycle <= 0;
         previous_end <= 0;
         trace_element <= '{default:0};
     endtask
         
     task check_past_wb_ready_values(input integer queue_input);
         wb_ready_value_in <= queue_input;
         wb_ready_present <= wb_ready;
         wb_ready_recalculate_time <= 1'b1;
     endtask
         
     task check_past_data_mem_res_values(input integer range_start, range_end);
         data_mem_rvalid_range_in <= {range_start, range_end};
         data_mem_rvalid_present <= data_mem_rvalid;
         data_mem_rvalid_recalculate_single_cycle <= 1'b1;
     endtask  

endmodule