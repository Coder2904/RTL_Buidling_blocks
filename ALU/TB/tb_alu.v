`timescale 1ns/1ps // time unit and time precision
 
module tb_alu;
    parameter W = 32; /// its a parameterised Testbenches we can run 32-bit alu 8-bit alu
    localparam Shift_width = $clog2(W);

    // Here we are definiting our operation control codes for these operations similar to out RTL
    localparam [3:0]  ADD=0, SUB=1, AND_Op=2, OR_Op=3, XOR_op=4,
                  SHIFT_LEFT_LOGICAl=5, SHIFT_RIGHT_LOGICAL=6, SHIFT_RIGHT_ARITHEMATIC=7,
                  SET_LESS_THAN=8, SET_LESS_THAN_UNsigned=9;

    // boundary value test vectors
    localparam [W-1:0] ZEROS = {W{1'b0}};    // All bits are zero-----To test zero inputs, zero results, and the zero flag.
    localparam [W-1:0] ONES  = {W{1'b1}};    // All bits are one------To test maximum unsigned values, bitwise operations, and boundary conditions.
    localparam [W-1:0] MAX_P = {1'b0, {(W-1){1'b1}}};    // Maximum signed positive  ----in general = 2^(W-1) -1
    localparam [W-1:0] MIN_N = {1'b1, {(W-1){1'b0}}};      // mainimum signed negative  ----in general = -2^(W-1)


    // Wire connections
    reg [W-1:0] a, b;
    reg [3:0]   Operation_ctrl;
    wire [W-1:0] result;
    wire        zero_flag, overflow_flag;

    // Module instantiated ----> connecting to RTL --- these passes the testbench parameter W to ALU
    alu #(.WIDTH(W)) dut (.a(a), .b(b), .Operation_ctrl(Operation_ctrl),
                          .result(result), .zero_flag(zero_flag), .overflow_flag(overflow_flag));

    // Variable of Testbenches
    integer errors = 0 , tests = 0, i, k; // errors= counts failed checks, tests= counts total checks // i and k are loop counters
    // these two are calculated by the testbench 
    reg [W-1:0] expect_result;
    reg         expect_overflow;
    //not obtained from DUT
    reg [Shift_width-1:0] expect_shift;
    reg [W-1:0] special [0:5]; // 6 elements each of width W ---- stores corner cases operands 


    // Independent Behavioural reference model
    task model;
         begin
            expect_shift = b[Shift_width-1:0];
            expect_overflow = 1'b0; // initializing it to zero means that operations that don't calculate arithmetic overflow automatically retain the correct expected value. as we don't detect overflow for other operation rather than add and sub
            case (Operation_ctrl)
                ADD: begin
                    expect_result   = a + b; 
                    expect_overflow = (a[W-1]==b[W-1]) && (expect_result[W-1]!=a[W-1]);
                     end 
                SUB: begin
                    expect_result   = a-b ; 
                    expect_overflow = (a[W-1]!=b[W-1]) && (expect_result[W-1]!=a[W-1]);

                     end
                AND_Op: expect_result = a & b;
                OR_Op:  expect_result = a | b;
                XOR_op: expect_result = a ^ b;
                SHIFT_LEFT_LOGICAl:      expect_result = a << expect_shift;
                SHIFT_RIGHT_LOGICAL:     expect_result = a >> expect_shift;
                SHIFT_RIGHT_ARITHEMATIC: expect_result = $signed(a) >>> expect_shift;
                SET_LESS_THAN:           expect_result = ($signed(a) < $signed(b)) ? 1 : 0;
                SET_LESS_THAN_UNsigned:  expect_result = (a < b) ? 1: 0;

                default: expect_result = ZEROS;
            endcase
         end
    endtask
    

    // model based checking
    task apply(input [W-1:0] ta, input [W-1:0] tb_in, input [3:0] ctrl); // its like apply(8'd10, 8'd5, ADD) these are local to task and receive values when the task is called
         begin
            // copying the task inputs to the alu inputs
            a = ta;
            b = tb_in;
            Operation_ctrl = ctrl;
            #1; // simulation delay of 1 unit of time... this is given for combinational logic of ALU to get settled after the task inputs are copied to its input
            model; // calling the task
            tests = tests + 1;
            if (result !== expect_result || zero_flag !== (expect_result == ZEROS) || overflow_flag !== expect_overflow) begin
                errors = errors + 1;
                $display("Failed Operation_ctrl=%0d a=%h b=%h : result=%h expected_result=%h zero_flag=%h overflow_flag=%h expect_overflow=%h", 
                          ctrl, ta, tb_in, result, expect_result, zero_flag, overflow_flag, expect_overflow);
            end
         end
    endtask

    // Direct checks of the spec's edge cases ---> model independent
    task expected_equals(input [255:0] name, input [W-1:0] got, input [W-1:0] expected); // unlike apply it doesnot calculate the expected results on its own, we have to provide it manually 
         begin
            tests= tests + 1;
            if(got !== expected) begin
                errors = errors + 1;
                $display("Failed %0s: got %h expected %h", name, got, expected);        
            end
         end
    endtask

    initial begin
        $dumpfile("tb_alu.vcd");
        $dumpvars(0, tb_alu);
        special[0] = ZEROS;
        special[1] = ONES;
        special[2] = MAX_P;
        special[3] = MIN_N;
        special[4] = 1;
        special[5] = ONES - 1;
        
        // -----Signed Overflow Test on ADD/SUB----- //
        // ADD
        a = MAX_P; 
        b = 1; 
        Operation_ctrl = ADD; 
        #1;
        expected_equals("ADD max+1 result", result, MIN_N);
        expected_equals("ADD max+1 overflow", {{(W-1){1'b0}}, overflow_flag}, 1);

        // SUB
        a = MIN_N; 
        b = 1; 
        Operation_ctrl = SUB; 
        #1;
        expected_equals("SUB min-1 result", result, MAX_P);
        expected_equals("SUB min-1 overflow", {{(W-1){1'b0}}, overflow_flag}, 1);

        //Checks nornaml addition where overflow should not occur
        a = 5; 
        b = 3; 
        Operation_ctrl = ADD; 
        #1;
        expected_equals("Normal Add overflow", {{(W-1){1'b0}}, overflow_flag}, 0);

        //Overflow must stay 0 for non arithematic operations
        a = MAX_P; 
        b = 1; 
        Operation_ctrl = AND_Op; 
        #1;
        expected_equals("AND no overflow", {{(W-1){1'b0}}, overflow_flag}, 0);
        Operation_ctrl = SET_LESS_THAN;
        #1
        expected_equals("SLT no overflow", {{(W-1){1'b0}}, overflow_flag}, 0);

    //------SET LESS THAN AND SET LESS THAN UNsigned must disagree with a negative Operand -----//
        a = ONES;
        b = 1;
        Operation_ctrl = SET_LESS_THAN;
        #1;
        expected_equals("SLT -1 < 1", result, 1);

        a = ONES;
        b = 1;
        Operation_ctrl = SET_LESS_THAN_UNsigned;
        #1;
        expected_equals("SLTU max < 1", result, 0);

        a = MIN_N;
        b = MAX_P;
        Operation_ctrl = SET_LESS_THAN;
        #1;
        expected_equals("SLT result under subtraction overflow",result, 1);
        expected_equals("SLT  min< max ", result, 1);

        a = MIN_N;
        b = MAX_P;
        Operation_ctrl = SET_LESS_THAN_UNsigned;
        #1;
        expected_equals("SLTU min<maX ", result, 0);


        // -----Shift Boundaries and shift amount masking----- //
        a = ONES; //11111111 
        b = 0;    //00000000
        Operation_ctrl = SHIFT_LEFT_LOGICAl;  
        #1; 
        expected_equals("SLL by 0", result, ONES);

        a = ONES; //11111111 
        b = W-1;    //if W=8 then b=7
        Operation_ctrl = SHIFT_LEFT_LOGICAl;  
        #1; 
        expected_equals("SLL by W-1", result, MIN_N);

        a = MIN_N; // 10000000
        b = W-1;    
        Operation_ctrl = SHIFT_RIGHT_ARITHEMATIC; 
        #1; 
        expected_equals("SRA min by W-1", result, ONES);

        a = MIN_N; // 10000000
        b = W-1;    
        Operation_ctrl = SHIFT_RIGHT_LOGICAL; 
        #1; 
        expected_equals("SRL min by W-1", result, 1);

        // Shift Amount Masking
        a = 4; // 00000100
        b = {ONES[W-1:Shift_width], {Shift_width{1'b0}}} | 1;// upper bits of b are ignored and shift by 1 ---- ONES= 8'b11111111 if W=8 and Shift width = 3 ONES [7:3] = 5'b11111 this selectes the upper 5 bits {Shift_width{1'b0}} so this concatenated 3 zeroes 11111 + 000 = 11111000 doing bitwise or with 1 we get b = 11111001 so now the lower bits is 001 which is 1 and a will be shifted by 1
        Operation_ctrl = SHIFT_LEFT_LOGICAl;
        #1;
        expected_equals("shift amount used lower bits only", result, 8);


        //----Zero flag---//
        a=7;
        b=7;
        Operation_ctrl = SUB;
        #1
        expected_equals("Zero flag", {{(W-1){1'b0}}, zero_flag}, 1);

        //---unused opcodes--//
        for (k = 10; k < 16; k = k+1) begin    /// our ALU supports 0-9 opcodes ..this will test for 10-15 opcodes
             a = ONES;
             b = ONES;
             Operation_ctrl = k;
             #1
             expected_equals("unused opcode result", result, 0);
             expected_equals("unused opcode result", {{(W-1){1'b0}}, zero_flag}, 1);
        end

        //----All-Zero / All-Ones / Corner operands On every Operations---///
        for (k = 0; k < 16; k = k + 1)   /// we have 6 special values for W bit width --- 0 -1 127 -127 1 -2   we are testing k till 16 because control unit is 4 bit width 
            for (i = 0; i < 6; i = i + 1) begin    /// for every K code this loop runs for 6 times for 6 special values to be tested
                 ///apply(input_a, input_b, operation);
                apply(special[i], special[(i+1)%6], k);
                apply(special[i], special[i], k);
                apply(special[(i+3)%6], special[i], k); /// here we are applying different paring in array choosing three positions away with each first operand this gives us a different paring rather than just simple consecuitive paring
                /// %6 helps us being in the range of index of 0-5 and
                // we havr 16 operations 6 loop pr operation and 3 calls pr loop so we har 16*6*3 = 288 reference model based checks
            end 
        
        // -- Randome Vs reference model ---//
        for (i = 0; i < 40000 ; i = i + 1) begin
            apply($random, $random, $random);
            if (i % 5 == 0) begin /// execute at every 5th interations including iteration zero
                apply(special[$urandom % 6], $random, $urandom % 10);
            end  
        end

        $display("tb_alu W=%0d: %0d checks, %0d errors", W, tests, errors);
        if (errors == 0) begin
            $display("Pass tb_alu W=%0d:", W);
        end
        else $display("FAIL tb_alu W=%0d", W);
        $finish;
    end
endmodule
