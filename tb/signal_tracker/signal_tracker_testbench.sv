`timescale 1ns / 1ps


module signal_tracker_testbench;

    logic clk;
    logic rst;
    integer signed counter;
    integer signal_counter_ts;
    integer signal_counter_ri;
    integer signal_counter_vi;
    logic tracked_signal;
    integer value_in;
    integer range_in [1:0];
    
    
    integer signed time_out [1:0];
    bit range_out;
    
    signal_tracker sig_track(.*);
    
    initial
    begin
        clk = 0;
        $srandom(20);
        signal_counter_ts = 0;
        signal_counter_ri = 0;
        signal_counter_vi = 0;
        counter = -1;
        tracked_signal = 0;
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
        if (signal_counter_ts > 2) 
        begin
            tracked_signal = ~tracked_signal;
            signal_counter_ts = 0;
        end
        else signal_counter_ts++;
    end
    
    always@ (posedge clk)
    begin
        if (signal_counter_ri > 12) 
        begin
            range_in = {3, 1};
        end
        else signal_counter_ri++;
    end
    
    always@ (posedge clk)
    begin
        if (signal_counter_vi > 5) 
        begin
            value_in = $urandom_range(8,0);
            signal_counter_vi = 0;
        end
        else signal_counter_vi++;
    end
    
    always@ (posedge rst)
    begin
        signal_counter_ri = 0;
        signal_counter_ts = 0;
        signal_counter_vi = 0;
    end
    
      
        

endmodule
