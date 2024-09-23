module mac_pipe #(
    parameter INW = 16,
    parameter OUTW = 48,
    localparam MINVAL = (64'd1<<(OUTW-1)),
    localparam MAXVAL = (64'd1<<(OUTW-1))-1
)(
    input signed [INW-1:0]          in0,
    input signed [INW-1:0]          in1,
    input                           valid_input,
    input                           clear_acc,
    input                           reset,
    input                           clk,
    output logic signed [OUTW-1:0]  out
);

    logic signed [2*INW-1:0]    mult_out;
    logic signed [2*INW-1:0]    pipe_line_rg_out;
    logic signed [OUTW-1:0]     add_out;
    logic signed enable_out_register;

    always_comb 
    begin
        mult_out = in0 * in1;
    end

    always_ff @(posedge clk) begin
        if(reset) begin
            pipe_line_rg_out <= 0;
            enable_out_register <= 0;
        end
        else begin
            pipe_line_rg_out <= mult_out;
            enable_out_register <= valid_input;
        end
    end

    always_comb begin
        add_out  = pipe_line_rg_out + out;
        // Handling Saturation 
        /* If both the inputs to the adder are positive(signed bit=0) and the result add_out is negative(signed bit=1), then overflow occured. 
        If both the inputs of the adder are negative and add_out is positive, then also overflow occured. 
        */
        if(out[OUTW-1]==1 && pipe_line_rg_out[2*INW-1]==1 && add_out[OUTW-1]==0) begin 
            add_out = -MINVAL;
        end
        else if(out[OUTW-1]==0 && pipe_line_rg_out[2*INW-1]==0 && add_out[OUTW-1]==1) begin
            add_out = MAXVAL;
        end
        else begin
            add_out = $signed(add_out);
        end
    end

    always_ff @(posedge clk) 
    begin 
        if(reset || clear_acc) begin
            out <= 0;
            data_ready <= 0;
        end
        else if(enable_out_register) begin
            out <= add_out;
        end
        
    end

endmodule