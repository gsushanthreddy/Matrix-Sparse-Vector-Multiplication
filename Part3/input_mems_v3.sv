module input_mems #(
    parameter INW  = 12,
    parameter M    = 7,
    parameter N    = 9,
    parameter MAXK = 8,
    localparam K_BITS      = $clog2(MAXK+1),
    localparam A_ADDR_BITS = $clog2(M*MAXK),
    localparam B_ADDR_BITS = $clog2(MAXK*N)
)(
    input                  clk, reset,
    input [INW-1:0]        AXIS_TDATA,
    input                  AXIS_TVALID,
    input [K_BITS:0]       AXIS_TUSER,
    output logic           AXIS_TREADY,
    output logic           matrices_loaded,
    input                  compute_finished,
    output logic [K_BITS-1:0] K,
    input [A_ADDR_BITS-1:0] A_read_addr,
    output logic signed [INW-1:0] A_data,
    input [B_ADDR_BITS-1:0] B_read_addr,
    output logic signed [INW-1:0] B_data
);

    // Internal signals and registers
    logic [$clog2(M*MAXK)-1:0] a_write_addr;
    logic [$clog2(N*MAXK)-1:0] b_write_addr;
    logic [$clog2(M*MAXK)-1:0] a_addr;
    logic [$clog2(N*MAXK)-1:0] b_addr;
    logic [$clog2(MAXK+1)-1:0] TUSER_K;
    logic new_A;
    logic wr_en_A, wr_en_B;

    // State machine for control logic
    typedef enum logic [1:0] {
        IDLE,
        INPUT_A,
        INPUT_B,
        LOADED
    } state_t;
    state_t state, next_state;

    // Memory instances
    memory #(.WIDTH(INW), .SIZE(M*MAXK)) A_memory (
        .data_in(AXIS_TDATA),
        .data_out(A_data),
        .addr(a_addr),
        .clk(clk),
        .wr_en(wr_en_A)
    );

    memory #(.WIDTH(INW), .SIZE(N*MAXK)) B_memory (
        .data_in(AXIS_TDATA),
        .data_out(B_data),
        .addr(b_addr),
        .clk(clk),
        .wr_en(wr_en_B)
    );

    // Initial assignments
    assign TUSER_K = AXIS_TUSER[$clog2(MAXK+1):1];
    assign new_A = AXIS_TUSER[0];
    assign AXIS_TREADY = (state == INPUT_A || state == INPUT_B);

    // State machine logic
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
            K <= 0;
            matrices_loaded <= 0;
            a_write_addr <= 0;
            b_write_addr <= 0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    if (AXIS_TVALID && AXIS_TREADY) begin
                        if (new_A) begin
                            K <= TUSER_K;
                            next_state <= INPUT_A;
                        end else begin
                            next_state <= INPUT_B;
                        end
                    end
                end

                INPUT_A: begin
                    wr_en_A <= AXIS_TVALID && AXIS_TREADY;
                    if (AXIS_TVALID && AXIS_TREADY) begin
                        if (a_write_addr == M * K - 1) begin
                            a_write_addr <= 0;
                            next_state <= INPUT_B;
                        end else begin
                            a_write_addr <= a_write_addr + 1;
                        end
                    end
                end

                INPUT_B: begin
                    wr_en_B <= AXIS_TVALID && AXIS_TREADY;
                    if (AXIS_TVALID && AXIS_TREADY) begin
                        if (b_write_addr == K * N - 1) begin
                            b_write_addr <= 0;
                            matrices_loaded <= 1;
                            next_state <= LOADED;
                        end else begin
                            b_write_addr <= b_write_addr + 1;
                        end
                    end
                end

                LOADED: begin
                    if (compute_finished) begin
                        matrices_loaded <= 0;
                        next_state <= IDLE;
                    end
                end
            endcase
        end
    end
// Address selection for reading and writing
    always_comb begin
        if (matrices_loaded) begin
            a_addr = A_read_addr;  // Use read address when matrices are loaded
            b_addr = B_read_addr;
        end else begin
            a_addr = a_write_addr; // Use write address during data loading
            b_addr = b_write_addr;
        end
    end
endmodule
