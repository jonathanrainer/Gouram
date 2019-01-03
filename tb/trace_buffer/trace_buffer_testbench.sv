import ryuki_datatypes::trace_output;

module trace_buffer_testbench;

    logic clk;
    logic rst;
    integer signed counter;
    trace_output [0:3] test_traces;
    logic ready_signal;
    trace_output trace_element_in;
    logic data_request;
    
    integer signal_counter_trace_release = 0;
    integer signal_counter_trace_request = 0;
    integer trace_pointer = 0;
        
    trace_output trace_element_out;
    bit data_present;
    
    trace_buffer t_buff(.*);
    
    initial
    begin
        clk = 0;
        $srandom(20);
        test_traces[0].if_data.time_start = 100;
        test_traces[1].if_data.time_start = 200;
        test_traces[2].if_data.time_start = 300;
        test_traces[3].if_data.time_start = 400;
        counter = -1;
        #50 rst = 1; counter = -1;
        #1000 $finish;
    end
    
    always
    begin
        #5 clk = ~clk;
    end
    
    always@ (posedge clk)
    begin
        counter++;
    end
    
    always@ (posedge clk)
    begin
        if (signal_counter_trace_release > 5) 
        begin
            ready_signal = 1'b1;
            trace_element_in = test_traces[trace_pointer];
            signal_counter_trace_release = 0;
            trace_pointer++;
            if (trace_pointer == 4) trace_pointer = 0;
        end
        else 
        begin
            signal_counter_trace_release++;
            ready_signal = 1'b0;
        end
    end
    
    always@ (posedge clk)
    begin
        if (signal_counter_trace_request == 2)
        begin
            data_request = 1'b1;
            signal_counter_trace_request++;
        end
        else if (signal_counter_trace_request == 3)
        begin
            signal_counter_trace_request = 0;
            data_request = 0;
        end
        else signal_counter_trace_request++;
    end
    
    always@ (posedge rst)
    begin
        signal_counter_trace_release = 0;
        signal_counter_trace_request = 0;
        trace_pointer = 0;
    end
    
      
        

endmodule
