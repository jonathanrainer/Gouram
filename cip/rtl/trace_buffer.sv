module trace_buffer
#(
    parameter BUFFER_WIDTH = 8,
    parameter type trace_output = int
)
(
    // Externally Required Signals

    input logic clk,
    input logic rst_n,
    input bit ready_signal,
    input trace_output trace_element_in,
    input bit data_request,
    
    // Outputs
    
    output bit data_present,
    output trace_output trace_element_out
);

    trace_output buffer [BUFFER_WIDTH-1:0];
    bit signed [$clog2(BUFFER_WIDTH):0] front; 
    bit signed [$clog2(BUFFER_WIDTH):0] rear;
    
    integer size = 0;
    
    // Clocked Part (Data Collection)
    always@(negedge clk)
    begin
        if (ready_signal)
        begin
            rear = (rear + 1) % BUFFER_WIDTH;
            buffer[rear] = trace_element_in;
            size++;
            if (rear == front && size == BUFFER_WIDTH) front = (front + 1) % BUFFER_WIDTH;
            if (front == -1) front = 0;
            data_present = 1'b1;
        end
    end
    
    // Unclocked Part (Data Output)
    always@ (posedge data_request)
    begin
        if (data_present)
        begin
            trace_element_out = buffer[front];
            front = (front + 1) % BUFFER_WIDTH;
            size--;
            if (size == 0)
            begin
                front = -1;
                rear = -1;
                data_present = 1'b0;
            end
        end
    end
        
    // Reset behaviour
    
    always@(posedge rst_n)
    begin
        if (rst_n)
        begin
            front <= -1;
            rear <= -1;
            buffer <= '{default:0};
        end
    end

endmodule
