module MMM #(
    parameter INW = 12,
    parameter OUTW = 36,
    parameter M = 6,
    parameter N = 11,
    parameter MAXK = 8,
    localparam K_BITS = $clog2(MAXK+1)
)(
    input clk,
    input reset,
    input [INW-1:0] INPUT_TDATA,
    input INPUT_TVALID,
    input [K_BITS:0] INPUT_TUSER,
    output INPUT_TREADY,
    output [OUTW-1:0] OUTPUT_TDATA,
    output OUTPUT_TVALID,
    input OUTPUT_TREADY
);
    // logics for counting read address in control logic
    logic [$clog2(M+1)-1:0] m;
    logic [$clog2(N+1)-1:0] n;
    logic [K_BITS:0] k; // made a change
    logic clear_m, clear_n, clear_k;
    logic increment_k, increment_m, increment_n;
    
    // logical connections between input_mems and mac_pipe
    logic signed [INW-1:0] A_data_from_input_mems;
    logic signed [INW-1:0] B_data_from_input_mems;
     
    // logical connections between mac_pipe and fifo_out
    logic signed [OUTW-1:0]  output_from_mac;

    // logical connections between input_mems and control logic
    logic [$clog2(M*MAXK)-1:0] A_read_addr;
    logic [$clog2(MAXK*N)-1:0] B_read_addr;
    logic matrices_loaded;
    logic [K_BITS-1:0] K;
    logic compute_finished;
    
    // logical connections between mac_pipe and control logic
    logic clear_acc;
    logic valid_input;

    // logical connections between fifo_out and control logic
    logic wr_en_fifo;
    logic [($clog2(N+1))-1:0] capacity;

    // initialising FSM
    enum logic [1:0] {mmm_start, read_from_input_memory, store_in_fifo} state, next_state;
  
    always_ff @(posedge clk) begin
        if(reset) begin
            state <= mmm_start;
            k <= 0;
            m <= 0;
            n <= 0;
            compute_finished <= 1;
            valid_input <= 0;
            clear_acc <= 1;
        end
        else begin
            if(state == mmm_start) begin
                if(matrices_loaded == 1) begin
                    state <= read_from_input_memory;
                    compute_finished <= 0;
                    valid_input <= 0;
                    clear_acc <= 1;
                end
            end
            else if(state == read_from_input_memory) begin
                if(k==1) begin
                   valid_input <= 1; 
                end
                else if(k == K+1) begin
                    valid_input <= 0;
                end
                if(k==2) begin
                    clear_acc <= 0;
                end
                if(k<K) begin
                    A_read_addr <= m*K + k;
                    B_read_addr <= k*N + n;
                    k <= k+1;
                end
                else begin
                    if(k == K+3) begin
                        state <= store_in_fifo;
                        k <= 0;
                    end
                    else begin
                        state <= read_from_input_memory;
                        k <= k + 1;
                    end
                end
            end
            else if(state == store_in_fifo) begin
                if(capacity != 0) begin
                    if(n<N-1) begin
                        n <= n + 1;
                        clear_acc <= 1;
                        state <= read_from_input_memory;
                    end
                    else if(m<M-1) begin
                        n <= 0;
                        m <= m + 1;
                        clear_acc <= 1;
                        state <= read_from_input_memory;
                    end
                    else begin
                        state <= mmm_start;
                        m <= 0;
                        n <= 0;
                        k <= 0;
                        compute_finished <= 1;
                    end
                end
            end
        end
    end

    always_comb begin
        wr_en_fifo = 0;
        if(state == mmm_start) begin
            wr_en_fifo = 0;
        end
        else if(state == read_from_input_memory) begin
            wr_en_fifo = 0;
        end
        else if(capacity != 0 && state == store_in_fifo) begin
            wr_en_fifo = 1;
        end
    end

    
    // Instantiating input memories unit
    input_mems #(.INW(INW), .M(M), .N(N), .MAXK(MAXK)) input_memories_inst(
        .clk(clk),
        .reset(reset),
        .AXIS_TDATA(INPUT_TDATA),
        .AXIS_TVALID(INPUT_TVALID),
        .AXIS_TUSER(INPUT_TUSER),
        .AXIS_TREADY(INPUT_TREADY),
        .matrices_loaded(matrices_loaded),
        .compute_finished(compute_finished),
        .K(K),
        .A_read_addr(A_read_addr),
        .A_data(A_data_from_input_mems),
        .B_read_addr(B_read_addr),
        .B_data(B_data_from_input_mems)

    );

    //instantiating piplined mac unit
    mac_pipe #(.INW(INW), .OUTW(OUTW)) pipelined_mac_inst(
        .in0(A_data_from_input_mems),
        .in1(B_data_from_input_mems),
        .valid_input(valid_input),
        .clear_acc(clear_acc),
        .reset(reset),
        .clk(clk),
        .out(output_from_mac)
    );

    //instantiating output fifo unit
    fifo_out #(.OUTW(OUTW), .DEPTH(N)) output_fifo_inst(
        .clk(clk),
        .reset(reset),
        .data_in(output_from_mac),
        .wr_en(wr_en_fifo),
        .capacity(capacity),
        .AXIS_TDATA(OUTPUT_TDATA),
        .AXIS_TVALID(OUTPUT_TVALID),
        .AXIS_TREADY(OUTPUT_TREADY)
    );

endmodule

