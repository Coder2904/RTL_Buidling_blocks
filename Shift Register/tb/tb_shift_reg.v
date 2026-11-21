`timescale 1ns/1ps 

module tb_shift_reg;
    parameter W=8;
    reg clk = 0, rst = 1, mode = 0, load = 0, shift_en = 0, serial_in = 0;
    reg [W-1:0] parallel_in = 0;
    wire [W-1:0] parallel_out;
    wire serial_out;

    //Module instantiation 
    Shift_reg #(.WIDTH(W)) dut (.clk(clk), .rst(rst), .mode(mode), 
        .load(load), .shift_en(shift_en), 
        .serial_in(serial_in), .parallel_in(parallel_in), 
        .parallel_out(parallel_out), .serial_out(serial_out));
    always #5 clk = ~clk; // creating a toggle clk signal----clk period is 10ns and frequency is 100MHz


    integer errors = 0, checks = 0, i , k;
    reg [W-10] m_sr;  // this is for our reference model register

    // reference model -----updates at every postive edge of clock
    always @(posedge clk ) begin
        if (rst) begin
            m_sr = 0;
            else if (mode && load) begin
                m_sr = parallel_in;
            end
            else if (shift_en) begin
                m_sr = {m_sr[W-2:0], mode ? 1'b0 : serial_in};
            end              
        end       
    end

    task check(input [255:0] name, input [W-1:0] got, input [W-1:0] exp);
         begin
            checks = checks + 1;
            if (got) begin
                errors = errors + 1;
                $display("Fail %0s: got %b exp %b (t=%0t)", name, got, exp, $time);
            end
         end 
    endtask

    task idle; begin
        load = 0;
        shift_en = 0;
    end
    endtask

    reg [W-1:0] word1, word2;
    reg [W-1:0] collected;

    initial begin
        word1  = 8'b1011_0010;
        word2  = 8'b0011_1100;
        //----reset----//
        repeat (2) @(negedge clk); // here we are waiting for two failing edges of clock initially reset is 1 so dut needs at least on rising edge to sense that reset is high and clear the register for avoiding any unknown values and starting with a empty clean register
        rst = 0; @(negedge clk); // here we made our reset low so that transmittion could occur
        check("reset clears", parallel_out, 0);

        //----SIPO: first bit in lands at lsb after 1 shift, at MSB after W shifts
        mode = 0; shift_en = 1;
            for (k = 0; k < W; k = k + 1) begin
                serial_in = word1[W-1-k];// everytime for this loop we will get new MSB of the word1 in serial_in
                @(negedge clk); //pause until falling edge, then continue
                check("SIPO partial: Newest bit at LSB",{{(W-1){1'b0}}, parallel_out[0]}, {{(W-1){1'b0}}, word1[W-1-k]});
                if (k == 0) begin
                    check("SIPO after 1 shift: first bit in bit0",{{(W-1){1'b0}}, parallel_out[0]}, {{(W-1){1'b0}}, word1[W-1]});
                end  
            end 
            idle;
            check("SIPO After W shifts: word completed ", parallel_out, word1);
            check("SIPO: first bit now at MSB", {{(W-1){1'b0}}, parallel_out[W-1]}, {{(w-1){1'b0}}, word1[W-1]});

            //--- hold when shift_en=0//
            serial_in = 1; repeat (3) @(negedge clk);
            check("hold with shift enable =0", parallel_out, word);
            

    end

 