module input_mems #(
    parameter INW = 12,
    parameter M = 7,
    parameter N = 9,
    parameter MAXK = 8,
    localparam K_BITS = $clog2(MAXK+1),
    localparam A_ADDR_BITS = $clog2(M*MAXK),
    localparam B_ADDR_BITS = $clog2(MAXK*N)
    )(
    input clk, reset,
    input [INW-1:0] AXIS_TDATA,
    input AXIS_TVALID,
    input [K_BITS:0] AXIS_TUSER,
    output logic AXIS_TREADY,
    output logic matrices_loaded,
    input compute_finished,
    output logic [K_BITS-1:0] K,
    input [A_ADDR_BITS-1:0] A_read_addr,
    output logic signed [INW-1:0] A_data,
    input [B_ADDR_BITS-1:0] B_read_addr,
    output logic signed [INW-1:0] B_data
);

    logic [$clog2(MAXK+1)-1:0] TUSER_K;
    logic new_A;  

    assign TUSER_K = AXIS_TUSER[$clog2(MAXK+1):1]; 
    assign new_A = AXIS_TUSER[0];
    
    // Control signals
    input clear_counter_A;
    input clear_counter_B;
    input increment_counter_A;
    input increment_counter_B;

    input wr_en_A;
    input wr_en_B;
    
    input matrices_loaded;
    
    // Status Signals
    output logic matrix_A_loaded;
    output logic matrix_B_loaded;

    // instantiation of FSM
    input_mems_fsm fsm_inst(
        .clk(clk),
        .reset(reset),
        .AXIS_TVALID(AXIS_TVALID),
        .compute_finished(compute_finished),
        .new_A(new_A),
        .matrix_A_loaded(matrix_A_loaded),
        .matrix_B_loaded(matrix_B_loaded),

        .clear_counter_A(clear_counter_A),
        .clear_counter_B(clear_counter_B),
        .increment_counter_A(increment_counter_A),
        .increment_counter_B(increment_counter_B),
        .matrices_loaded(matrices_loaded),
        .wr_en_a(wr_en_A),
        .wr_en_b(wr_en_B),
        .AXIS_TREADY(AXIS_TREADY)
        // Akarsh comment: output K is missing over here
    );

    // instantiation of Datapath
    input_mems_datapath #(.INW(INW), .M(M), .N(N), .MAXK(MAXK)) datapath_inst(
        .clk(clk),
        .reset(reset),
        .AXIS_TDATA(AXIS_TDATA),

        .A_read_addr(A_read_addr),
        .A_data(A_data),
        .B_read_addr(B_read_addr),
        .B_data(B_data),
        
        .K(K),

        .clear_counter_A(clear_counter_A),
        .clear_counter_B(clear_counter_B),
        .increment_counter_A(increment_counter_A),
        .increment_counter_B(increment_counter_B),

        .wr_en_A(wr_en_A),
        .wr_en_B(wr_en_B),

        .matrices_loaded(matrices_loaded),

        .matrix_A_loaded(matrix_A_loaded),
        .matrix_B_loaded(matrix_B_loaded)
    );
endmodule