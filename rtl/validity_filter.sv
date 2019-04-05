import gouram_datatypes::*;

module validity_filter
#(
    parameter TRACE_BUFFER_SIZE = 16,
    parameter type trace_format = int,
    parameter SIGNAL_BUFFER_SIZE = 128,
    parameter DATA_WIDTH = 32
)
(
    // Generic Inputs
    input bit clk,
    input bit rst_n,
    input integer counter,
    
    // Inputs from Fetch Phase
    input trace_format if_data_i,
    input integer if_stage_end_i,
    input bit if_data_ready,
    
    // Inputs from Processor
    input bit is_decoding,
    input bit branch_decision,
    input bit jump_done,
    
    // Outputs
    output trace_format filtered_data,
    output integer if_stage_end_o,
    output bit filtered_data_ready
);

    // Buffer for Traces that come from IF Tracker
     bit data_request;
     bit data_present;
     bit data_valid; 
     integer if_stage_end_buffer_output;
     trace_format buffer_output;
     trace_buffer #(TRACE_BUFFER_SIZE, trace_format) t_buffer (
        .clk(clk), .rst_n(rst_n), .ready_signal(if_data_ready), .trace_element_in(if_data_i), 
        .data_request(data_request), .data_present(data_present), .trace_element_out(buffer_output),
        .data_valid(data_valid), .if_stage_end_in(if_stage_end_i), .if_stage_end_out(if_stage_end_buffer_output)
     );


    // Internal Buffer to hold the trace element being constructed
    trace_format trace_element;
    
    // Buffers to hold the signals of interest
    signal_tracker_if #(1) is_decoding_port (clk, rst_n, counter, is_decoding);
    signal_tracker_time_test  #(SIGNAL_BUFFER_SIZE) is_decoding_buffer (
        is_decoding_port.TimeTest
    );
    bit is_decoding_buffered;
    
    // Buffers to hold the signals of interest
    signal_tracker_if #(1) jump_done_port (clk, rst_n, counter, jump_done);
    signal_tracker_time_test  #(SIGNAL_BUFFER_SIZE) jump_done_buffer (
        jump_done_port.TimeTest
    );
    
    // Buffers to hold the signals of interest
    signal_tracker_if #(1) branch_decision_port (clk, rst_n, counter, branch_decision);
    signal_tracker_value_find  #(SIGNAL_BUFFER_SIZE) branch_decision_buffer (
        branch_decision_port.ValueFind
    );
    
    // Internal State
    integer previous_end;
    integer signed decode_phase [1:0]; 
    
    // State Machine to Control Unit
    enum bit [2:0] {
            FILTER_START =              3'b000,
            GET_DATA_FROM_BUFFER =      3'b001,
            CALCULATE_DECODE_PHASE =    3'b010,
            SCAN_FOR_DECODE_PHASE  =    3'b011,
            CHECK_JUMP_DONE =           3'b100,
            CHECK_BRANCH_DECISION =     3'b101,
            OUTPUT_DATA =     3'b110
         } state;

    always @(posedge clk)
    begin
        if(!rst_n) initialise_device();
        else
        begin
            unique case(state)
                FILTER_START:
                begin
                    filtered_data_ready <= 1'b0;
                    if (data_present)
                    begin
                        data_request <= 1'b1;
                        state <= GET_DATA_FROM_BUFFER;
                    end
                end
                GET_DATA_FROM_BUFFER:
                begin
                    if (data_valid)
                    begin
                        data_request <= 1'b0;
                        trace_element <= buffer_output;
                        // Calculate how long the decode phase is 
                        check_past_is_decoding_values((if_stage_end_buffer_output > previous_end) ? counter - if_stage_end_buffer_output: counter - previous_end+1);   
                        decode_phase <= {-1,-1};   
                        state <= CALCULATE_DECODE_PHASE;
                    end 
                end
                CALCULATE_DECODE_PHASE:
                begin
                    if (is_decoding_port.data_valid)
                    begin
                        is_decoding_port.recalculate_time <= 0;
                        state <= CHECK_JUMP_DONE;
                        check_past_jump_done_values(counter-if_stage_end_buffer_output);
                        // Several things can happen here: #1 The whole decode phase is found by scanning the buffer
                        if(is_decoding_port.time_out[0] != -1 && is_decoding_port.time_out[1] != -1) 
                        begin
                            decode_phase <= is_decoding_port.time_out;
                        end
                        // #2 The start might be found in the buffer but no end: So either the end is in the saved values or needs to be scanned for
                        else if (is_decoding_port.time_out[0] != -1 && is_decoding_port.time_out[1] == -1)
                        begin
                            decode_phase[0] <= is_decoding_port.time_out[0];
                            if (!is_decoding_buffered) decode_phase[1] <= counter-2;
                            else if (!is_decoding) decode_phase[1] <= counter-1;
                            else state <= SCAN_FOR_DECODE_PHASE;
                        end  
                        else if (is_decoding_port.time_out[0] == -1 && is_decoding_port.time_out[1] == -1)
                        begin
                            if (is_decoding_buffered && !is_decoding)
                            begin
                                decode_phase[0] <= counter-2;
                                decode_phase[1] <= counter-2;
                            end
                            else if (!is_decoding_buffered && is_decoding)
                            begin
                                decode_phase[0] <= counter-1;
                                state <= SCAN_FOR_DECODE_PHASE;
                            end
                        end
                        else state <= SCAN_FOR_DECODE_PHASE;  
                    end
                is_decoding_buffered <= is_decoding;
                end
                SCAN_FOR_DECODE_PHASE:
                if (decode_phase[0] != -1 && !is_decoding) 
                begin
                    decode_phase[1] <= counter;
                    check_past_jump_done_values(counter-if_stage_end_buffer_output+1);
                    state <= CHECK_JUMP_DONE;
                end
                else if (decode_phase[0] == -1 && is_decoding)
                begin
                    decode_phase[0] <= counter;
                end
                CHECK_JUMP_DONE:
                begin
                    if (jump_done_port.data_valid)
                    begin
                        jump_done_port.recalculate_time <= 0;
                        if(jump_done_port.time_out[0] != -1 && jump_done_port.time_out[0] <= decode_phase[1]) state <= FILTER_START;
                        else 
                        begin
                            check_past_branch_decision_values(counter-(decode_phase[1]) +1);
                            state <= CHECK_BRANCH_DECISION;
                        end
                    end
                end
                CHECK_BRANCH_DECISION:
                begin
                    if (branch_decision_port.data_valid)
                    begin
                        branch_decision_port.recalculate_back_cycle <= 1'b0;
                        if(branch_decision_port.signal_recall) state <= FILTER_START;
                        else state <= OUTPUT_DATA;
                    end
                end
                OUTPUT_DATA:
                begin
                    filtered_data_ready <= 1'b1;
                    filtered_data <= trace_element;
                    if_stage_end_o <= if_stage_end_buffer_output;
                    state <= FILTER_START;
                    previous_end <= decode_phase[1];
                end
            endcase
        end
    end
    
    initial
    begin
        initialise_device();
    end


    task initialise_device();
        filtered_data <= '{default: 0};
        filtered_data_ready <= 0;
        previous_end <= 0;
    endtask
    
    task check_past_is_decoding_values(input integer queue_input);
            is_decoding_port.value_in <= queue_input;
            is_decoding_buffered <= is_decoding;
            is_decoding_port.recalculate_time <= 1'b1;
    endtask 
    
    task check_past_jump_done_values(input integer queue_input);
           jump_done_port.value_in <= queue_input;
           jump_done_port.recalculate_time <= 1'b1;
    endtask 
   
    task check_past_branch_decision_values(input integer queue_input);
           branch_decision_port.cycles_back_to_recall <= queue_input;
           branch_decision_port.recalculate_back_cycle <= 1'b1;
    endtask

endmodule
