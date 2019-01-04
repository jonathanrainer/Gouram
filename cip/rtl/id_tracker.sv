module id_tracker
#(
    parameter INSTR_DATA_WIDTH = 32,
    parameter DATA_ADDR_WIDTH = 32,
    parameter TRACE_BUFFER_SIZE = 32,
    parameter type trace_format = int
)
(
    input logic clk,
    input logic rst,
    
    // Inputs from Counter
    input integer counter,

    // Inputs from IF Tracker
    input logic if_data_valid,
    trace_format if_data_i,
    
    // Inputs from ID Pipeline Stage
    input logic id_ready,
    input logic jump_done,
    input logic is_decoding,
    input logic illegal_instruction,
    input logic branch_req,
    input logic branch_decision,
    
    // Outputs to EX Tracker
    trace_format id_data_o,
    output logic id_data_ready
);

    trace_format trace_element;
    // IF Pipeline Stage State Machine
    enum logic [2:0]  {
        DECODE_START =          3'b000,
        GET_DATA_FROM_BUFFER =  3'b001,
        CHECK_ILLEGAL_INSTR =   3'b010,
        CHECK_PAST_TIME =       3'b011,
        WAIT_START_TIME =       3'b100,
        RECHECK_END_TIME =      3'b101,
        CHECK_JUMP =            3'b110,
        OUTPUT_RESULT =         3'b111
     } state;
     
     integer  is_decoding_value_in = 0;
     integer  is_decoding_time_out [1:0] = {0,0};
     bit recalculate_time = 1'b0;
     integer previous_end = 0;
     integer potential_previous_end = 0;
     bit update_end = 1'b0;
     advanced_signal_tracker #(1, 1, 128) is_decoding_buffer  (
        .clk(clk), .rst(rst), .counter(counter), .tracked_signal(is_decoding), .corroborating_signal(id_ready), 
        .value_in(is_decoding_value_in), .time_out(is_decoding_time_out), .recalculate_time(recalculate_time),
        .update_end(update_end), .previous_end_i(previous_end)
     );
     logic is_decoding_present = 0;
     logic id_ready_present = 0;
     
     // Place to track the state of id_ready when the start is discovered to make tracking the 
     // end of the intervals easier.
     logic id_ready_start_state = 0;
     
     integer jump_done_range_in [1:0] = {0,0};
     bit jump_done_range_out = 0;
     bit recalculate_jump_done_range = 1'b0;
     signal_tracker  #(1, 128) jump_done_buffer (
        .clk(clk), .rst(rst), .counter(counter), .tracked_signal(jump_done), .range_in(jump_done_range_in),
        .range_out(jump_done_range_out), .recalculate_range(recalculate_jump_done_range), .ready_flag(1'b1),
        .ex_ready_flag(1'b0), .data_mem_req_flag(1'b0)
     );
     logic jump_done_present = 0;
     bit [DATA_ADDR_WIDTH-1:0] jump_addr_loc  = 0;
     
     // Place to track the state of the illegal_instruction marker that indicates when a fetch has failed
     // to fetch a valid instruction
     
     integer illegal_instruction_range_in [1:0] = {0,0};
     bit illegal_instruction_range_out = 0;
     bit recalculate_illegal_instruction_range = 1'b0;
     signal_tracker  #(1, 128) illegal_instruction_buffer (
        .clk(clk), .rst(rst), .counter(counter), .tracked_signal(illegal_instruction), 
        .range_in(illegal_instruction_range_in),
        .range_out(illegal_instruction_range_out), .recalculate_range(recalculate_illegal_instruction_range),
        .ready_flag(1'b1), .ex_ready_flag(1'b0), .data_mem_req_flag(1'b0)
     );
     logic illegal_instruction_present = 0;
       
     integer branch_decision_range_in [1:0] = {0,0};
     integer branch_decision_single_cycle_out = 0;
     bit recalculate_branch_decision_single_cycle = 1'b0;
     signal_tracker  #(1, 128) branch_decision_buffer (
         .clk(clk), .rst(rst), .counter(counter), .tracked_signal(branch_decision && branch_req), 
         .range_in(branch_decision_range_in),
         .single_cycle_out(branch_decision_single_cycle_out), 
         .recalculate_single_cycle(recalculate_branch_decision_single_cycle),
         .ready_flag(1'b1), .ex_ready_flag(1'b0), .data_mem_req_flag(1'b0)
     );
     logic branch_decision_present = 0;
     
     // Trace Buffer
     bit data_request = 1'b0;
     bit data_present;
     trace_format buffer_output;
     trace_buffer #(TRACE_BUFFER_SIZE, trace_format) t_buffer  (
        .clk(clk), .rst(rst), .ready_signal(if_data_valid), .trace_element_in(if_data_i), 
        .data_request(data_request), .data_present(data_present), .trace_element_out(buffer_output)
     );
     
    always_ff @(posedge clk)
    begin
        unique case(state)
            DECODE_START:
            begin
                update_end = 1'b0;
                id_data_ready <= 1'b0;
                if (data_present) 
                begin
                    data_request <= 1'b1;
                    state <= GET_DATA_FROM_BUFFER;
                end
            end
            GET_DATA_FROM_BUFFER:
            begin
                data_request <= 1'b0;
                // Copy in data to the internal trace buffer
                trace_element <= buffer_output;
                check_past_illegal_instruction_values(buffer_output.if_data.time_end);
                state <= CHECK_ILLEGAL_INSTR;
            end
            CHECK_ILLEGAL_INSTR:
            begin
                recalculate_illegal_instruction_range <= 1'b0;
                if (illegal_instruction_range_out)
                begin
                    trace_element.pass_through <= 1'b1;
                    trace_element.id_data <= '{default:0};
                    trace_element.ex_data <= '{default:0};
                    trace_element.wb_data <= '{default:0};  
                    state <= OUTPUT_RESULT;
                end
                else
                begin
                    check_past_is_decoding_values(counter - buffer_output.if_data.time_end);
                    state <= CHECK_PAST_TIME;
                end
            end
            CHECK_PAST_TIME:
            begin
                recalculate_time <= 1'b0;
                // If no start point has been found then the signal cannot have started so 
                // either it started in one of the two tracked signals or we're still waiting
                // for it to start.
                if (is_decoding_time_out[0] == -1)
                begin
                    if (is_decoding_present && (counter -1) > previous_end)
                    begin
                        // If this is valid then the start point has been found. It's still possible 
                        // and end point may have been tracked also so then check for that
                        trace_element.id_data.time_start <= counter - 1;
                        if (!is_decoding || (is_decoding && !id_ready))
                        begin
                            // If the above conditions are met then the end point was tracked also so there's
                            // no need to change the state variable as CHECK_JUMP is the correct next location.
                            trace_element.id_data.time_end <= counter;
                            previous_end = counter;
                            check_past_jump_done_values(counter-1, counter);
                            check_past_branch_decision_values(trace_element.if_data.time_end, counter);
                            state <= CHECK_JUMP;
                        end
                        // If no end time is found then move to the state that constantly checks for an end.
                        else 
                        begin
                            id_ready_start_state <= id_ready;
                            state <= RECHECK_END_TIME; 
                        end
                    end
                    // If the is_decoding_present variable didn't get the start point there's a chance the 
                    // current value of is_decoding still holds the data we need solve
                    if (is_decoding && counter > previous_end)
                    begin
                        trace_element.id_data.time_start <= counter;
                        // A start time has been found but as yet no end time so jump to a new state 
                        // to wait for that.
                        id_ready_start_state <= id_ready;
                        state <= RECHECK_END_TIME;
                    end
                    // If none of this happens then you need to just check for a start time constantly
                    else state <= WAIT_START_TIME;
                end
                else if (is_decoding_time_out[1] == -1)
                begin
                    trace_element.id_data.time_start <= is_decoding_time_out[0];
                    // If you have a start point but as yet no end point you need to check through the
                    // other saved values to see whether the end point has been tracked or it needs to 
                    // be checked for.
                    if (!is_decoding_present && id_ready_present)
                    begin
                        trace_element.id_data.time_end <= counter;
                        potential_previous_end <= counter;
                        check_past_jump_done_values(is_decoding_time_out[0], counter);
                        check_past_branch_decision_values(trace_element.if_data.time_end, counter);
                        state <= CHECK_JUMP;
                    end
                    else if (!is_decoding || id_ready)
                    begin
                        trace_element.id_data.time_end <= counter;
                        potential_previous_end <= counter;
                        check_past_jump_done_values(is_decoding_time_out[0], counter);
                        check_past_branch_decision_values(trace_element.if_data.time_end, counter);
                        state <= CHECK_JUMP;
                    end
                    else 
                    begin
                        id_ready_start_state <= id_ready;
                        state <= RECHECK_END_TIME;
                    end
                end
                else
                begin
                    trace_element.id_data.time_start <= is_decoding_time_out[0];
                    trace_element.id_data.time_end <= is_decoding_time_out[1];
                    potential_previous_end <= is_decoding_time_out[1];
                    check_past_jump_done_values(is_decoding_time_out[0], is_decoding_time_out[1]);
                    check_past_branch_decision_values(trace_element.if_data.time_end, is_decoding_time_out[1]+1);
                    state <= CHECK_JUMP;
                end
            end
            WAIT_START_TIME:
            begin
                if(is_decoding && (counter > previous_end))
                begin
                    trace_element.id_data.time_start <= counter;
                    id_ready_start_state <= id_ready;
                    state <= RECHECK_END_TIME;
                end
            end
            RECHECK_END_TIME:
            begin
                if (!is_decoding || (id_ready_start_state && !id_ready))
                begin
                    trace_element.id_data.time_end <= counter - 1;
                    potential_previous_end <= counter - 1;
                    check_past_jump_done_values(trace_element.id_data.time_start, counter - 1);
                    check_past_branch_decision_values(trace_element.if_data.time_end, counter - 1);
                    state <= CHECK_JUMP;
                end
                else if (!id_ready_start_state && id_ready)
                begin
                     trace_element.id_data.time_end <= counter;
                     potential_previous_end <= counter;
                     check_past_jump_done_values(trace_element.id_data.time_start, counter);
                     check_past_branch_decision_values(trace_element.if_data.time_end, counter);
                     state <= CHECK_JUMP;
                end
            end
            CHECK_JUMP:
            begin
                recalculate_jump_done_range <= 1'b0;
                recalculate_branch_decision_single_cycle <= 1'b0;
                state <= OUTPUT_RESULT;
                if (jump_done_range_out && jump_addr_loc == 0)
                begin
                    jump_addr_loc <= trace_element.addr;
                    trace_element.pass_through <= 1'b1;
                    trace_element.ex_data <= '{default:0};
                    trace_element.wb_data <= '{default:0};  
                end
                else if ((branch_decision_single_cycle_out <= trace_element.id_data.time_end && 
                branch_decision_single_cycle_out >= trace_element.if_data.time_end) || (jump_addr_loc > 0 && trace_element.addr - jump_addr_loc == 4))
                begin
                    jump_addr_loc <= trace_element.addr;
                    // If this isn't valid then we can invalidate the DECODE phase
                    trace_element.pass_through <= 1'b1;
                    trace_element.ex_data <= '{default:0};
                    trace_element.wb_data <= '{default:0};  
                    trace_element.id_data <= '{default:0};
                    potential_previous_end = previous_end;
                end
                else jump_addr_loc <= 1'b0;
            end
           OUTPUT_RESULT:
           begin
                id_data_o <= trace_element;
                id_data_ready <= 1'b1;
                previous_end <= potential_previous_end;
                update_end <= 1'b1;
                state <= DECODE_START;
           end
        endcase
    end
    
    always @(posedge rst)
    begin
        initialise_module();
    end
    
    initial
    begin
        initialise_module();
    end
    
    task initialise_module();
    begin
        state <= DECODE_START;
        id_data_ready <= 0;
        is_decoding_value_in <= 0;
        jump_done_range_in <= {0,0};
        recalculate_time <= 0;
        recalculate_jump_done_range <= 0;
        trace_element <= '{default:0};
    end
    endtask
    
    task check_past_is_decoding_values(input integer queue_input);
        is_decoding_value_in <= queue_input;
        is_decoding_present <= is_decoding;
        id_ready_present <= id_ready;
        recalculate_time <= 1'b1;
    endtask
    
    task check_past_jump_done_values(input integer queue_end, queue_start);
        jump_done_range_in <= {queue_end, queue_start};
        jump_done_present = jump_done;
        recalculate_jump_done_range <= 1'b1;
    endtask
    
    task check_past_branch_decision_values(input integer queue_end, queue_start);
            branch_decision_range_in <= {queue_end, queue_start};
            branch_decision_present = jump_done;
            recalculate_branch_decision_single_cycle <= 1'b1;
    endtask
    
    task check_past_illegal_instruction_values(input integer queue_end);
        illegal_instruction_range_in <= {queue_end+1, queue_end+1};
        illegal_instruction_present = jump_done;
        recalculate_illegal_instruction_range <= 1'b1;
    endtask
  
endmodule 