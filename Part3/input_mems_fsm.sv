module input_mems_fsm #(
        parameter MAXK = 8, // add this while connecting fsm and datapath
        localparam K_BITS = $clog2(MAXK+1)
    )( 
    input clk, reset,
    input AXIS_TVALID,
    input compute_finished,
    input new_A,
    input matrix_A_loaded,
    input matrix_B_loaded,
    input [K_BITS:0] AXIS_TUSER, // add this while connecting fsm and datapath

    output logic matrices_loaded,
    output logic wr_en_a,
    output logic wr_en_b,
    output logic AXIS_TREADY,
    output logic [K_BITS-1:0] K // add this while connecting fsm and datapath
);
    enum {start, load_a, load_b, read} state, next_state;

    always_comb begin
        // matrices_loaded = 0;
        wr_en_a = 0;
        wr_en_b = 0;
        AXIS_TREADY = 1;

        if (state==start) begin
            if (AXIS_TVALID && AXIS_TREADY) begin
                if (new_A==1) begin
                    wr_en_a = 1;
                    next_state = load_a;
                end
                else if(new_A==0) begin
                    wr_en_b = 1;
                    next_state = load_b;
                end
            end 
            else begin
                next_state = start;
            end
        end
        else if (state==load_a) begin
            if(matrix_A_loaded==0) begin
                if(AXIS_TVALID) begin
                    wr_en_a = 1;
                end
                next_state = load_a;
            end
            else if(matrix_A_loaded==1) begin
                // wr_en_b = 1;
                next_state = load_b;
            end
        end
        else if (state==load_b) begin
            if(matrix_B_loaded==0) begin
                if(AXIS_TVALID) begin
                    wr_en_b = 1;
                end
                next_state = load_b;
            end
            else if(matrix_B_loaded==1) begin
                matrices_loaded = 1;
                next_state = read;
            end
        end
        else if (state==read) begin
            if (compute_finished) begin
                next_state = start;
                matrices_loaded = 0;
            end
            else begin
                AXIS_TREADY = 0;
                next_state = read;
            end
        end
    end

    always_ff @(posedge clk) begin
        if(reset) begin
            state <= start;
        end
        else begin
            state <= next_state;
        end
    end

    always_ff @(posedge clk) begin
        if(AXIS_TVALID && AXIS_TREADY && state==start) begin //check logic
            K <= AXIS_TUSER[$clog2(MAXK+1):1];
        end
    end
endmodule