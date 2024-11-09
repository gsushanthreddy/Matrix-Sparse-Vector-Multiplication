module input_mems_fsm #(
        parameter MAXK = 9, 
        localparam K_BITS = $clog2(MAXK+1)
    )( 
    input clk, reset,
    input AXIS_TVALID,
    input compute_finished,
    input new_A,
    input matrix_A_loaded,
    input matrix_B_loaded,
    input [$clog2(MAXK+1)-1:0] TUSER_K,  

    output logic matrices_loaded,
    output logic wr_en_a,
    output logic wr_en_b,
    output logic AXIS_TREADY,
    output logic [K_BITS-1:0] K 
);
    enum logic [1:0] {start, load_a, load_b, read} state, next_state;

    always_comb begin
        if(reset==1) begin
            wr_en_a = 0;
            wr_en_b = 0;
            matrices_loaded = 0;
            AXIS_TREADY = 1;
            next_state = start;
        end
        else begin
            if(state == start) begin
                AXIS_TREADY = 1;
                if(AXIS_TVALID) begin
                    if(new_A == 1) begin
                        wr_en_a = 1;
                        wr_en_b = 0;
                        matrices_loaded = 0;
                        next_state = load_a;
                    end
                    else if(new_A == 0) begin
                        wr_en_a = 0;
                        wr_en_b = 1;
                        matrices_loaded = 0;
                        next_state = load_b;
                    end
                end
                else begin
                    wr_en_a = 0;
                    wr_en_b = 0;
                    matrices_loaded = 0;
                    next_state = start;
                end
            end
            else if(state == load_a) begin
                AXIS_TREADY = 1;
                if(matrix_A_loaded == 1) begin
                    wr_en_a = 0;
                    wr_en_b = 0;
                    matrices_loaded = 0;
                    next_state = load_b;
                    AXIS_TREADY = 0;
                end
                else if(matrix_A_loaded == 0) begin
                    if(AXIS_TVALID) begin
                        wr_en_a = 1;
                        wr_en_b = 0;
                        matrices_loaded = 0;
                        next_state = load_a;
                    end
                    else begin
                        wr_en_a = 0;
                        wr_en_b = 0;
                        matrices_loaded = 0;
                        next_state = load_a;
                    end
                end
            end
            else if(state == load_b) begin
                AXIS_TREADY = 1;
                if(matrix_B_loaded == 1) begin
                    wr_en_a = 0;
                    wr_en_b = 0;
                    matrices_loaded = 1;
                    AXIS_TREADY = 0;
                    next_state = read;
                end
                else if(matrix_B_loaded == 0) begin
                    if(AXIS_TVALID) begin
                        wr_en_a = 0;
                        wr_en_b = 1;
                        matrices_loaded = 0;
                        next_state = load_b;
                    end
                    else begin
                        wr_en_a = 0;
                        wr_en_b = 0;
                        matrices_loaded = 0;
                        next_state = load_b;
                    end
                end
            end
            else if(state == read) begin
                AXIS_TREADY = 0;
                if(compute_finished == 0) begin
                    wr_en_a = 0;
                    wr_en_b = 0;
                    matrices_loaded = 1;
                    next_state = read;
                end
                else if(compute_finished == 1) begin
                    wr_en_a = 0;
                    wr_en_b = 0;
                    matrices_loaded = 0;
                    next_state = start;
                end
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
        if(AXIS_TVALID && AXIS_TREADY && new_A && state == start) begin
            K <= TUSER_K;
        end
    end

endmodule