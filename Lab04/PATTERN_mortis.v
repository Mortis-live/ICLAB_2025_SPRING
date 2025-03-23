//############################################################################
//   _,.---._       _,.---._      
// 	,-.' - ,  `.   ,-.' - ,  `.    
//  /==/ ,    -  \ /==/ ,    -  \   
// |==| - .=.  ,  |==| - .=.  ,  |  
// |==|  : ;=:  - |==|  : ;=:  - |  
// |==|,  '='  ,  |==|,  '='  ,  |  
//  \==\ _   -    ;\==\ _   -    ;  
// 	'.='.  ,  ; -\ '.='.  ,  ; -\  
// 		`--`--'' `--`  `--`--'' `--` 
//############################################################################

//############################################################################
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//   (C) Copyright Laboratory System Integration and Silicon Implementation
//   All Right Reserved
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   ICLAB 2023 Fall
//   Lab04 Exercise		: Two Head Attention
//   Author     		: Yu-Chi Lin (a6121461214.st12@nycu.edu.tw)
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   File Name   : ATTN.v
//   Module Name : ATTN
//   Release version : V1.0 (Release Date: 2025-3)
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################

`define CYCLE_TIME 50.0
`define SEED_NUMBER 280
`define PATTERN_NUMBER 1000

module PATTERN (
    //Output Port
    clk,
    rst_n,

    in_valid,
    in_str,
    q_weight,
    k_weight,
    v_weight,
    out_weight,

    //Input Port
    out_valid,
    out
);

  //---------------------------------------------------------------------
  //   PORT DECLARATION          
  //---------------------------------------------------------------------
  output logic clk, rst_n, in_valid;
  output logic [31:0] in_str;
  output logic [31:0] q_weight;
  output logic [31:0] k_weight;
  output logic [31:0] v_weight;
  output logic [31:0] out_weight;

  input out_valid;
  input [31:0] out;

  //---------------------------------------------------------------------
  //   PARAMETER & INTEGER DECLARATION
  //---------------------------------------------------------------------
  real CYCLE = `CYCLE_TIME;
  real PAT_NUM = `PATTERN_NUMBER;
  real MIN_RANGE_OF_INPUT = -0.5;
  real MAX_RANGE_OF_INPUT = 0.5;
  parameter PRECISION_OF_RANDOM_EXPONENT = -5; // 2^(PRECISION_OF_RANDOM_EXPONENT) ~ the exponent of MAX_RANGE_OF_INPUT
  parameter SEED = `SEED_NUMBER;
  parameter real_sig_width = 52;  // verilog real (double)
  parameter real_exp_width = 11;  // verilog real (double)


  parameter inst_sig_width = 23;
  parameter inst_exp_width = 8;
  parameter inst_ieee_compliance = 0;
  parameter inst_arch_type = 0;
  parameter inst_arch = 0;


  parameter WEIGHT_COL = 4;
  parameter WEIGHT_ROW = 4;
  parameter IN_STR_COL = 4;
  parameter IN_STR_ROW = 5;


  reg [ 9*8:1] reset_color = "\033[1;0m";
  reg [10*8:1] txt_black_prefix = "\033[1;30m";
  reg [10*8:1] txt_red_prefix = "\033[1;31m";
  reg [10*8:1] txt_green_prefix = "\033[1;32m";
  reg [10*8:1] txt_yellow_prefix = "\033[1;33m";
  reg [10*8:1] txt_blue_prefix = "\033[1;34m";

  reg [10*8:1] bkg_black_prefix = "\033[40;1m";
  reg [10*8:1] bkg_red_prefix = "\033[41;1m";
  reg [10*8:1] bkg_green_prefix = "\033[42;1m";
  reg [10*8:1] bkg_yellow_prefix = "\033[43;1m";
  reg [10*8:1] bkg_blue_prefix = "\033[44;1m";
  reg [10*8:1] bkg_white_prefix = "\033[47;1m";

  parameter sqare_root_2 = 32'b00111111101101010000010011110011;

  integer i_pat, total_latency, latency;
  integer file;

  integer cnt_out;


  //---------------------------------------------------------------------
  //   Reg & Wires
  //---------------------------------------------------------------------
  reg [inst_sig_width+inst_exp_width:0]
      _k_weight[0:WEIGHT_ROW-1][0:WEIGHT_COL-1],
      _k_weight_transpose[0:WEIGHT_COL-1][0:WEIGHT_ROW-1],
      _q_weight[0:WEIGHT_ROW-1][0:WEIGHT_COL-1],
      _q_weight_transpose[0:WEIGHT_COL-1][0:WEIGHT_ROW-1],
      _v_weight[0:WEIGHT_ROW-1][0:WEIGHT_COL-1],
      _v_weight_transpose[0:WEIGHT_COL-1][0:WEIGHT_ROW-1],
      _out_weight[0:WEIGHT_ROW-1][0:WEIGHT_COL-1];

  reg [31:0] _out_weight_transpose[0:WEIGHT_COL-1][0:WEIGHT_ROW-1];

  reg [inst_sig_width+inst_exp_width:0] _in_str[IN_STR_ROW-1:0][IN_STR_COL-1:0];

  reg [31:0]
      _K[0:IN_STR_ROW-1][0:IN_STR_COL-1],
      _Q[0:IN_STR_ROW-1][0:IN_STR_COL-1],
      _V[0:IN_STR_ROW-1][0:IN_STR_COL-1];

  reg [31:0] _K_transpose[0:IN_STR_COL-1][0:IN_STR_ROW-1];

  reg [31:0]
      _score[0:1][0:IN_STR_ROW-1][0:IN_STR_ROW-1],
      _score_dim[0:1][0:IN_STR_ROW-1][0:IN_STR_ROW-1];

  reg [31:0]
      _exp_score[0:1][0:IN_STR_ROW-1][0:IN_STR_ROW-1],
      _softmax_score[0:1][0:IN_STR_ROW-1][0:IN_STR_ROW-1];


  reg [31:0] _softmax_sum[0:1][0:4];

  reg [31:0] _head_out[0:1][0:IN_STR_ROW-1][0:2-1];

  reg [31:0] _concat[0:IN_STR_ROW-1][0:IN_STR_COL-1];

  reg [31:0] _golden_ans[0:IN_STR_ROW-1][0:IN_STR_COL-1];

  reg [31:0] _out_buffer[0:IN_STR_ROW-1][0:IN_STR_COL-1];


  real err[0:19];

  reg [4*8:1] _line1 = "____";
  reg [4*8:1] _space1 = "    ";
  reg [9*8:1] _line2 = "_________";
  reg [9*8:1] _space2 = "         ";

  //================================================================
  // clock
  //================================================================

  always #(CYCLE / 2.0) clk = ~clk;
  initial clk = 0;

  //---------------------------------------------------------------------
  //   Pattern_Design
  //---------------------------------------------------------------------

  // Start Pattern
  initial begin
    rst_n = 1'b1;
    force clk = 0;
    reset_signal_task;
    total_latency = 0;
    #CYCLE;
    release clk;

    @(negedge clk);

    for (i_pat = 0; i_pat < PAT_NUM; i_pat = i_pat + 1) begin
      randomize_input;
      cal_ans_task;
      input_task;
      dump_input;
      dump_output;
      wait_out_valid_task;
      check_ans;
      $display("%0sPASS PATTERN NO.%4d, %0sCycles: %3d%0s", txt_blue_prefix, i_pat,
               txt_green_prefix, latency, reset_color);
    end
    YOU_PASS_TASK;
  end


  //---------------------------------------------------------------------

  task cal_ans_task;
    integer _i, _j, _k, _num;
    real temp_real;
    real tmp_real;
    real tmp_real1, tmp_real2;
    begin
      // Transpose
      for (_i = 0; _i < WEIGHT_ROW; _i = _i + 1) begin
        for (_j = 0; _j < WEIGHT_COL; _j = _j + 1) begin
          _k_weight_transpose[_j][_i] = _k_weight[_i][_j];
          _q_weight_transpose[_j][_i] = _q_weight[_i][_j];
          _v_weight_transpose[_j][_i] = _v_weight[_i][_j];
        end
      end

      // in_str * k_weight^T
      for (_i = 0; _i < IN_STR_ROW; _i = _i + 1) begin
        for (_j = 0; _j < WEIGHT_COL; _j = _j + 1) begin
          temp_real = 0;
          for (_k = 0; _k < IN_STR_COL; _k = _k + 1) begin
            temp_real = temp_real +
                $bitstoshortreal(_in_str[_i][_k]) * $bitstoshortreal(_k_weight_transpose[_k][_j]);
          end
          _K[_i][_j] = $shortrealtobits(temp_real);
        end
      end

      // in_str * q_weight^T
      for (_i = 0; _i < IN_STR_ROW; _i = _i + 1) begin
        for (_j = 0; _j < WEIGHT_COL; _j = _j + 1) begin
          temp_real = 0;
          for (_k = 0; _k < IN_STR_COL; _k = _k + 1) begin
            temp_real = temp_real +
                $bitstoshortreal(_in_str[_i][_k]) * $bitstoshortreal(_q_weight_transpose[_k][_j]);
          end
          _Q[_i][_j] = $shortrealtobits(temp_real);
        end
      end

      // in_str * v_weight^T
      for (_i = 0; _i < IN_STR_ROW; _i = _i + 1) begin
        for (_j = 0; _j < WEIGHT_COL; _j = _j + 1) begin
          temp_real = 0;
          for (_k = 0; _k < IN_STR_COL; _k = _k + 1) begin
            temp_real = temp_real +
                $bitstoshortreal(_in_str[_i][_k]) * $bitstoshortreal(_v_weight_transpose[_k][_j]);
          end
          _V[_i][_j] = $shortrealtobits(temp_real);
        end
      end

      // _k^T
      for (_i = 0; _i < IN_STR_COL; _i = _i + 1) begin
        for (_j = 0; _j < IN_STR_ROW; _j = _j + 1) begin
          _K_transpose[_i][_j] = _K[_j][_i];
        end
      end

      // Q_head * K_head^T
      for (_num = 0; _num < 2; _num = _num + 1) begin
        for (_i = 0; _i < IN_STR_ROW; _i = _i + 1) begin
          for (_j = 0; _j < IN_STR_ROW; _j = _j + 1) begin
            temp_real = 0;
            for (_k = _num * 2; _k < (_num + 1) * 2; _k = _k + 1) begin
              temp_real = temp_real +
                  $bitstoshortreal(_Q[_i][_k]) * $bitstoshortreal(_K_transpose[_k][_j]);
            end
            _score[_num][_i][_j] = $shortrealtobits(temp_real);
          end
        end
      end


      // / sqrt(head_dim)
      for (_num = 1; _num <= 2; _num = _num + 1) begin
        for (_i = 0; _i < IN_STR_ROW; _i = _i + 1) begin
          for (_j = 0; _j < IN_STR_ROW; _j = _j + 1) begin
            temp_real = $bitstoshortreal(_score[_num-1][_i][_j]) / $bitstoshortreal(sqare_root_2);
            _score_dim[_num-1][_i][_j] = $shortrealtobits(temp_real);
          end
        end
      end

      // Softmax
      // Step 6-1: Softmax (expedential step)
      for (_num = 0; _num < 2; _num = _num + 1) begin
        for (_i = 0; _i < IN_STR_ROW; _i = _i + 1) begin
          for (_j = 0; _j < IN_STR_ROW; _j = _j + 1) begin
            _exp_score[_num][_i][_j] =
                $shortrealtobits($exp($bitstoshortreal(_score_dim[_num][_i][_j])));
          end
        end
      end
      // Step 6-2: Softmax (sum and division step for each row)
      for (_num = 0; _num < 2; _num = _num + 1) begin
        for (_i = 0; _i < IN_STR_ROW; _i = _i + 1) begin
          tmp_real = 0;
          for (_j = 0; _j < IN_STR_ROW; _j = _j + 1) begin
            tmp_real = tmp_real + $bitstoshortreal(_exp_score[_num][_i][_j]);
          end
          _softmax_sum[_num][_i] = $shortrealtobits(tmp_real);
          for (_j = 0; _j < IN_STR_ROW; _j = _j + 1) begin
            _softmax_score[_num][_i][_j] =
                $shortrealtobits($bitstoshortreal(_exp_score[_num][_i][_j]) / tmp_real);
          end
        end
      end

      // softmax_score * V for each head 0
      for (_i = 0; _i < IN_STR_ROW; _i = _i + 1) begin
        for (_j = 0; _j < 2; _j = _j + 1) begin
          temp_real = 0;
          for (_k = 0; _k < IN_STR_ROW; _k = _k + 1) begin
            temp_real = temp_real +
                $bitstoshortreal(_softmax_score[0][_i][_k]) * $bitstoshortreal(_V[_k][_j]);
          end
          _head_out[0][_i][_j] = $shortrealtobits(temp_real);
        end
      end

      // softmax_score * V for each head 1
      for (_i = 0; _i < IN_STR_ROW; _i = _i + 1) begin
        for (_j = 2; _j < 4; _j = _j + 1) begin
          temp_real = 0;
          for (_k = 0; _k < IN_STR_ROW; _k = _k + 1) begin
            temp_real = temp_real +
                $bitstoshortreal(_softmax_score[1][_i][_k]) * $bitstoshortreal(_V[_k][_j]);
          end
          _head_out[1][_i][_j-2] = $shortrealtobits(temp_real);
        end
      end

      // concat head 0 and head 1
      for (_i = 0; _i < IN_STR_ROW; _i = _i + 1) begin
        for (_j = 0; _j < 2; _j = _j + 1) begin
          _concat[_i][_j] = _head_out[0][_i][_j];
        end
      end

      for (_i = 0; _i < IN_STR_ROW; _i = _i + 1) begin
        for (_j = 2; _j < 4; _j = _j + 1) begin
          _concat[_i][_j] = _head_out[1][_i][_j-2];
        end
      end

      // out_weight_transpose
      for (_i = 0; _i < WEIGHT_COL; _i = _i + 1) begin
        for (_j = 0; _j < WEIGHT_ROW; _j = _j + 1) begin
          _out_weight_transpose[_i][_j] = _out_weight[_j][_i];
        end
      end

      // concat * out_weight^T
      for (_i = 0; _i < IN_STR_ROW; _i = _i + 1) begin
        for (_j = 0; _j < WEIGHT_COL; _j = _j + 1) begin
          temp_real = 0;
          for (_k = 0; _k < IN_STR_COL; _k = _k + 1) begin
            temp_real = temp_real +
                $bitstoshortreal(_concat[_i][_k]) * $bitstoshortreal(_out_weight_transpose[_k][_j]);
          end
          _golden_ans[_i][_j] = $shortrealtobits(temp_real);
        end
      end

      // ############################################################################
    end
  endtask

  task check_ans;
    integer condition_met;
    integer _i;
    begin
      cnt_out = 0;
      while (cnt_out < 20) begin
        if (out_valid === 1) begin
          _out_buffer[cnt_out/WEIGHT_COL][cnt_out%WEIGHT_COL] = out;
          cnt_out = cnt_out + 1;
        end else begin
          $display("\033[31m");
          $display("***********************************************************************");
          $display("*  Error Code:                                                        *");
          $display("*  The out_valid should be high for 20 cycles. (current less then 20)   *");
          $display("***********************************************************************");
          $display("\033[0m");
          $finish;
        end
        // latency = latency + 1;
        @(negedge clk);
      end
    end

    if (out_valid === 1) begin
      $display("\033[31m");
      $display("***********************************************************************");
      $display("*  Error Code:                                                        *");
      $display("*  The out_valid should be high for 20 cycles. (current more than 20) *");
      $display("***********************************************************************");
      $display("\033[0m");
      $finish;
    end

    // calculate the error
    for (int i = 0; i < 20; i = i + 1) begin
      err[i] = $abs(
          $bitstoshortreal(
              _out_buffer[i/WEIGHT_COL][i%WEIGHT_COL]
          ) - $bitstoshortreal(
              _golden_ans[i/WEIGHT_COL][i%WEIGHT_COL]
          )
      );
    end
    // check the error is less than 10e-7
    condition_met = 0;  // initialize to false
    for (_i = 0; _i < 20; _i = _i + 1) begin
      if (err[_i] >= 10e-7) begin
        condition_met = 1;
      end
    end
    if (condition_met == 1) begin
      $display("%0s", txt_red_prefix);
      $display("***********************************************************************");
      $display("*  Error Code:                                                        *");
      $display("%0sFAIL PATTERN NO.%4d, %0sCycles: %3d", txt_blue_prefix, i_pat, txt_red_prefix,
               latency);
      $display("*  The output data is not correct (err > 10e-7)                       *");
      $display("***********************************************************************");
      $display("\033[0m");
      $finish;
    end
  endtask

  task wait_out_valid_task;
    begin
      latency = 0;
      while (out_valid !== 1'b1) begin
        latency = latency + 1;
        if (latency == 200) begin
          $display("\033[31m");
          $display("**************************************************");
          $display("                    SPEC-7 FAIL                   ");
          $display("The execution latency is limited in 2000 cycles.  ");
          $display("**************************************************");
          $display("\033[0m");
          $finish;
        end
        @(negedge clk);
      end
      total_latency = total_latency + latency;
    end
  endtask

  task input_task;
    integer _i;
    begin
      in_valid = 1'b0;

      repeat (({$random(SEED)} % 4)) @(negedge clk);
      for (_i = 0; _i < IN_STR_COL * IN_STR_ROW; _i = _i + 1) begin
        in_valid = 1'b1;
        if (_i < WEIGHT_COL * WEIGHT_ROW) begin
          k_weight   = _k_weight[_i/WEIGHT_COL][_i%WEIGHT_COL];
          q_weight   = _q_weight[_i/WEIGHT_COL][_i%WEIGHT_COL];
          v_weight   = _v_weight[_i/WEIGHT_COL][_i%WEIGHT_COL];
          out_weight = _out_weight[_i/WEIGHT_COL][_i%WEIGHT_COL];
        end else begin
          k_weight   = 32'bx;
          q_weight   = 32'bx;
          v_weight   = 32'bx;
          out_weight = 32'bx;
        end
        in_str = _in_str[_i/IN_STR_COL][_i%IN_STR_COL];
        @(negedge clk);
      end
      in_valid = 1'b0;
      k_weight = 32'bx;
      q_weight = 32'bx;
      v_weight = 32'bx;
      out_weight = 32'bx;
      in_str = 32'bx;
    end
  endtask


  task dump_input;
    integer input_idx;
    integer num_idx;
    integer row_idx;
    integer col_idx;
    begin
      file = $fopen("../00_TESTBED/input_float.txt", "w");
      $fwrite(file, "[PAT NO. %4d]\n\n\n", i_pat);
      fwrite_new_line(file);
      $fwrite(file, "[========]\n");
      $fwrite(file, "[ In_str ]\n");
      $fwrite(file, "[========]\n\n");
      $fwrite(file, "[W] ");
      for (col_idx = 0; col_idx < WEIGHT_COL; col_idx = col_idx + 1) $fwrite(file, "%8d ", col_idx);
      $fwrite(file, "%0s", _space1);
      fwrite_new_line(file);
      // _________________
      $fwrite(file, "%0s", _line1);
      for (col_idx = 0; col_idx < WEIGHT_COL; col_idx = col_idx + 1) $fwrite(file, "%0s", _line2);
      $fwrite(file, "%0s", _space1);
      fwrite_new_line(file);
      //   0| **1 **2 **3
      for (row_idx = 0; row_idx < IN_STR_ROW; row_idx = row_idx + 1) begin
        $fwrite(file, "%2d| ", row_idx);
        for (col_idx = 0; col_idx < WEIGHT_COL; col_idx = col_idx + 1) begin
          $fwrite(file, "%8.3f ", $bitstoshortreal(_in_str[row_idx][col_idx]));
        end
        $fwrite(file, "%0s", _space1);
        fwrite_new_line(file);
      end
      fwrite_new_line(file);
      fwrite_new_line(file);

      fwrite_new_line(file);
      $fwrite(file, "[==========]\n");
      $fwrite(file, "[ K_Weight ]\n");
      $fwrite(file, "[==========]\n\n");
      // [#0] **1 **2 **3
      $fwrite(file, "[W] ");
      for (col_idx = 0; col_idx < WEIGHT_COL; col_idx = col_idx + 1) $fwrite(file, "%8d ", col_idx);
      $fwrite(file, "%0s", _space1);
      fwrite_new_line(file);
      // _________________
      $fwrite(file, "%0s", _line1);
      for (col_idx = 0; col_idx < WEIGHT_COL; col_idx = col_idx + 1) $fwrite(file, "%0s", _line2);
      $fwrite(file, "%0s", _space1);
      fwrite_new_line(file);
      //   0| **1 **2 **3
      for (row_idx = 0; row_idx < WEIGHT_ROW; row_idx = row_idx + 1) begin
        $fwrite(file, "%2d| ", row_idx);
        for (col_idx = 0; col_idx < WEIGHT_COL; col_idx = col_idx + 1) begin
          $fwrite(file, "%8.3f ", $bitstoshortreal(_k_weight[row_idx][col_idx]));
        end
        $fwrite(file, "%0s", _space1);
        fwrite_new_line(file);
      end
      fwrite_new_line(file);

      fwrite_new_line(file);
      $fwrite(file, "[==========]\n");
      $fwrite(file, "[ Q_Weight ]\n");
      $fwrite(file, "[==========]\n\n");
      // [#0] **1 **2 **3
      $fwrite(file, "[W] ");
      for (col_idx = 0; col_idx < WEIGHT_COL; col_idx = col_idx + 1) $fwrite(file, "%8d ", col_idx);
      $fwrite(file, "%0s", _space1);
      fwrite_new_line(file);
      // _________________
      $fwrite(file, "%0s", _line1);
      for (col_idx = 0; col_idx < WEIGHT_COL; col_idx = col_idx + 1) $fwrite(file, "%0s", _line2);
      $fwrite(file, "%0s", _space1);
      fwrite_new_line(file);
      //   0| **1 **2 **3
      for (row_idx = 0; row_idx < WEIGHT_ROW; row_idx = row_idx + 1) begin
        $fwrite(file, "%2d| ", row_idx);
        for (col_idx = 0; col_idx < WEIGHT_COL; col_idx = col_idx + 1) begin
          $fwrite(file, "%8.3f ", $bitstoshortreal(_q_weight[row_idx][col_idx]));
        end
        $fwrite(file, "%0s", _space1);
        fwrite_new_line(file);
      end
      fwrite_new_line(file);

      fwrite_new_line(file);
      $fwrite(file, "[==========]\n");
      $fwrite(file, "[ V_Weight ]\n");
      $fwrite(file, "[==========]\n\n");
      // [#0] **1 **2 **3
      $fwrite(file, "[W] ");
      for (col_idx = 0; col_idx < WEIGHT_COL; col_idx = col_idx + 1) $fwrite(file, "%8d ", col_idx);
      $fwrite(file, "%0s", _space1);
      fwrite_new_line(file);
      // _________________
      $fwrite(file, "%0s", _line1);
      for (col_idx = 0; col_idx < WEIGHT_COL; col_idx = col_idx + 1) $fwrite(file, "%0s", _line2);
      $fwrite(file, "%0s", _space1);
      fwrite_new_line(file);
      //   0| **1 **2 **3
      for (row_idx = 0; row_idx < WEIGHT_ROW; row_idx = row_idx + 1) begin
        $fwrite(file, "%2d| ", row_idx);
        for (col_idx = 0; col_idx < WEIGHT_COL; col_idx = col_idx + 1) begin
          $fwrite(file, "%8.3f ", $bitstoshortreal(_v_weight[row_idx][col_idx]));
        end
        $fwrite(file, "%0s", _space1);
        fwrite_new_line(file);
      end
      fwrite_new_line(file);

      fwrite_new_line(file);
      $fwrite(file, "[============]\n");
      $fwrite(file, "[ OUT_Weight ]\n");
      $fwrite(file, "[============]\n\n");
      // [#0] **1 **2 **3
      $fwrite(file, "[W] ");
      for (col_idx = 0; col_idx < WEIGHT_COL; col_idx = col_idx + 1) $fwrite(file, "%8d ", col_idx);
      $fwrite(file, "%0s", _space1);
      fwrite_new_line(file);
      // _________________
      $fwrite(file, "%0s", _line1);
      for (col_idx = 0; col_idx < WEIGHT_COL; col_idx = col_idx + 1) $fwrite(file, "%0s", _line2);
      $fwrite(file, "%0s", _space1);
      fwrite_new_line(file);
      //   0| **1 **2 **3
      for (row_idx = 0; row_idx < WEIGHT_ROW; row_idx = row_idx + 1) begin
        $fwrite(file, "%2d| ", row_idx);
        for (col_idx = 0; col_idx < WEIGHT_COL; col_idx = col_idx + 1) begin
          $fwrite(file, "%8.3f ", $bitstoshortreal(_out_weight[row_idx][col_idx]));
        end
        $fwrite(file, "%0s", _space1);
        fwrite_new_line(file);
      end
      fwrite_new_line(file);
      $fclose(file);
    end
  endtask


  task dump_output;
    integer file;
    integer input_idx;
    integer ch_idx;
    integer num_idx;
    integer col_idx;
    integer row_idx;
    begin
      file = $fopen("../00_TESTBED/output_float.txt", "w");
      $fwrite(file, "[PAT NO. %4d]\n\n\n", i_pat);

      $fwrite(file, "[==============]\n");
      $fwrite(file, "[ KQV_Weight^T ]\n");
      $fwrite(file, "[==============]\n\n");

      // Print column indices
      $fwrite(file, "[K] ");
      for (col_idx = 0; col_idx < WEIGHT_COL; col_idx = col_idx + 1) $fwrite(file, "%8d ", col_idx);
      $fwrite(file, "[Q] ");
      for (col_idx = 0; col_idx < WEIGHT_COL; col_idx = col_idx + 1) $fwrite(file, "%8d ", col_idx);
      $fwrite(file, "[V] ");
      for (col_idx = 0; col_idx < WEIGHT_COL; col_idx = col_idx + 1) $fwrite(file, "%8d ", col_idx);
      $fwrite(file, "%0s", _space1);
      fwrite_new_line(file);

      // Print separator line
      for (num_idx = 0; num_idx < 3; num_idx = num_idx + 1) begin
        $fwrite(file, "%0s", _line1);
        for (col_idx = 0; col_idx < WEIGHT_COL; col_idx = col_idx + 1) $fwrite(file, "%0s", _line2);
      end


      $fwrite(file, "%0s", _space1);
      fwrite_new_line(file);

      // Print K_Weight, Q_Weight, and V_Weight in the same row
      for (row_idx = 0; row_idx < WEIGHT_ROW; row_idx = row_idx + 1) begin
        // Print row index
        $fwrite(file, "%2d| ", row_idx);

        // Print K_Weight values
        for (col_idx = 0; col_idx < WEIGHT_COL; col_idx = col_idx + 1) begin
          $fwrite(file, "%8.3f ", $bitstoshortreal(_k_weight_transpose[row_idx][col_idx]));
        end

        $fwrite(file, "%2d| ", row_idx);

        // Print Q_Weight values (same row as K_Weight)
        for (col_idx = 0; col_idx < WEIGHT_COL; col_idx = col_idx + 1) begin
          $fwrite(file, "%8.3f ", $bitstoshortreal(_q_weight_transpose[row_idx][col_idx]));
        end

        $fwrite(file, "%2d| ", row_idx);

        // Print V_Weight values (same row as K_Weight and Q_Weight)
        for (col_idx = 0; col_idx < WEIGHT_COL; col_idx = col_idx + 1) begin
          $fwrite(file, "%8.3f ", $bitstoshortreal(_v_weight_transpose[row_idx][col_idx]));
        end

        // Print space at the end of the line
        $fwrite(file, "%0s", _space1);
        fwrite_new_line(file);
      end


      fwrite_new_line(file);
      $fwrite(file, "[=====]\n");
      $fwrite(file, "[ KQV ]\n");
      $fwrite(file, "[=====]\n\n");

      // Print column indices
      $fwrite(file, "[K] ");
      for (col_idx = 0; col_idx < WEIGHT_COL; col_idx = col_idx + 1) $fwrite(file, "%8d ", col_idx);
      $fwrite(file, "[Q] ");
      for (col_idx = 0; col_idx < WEIGHT_COL; col_idx = col_idx + 1) $fwrite(file, "%8d ", col_idx);
      $fwrite(file, "[V] ");
      for (col_idx = 0; col_idx < WEIGHT_COL; col_idx = col_idx + 1) $fwrite(file, "%8d ", col_idx);
      $fwrite(file, "%0s", _space1);
      fwrite_new_line(file);

      // Print separator line
      for (num_idx = 0; num_idx < 3; num_idx = num_idx + 1) begin
        $fwrite(file, "%0s", _line1);
        for (col_idx = 0; col_idx < WEIGHT_COL; col_idx = col_idx + 1) $fwrite(file, "%0s", _line2);
      end


      $fwrite(file, "%0s", _space1);
      fwrite_new_line(file);

      // Print K_Weight, Q_Weight, and V_Weight in the same row
      for (row_idx = 0; row_idx < IN_STR_ROW; row_idx = row_idx + 1) begin
        // Print row index
        $fwrite(file, "%2d| ", row_idx);

        // Print K_Weight values
        for (col_idx = 0; col_idx < WEIGHT_COL; col_idx = col_idx + 1) begin
          $fwrite(file, "%8.3f ", $bitstoshortreal(_K[row_idx][col_idx]));
        end

        $fwrite(file, "%2d| ", row_idx);

        // Print Q_Weight values (same row as K_Weight)
        for (col_idx = 0; col_idx < WEIGHT_COL; col_idx = col_idx + 1) begin
          $fwrite(file, "%8.3f ", $bitstoshortreal(_Q[row_idx][col_idx]));
        end

        $fwrite(file, "%2d| ", row_idx);

        // Print V_Weight values (same row as K_Weight and Q_Weight)
        for (col_idx = 0; col_idx < WEIGHT_COL; col_idx = col_idx + 1) begin
          $fwrite(file, "%8.3f ", $bitstoshortreal(_V[row_idx][col_idx]));
        end

        // Print space at the end of the line
        $fwrite(file, "%0s", _space1);
        fwrite_new_line(file);
      end

      fwrite_new_line(file);
      $fwrite(file, "[=====]\n");
      $fwrite(file, "[ K^T ]\n");
      $fwrite(file, "[=====]\n\n");

      // Print column indices
      $fwrite(file, "[K] ");
      for (col_idx = 0; col_idx < IN_STR_ROW; col_idx = col_idx + 1) $fwrite(file, "%8d ", col_idx);
      fwrite_new_line(file);

      // Print separator line
      $fwrite(file, "%0s", _line1);
      for (col_idx = 0; col_idx < IN_STR_ROW; col_idx = col_idx + 1) $fwrite(file, "%0s", _line2);


      $fwrite(file, "%0s", _space1);
      fwrite_new_line(file);

      // Print K_Weight, Q_Weight, and V_Weight in the same row
      for (row_idx = 0; row_idx < IN_STR_COL; row_idx = row_idx + 1) begin
        // Print row index
        $fwrite(file, "%2d| ", row_idx);

        // Print K_Weight values
        for (col_idx = 0; col_idx < IN_STR_ROW; col_idx = col_idx + 1) begin
          $fwrite(file, "%8.3f ", $bitstoshortreal(_K_transpose[row_idx][col_idx]));
        end

        // Print space at the end of the line
        $fwrite(file, "%0s", _space1);
        fwrite_new_line(file);
      end

      // Print a new line after the data for neatness
      fwrite_new_line(file);

      fwrite_new_line(file);
      $fwrite(file, "[=======]\n");
      $fwrite(file, "[ SCORE ]\n");
      $fwrite(file, "[=======]\n\n");

      // Print column indices
      $fwrite(file, "[1] ");
      for (col_idx = 0; col_idx < IN_STR_ROW; col_idx = col_idx + 1) $fwrite(file, "%8d ", col_idx);
      $fwrite(file, "[2] ");
      for (col_idx = 0; col_idx < IN_STR_ROW; col_idx = col_idx + 1) $fwrite(file, "%8d ", col_idx);

      // Print separator line
      for (num_idx = 0; num_idx < 2; num_idx = num_idx + 1) begin
        $fwrite(file, "%0s", _line1);
        for (col_idx = 0; col_idx < IN_STR_ROW; col_idx = col_idx + 1) $fwrite(file, "%0s", _line2);
      end


      $fwrite(file, "%0s", _space1);
      fwrite_new_line(file);

      // Print K_Weight, Q_Weight, and V_Weight in the same row
      for (row_idx = 0; row_idx < IN_STR_ROW; row_idx = row_idx + 1) begin
        // Print row index
        $fwrite(file, "%2d| ", row_idx);

        // Print K_Weight values
        for (col_idx = 0; col_idx < IN_STR_ROW; col_idx = col_idx + 1) begin
          $fwrite(file, "%8.3f ", $bitstoshortreal(_score[0][row_idx][col_idx]));
        end

        $fwrite(file, "%2d| ", row_idx);

        // Print Q_Weight values (same row as K_Weight)
        for (col_idx = 0; col_idx < IN_STR_ROW; col_idx = col_idx + 1) begin
          $fwrite(file, "%8.3f ", $bitstoshortreal(_score[1][row_idx][col_idx]));
        end

        // Print space at the end of the line
        $fwrite(file, "%0s", _space1);
        fwrite_new_line(file);
      end

      // Print a new line after the data for neatness
      fwrite_new_line(file);

      fwrite_new_line(file);
      $fwrite(file, "[===============]\n");
      $fwrite(file, "[ SCORE/sqrt(2) ]\n");
      $fwrite(file, "[===============]\n\n");

      // Print column indices
      $fwrite(file, "[1] ");
      for (col_idx = 0; col_idx < IN_STR_ROW; col_idx = col_idx + 1) $fwrite(file, "%8d ", col_idx);
      $fwrite(file, "[2] ");
      for (col_idx = 0; col_idx < IN_STR_ROW; col_idx = col_idx + 1) $fwrite(file, "%8d ", col_idx);

      // Print separator line
      for (num_idx = 0; num_idx < 2; num_idx = num_idx + 1) begin
        $fwrite(file, "%0s", _line1);
        for (col_idx = 0; col_idx < IN_STR_ROW; col_idx = col_idx + 1) $fwrite(file, "%0s", _line2);
      end


      $fwrite(file, "%0s", _space1);
      fwrite_new_line(file);

      // Print K_Weight, Q_Weight, and V_Weight in the same row
      for (row_idx = 0; row_idx < IN_STR_ROW; row_idx = row_idx + 1) begin
        // Print row index
        $fwrite(file, "%2d| ", row_idx);

        // Print K_Weight values
        for (col_idx = 0; col_idx < IN_STR_ROW; col_idx = col_idx + 1) begin
          $fwrite(file, "%8.3f ", $bitstoshortreal(_score_dim[0][row_idx][col_idx]));
        end

        $fwrite(file, "%2d| ", row_idx);

        // Print Q_Weight values (same row as K_Weight)
        for (col_idx = 0; col_idx < IN_STR_ROW; col_idx = col_idx + 1) begin
          $fwrite(file, "%8.3f ", $bitstoshortreal(_score_dim[1][row_idx][col_idx]));
        end

        // Print space at the end of the line
        $fwrite(file, "%0s", _space1);
        fwrite_new_line(file);
      end

      // Print a new line after the data for neatness
      fwrite_new_line(file);


      fwrite_new_line(file);
      $fwrite(file, "[===============]\n");
      $fwrite(file, "[ SCORE_EXPONEN ]\n");
      $fwrite(file, "[===============]\n\n");

      // Print column indices
      $fwrite(file, "[1] ");
      for (col_idx = 0; col_idx < IN_STR_ROW; col_idx = col_idx + 1) $fwrite(file, "%8d ", col_idx);
      $fwrite(file, "[2] ");
      for (col_idx = 0; col_idx < IN_STR_ROW; col_idx = col_idx + 1) $fwrite(file, "%8d ", col_idx);

      // Print separator line
      for (num_idx = 0; num_idx < 2; num_idx = num_idx + 1) begin
        $fwrite(file, "%0s", _line1);
        for (col_idx = 0; col_idx < IN_STR_ROW; col_idx = col_idx + 1) $fwrite(file, "%0s", _line2);
      end


      $fwrite(file, "%0s", _space1);
      fwrite_new_line(file);

      // Print K_Weight, Q_Weight, and V_Weight in the same row
      for (row_idx = 0; row_idx < IN_STR_ROW; row_idx = row_idx + 1) begin
        // Print row index
        $fwrite(file, "%2d| ", row_idx);

        // Print K_Weight values
        for (col_idx = 0; col_idx < IN_STR_ROW; col_idx = col_idx + 1) begin
          $fwrite(file, "%8.3f ", $bitstoshortreal(_exp_score[0][row_idx][col_idx]));
        end

        $fwrite(file, "%2d| ", row_idx);

        // Print Q_Weight values (same row as K_Weight)
        for (col_idx = 0; col_idx < IN_STR_ROW; col_idx = col_idx + 1) begin
          $fwrite(file, "%8.3f ", $bitstoshortreal(_exp_score[1][row_idx][col_idx]));
        end

        // Print space at the end of the line
        $fwrite(file, "%0s", _space1);
        fwrite_new_line(file);
      end

      // Print a new line after the data for neatness
      fwrite_new_line(file);

      $fwrite(file, "[=============]\n");
      $fwrite(file, "[ SOFTMAX_SUM ]\n");
      $fwrite(file, "[=============]\n\n");

      // Print column indices
      $fwrite(file, "[1] ");
      for (col_idx = 0; col_idx < 1; col_idx = col_idx + 1) $fwrite(file, "%8d ", col_idx);
      $fwrite(file, "[2] ");
      for (col_idx = 0; col_idx < 1; col_idx = col_idx + 1) $fwrite(file, "%8d ", col_idx);

      fwrite_new_line(file);
      // Print separator line
      $fwrite(file, "%0s", _line1);
      for (col_idx = 0; col_idx < 1; col_idx = col_idx + 1) $fwrite(file, "%0s", _line2);
      $fwrite(file, "%0s", _line1);
      for (col_idx = 0; col_idx < 1; col_idx = col_idx + 1) $fwrite(file, "%0s", _line2);


      $fwrite(file, "%0s", _space1);
      fwrite_new_line(file);

      // Print K_Weight, Q_Weight, and V_Weight in the same row
      for (row_idx = 0; row_idx < IN_STR_ROW; row_idx = row_idx + 1) begin
        // Print row index
        $fwrite(file, "%2d| ", row_idx);

        // Print K_Weight values
        for (col_idx = 0; col_idx < 1; col_idx = col_idx + 1) begin
          $fwrite(file, "%8.3f ", $bitstoshortreal(_softmax_sum[0][row_idx]));
        end

        $fwrite(file, "%2d| ", row_idx);

        // Print K_Weight values
        for (col_idx = 0; col_idx < 1; col_idx = col_idx + 1) begin
          $fwrite(file, "%8.3f ", $bitstoshortreal(_softmax_sum[1][row_idx]));
        end

        // Print space at the end of the line
        $fwrite(file, "%0s", _space1);
        fwrite_new_line(file);
      end

      // Print a new line after the data for neatness
      fwrite_new_line(file);

      fwrite_new_line(file);
      $fwrite(file, "[===============]\n");
      $fwrite(file, "[ SCORE_SOFTMAX ]\n");
      $fwrite(file, "[===============]\n\n");

      // Print column indices
      $fwrite(file, "[1] ");
      for (col_idx = 0; col_idx < IN_STR_ROW; col_idx = col_idx + 1) $fwrite(file, "%8d ", col_idx);
      $fwrite(file, "[2] ");
      for (col_idx = 0; col_idx < IN_STR_ROW; col_idx = col_idx + 1) $fwrite(file, "%8d ", col_idx);

      // Print separator line
      for (num_idx = 0; num_idx < 2; num_idx = num_idx + 1) begin
        $fwrite(file, "%0s", _line1);
        for (col_idx = 0; col_idx < IN_STR_ROW; col_idx = col_idx + 1) $fwrite(file, "%0s", _line2);
      end


      $fwrite(file, "%0s", _space1);
      fwrite_new_line(file);

      // Print K_Weight, Q_Weight, and V_Weight in the same row
      for (row_idx = 0; row_idx < IN_STR_ROW; row_idx = row_idx + 1) begin
        // Print row index
        $fwrite(file, "%2d| ", row_idx);

        // Print K_Weight values
        for (col_idx = 0; col_idx < IN_STR_ROW; col_idx = col_idx + 1) begin
          $fwrite(file, "%8.3f ", $bitstoshortreal(_softmax_score[0][row_idx][col_idx]));
        end

        $fwrite(file, "%2d| ", row_idx);

        // Print Q_Weight values (same row as K_Weight)
        for (col_idx = 0; col_idx < IN_STR_ROW; col_idx = col_idx + 1) begin
          $fwrite(file, "%8.3f ", $bitstoshortreal(_softmax_score[1][row_idx][col_idx]));
        end

        // Print space at the end of the line
        $fwrite(file, "%0s", _space1);
        fwrite_new_line(file);
      end
      fwrite_new_line(file);


      $fwrite(file, "[==========]\n");
      $fwrite(file, "[ H_concat ]\n");
      $fwrite(file, "[==========]\n\n");
      $fwrite(file, "[W] ");
      for (col_idx = 0; col_idx < WEIGHT_COL; col_idx = col_idx + 1) $fwrite(file, "%8d ", col_idx);
      $fwrite(file, "%0s", _space1);
      fwrite_new_line(file);
      // _________________
      $fwrite(file, "%0s", _line1);
      for (col_idx = 0; col_idx < WEIGHT_COL; col_idx = col_idx + 1) $fwrite(file, "%0s", _line2);
      $fwrite(file, "%0s", _space1);
      fwrite_new_line(file);
      //   0| **1 **2 **3
      for (row_idx = 0; row_idx < IN_STR_ROW; row_idx = row_idx + 1) begin
        $fwrite(file, "%2d| ", row_idx);
        for (col_idx = 0; col_idx < WEIGHT_COL; col_idx = col_idx + 1) begin
          $fwrite(file, "%8.3f ", $bitstoshortreal(_concat[row_idx][col_idx]));
        end
        $fwrite(file, "%0s", _space1);
        fwrite_new_line(file);
      end
      // Print a new line after the data for neatness
      fwrite_new_line(file);

      fwrite_new_line(file);
      $fwrite(file, "[==============]\n");
      $fwrite(file, "[ out_weight^T ]\n");
      $fwrite(file, "[==============]\n\n");

      // Print column indices
      $fwrite(file, "[O] ");
      for (col_idx = 0; col_idx < IN_STR_COL; col_idx = col_idx + 1) $fwrite(file, "%8d ", col_idx);
      fwrite_new_line(file);

      // Print separator line
      $fwrite(file, "%0s", _line1);
      for (col_idx = 0; col_idx < IN_STR_COL; col_idx = col_idx + 1) $fwrite(file, "%0s", _line2);


      $fwrite(file, "%0s", _space1);
      fwrite_new_line(file);

      // Print K_Weight, Q_Weight, and V_Weight in the same row
      for (row_idx = 0; row_idx < IN_STR_COL; row_idx = row_idx + 1) begin
        // Print row index
        $fwrite(file, "%2d| ", row_idx);

        // Print K_Weight values
        for (col_idx = 0; col_idx < IN_STR_COL; col_idx = col_idx + 1) begin
          $fwrite(file, "%8.3f ", $bitstoshortreal(_out_weight_transpose[row_idx][col_idx]));
        end

        // Print space at the end of the line
        $fwrite(file, "%0s", _space1);
        fwrite_new_line(file);
      end


      fwrite_new_line(file);

      $fwrite(file, "[===========]\n");
      $fwrite(file, "[ FINAL_ANS ]\n");
      $fwrite(file, "[===========]\n\n");
      $fwrite(file, "[W] ");
      for (col_idx = 0; col_idx < WEIGHT_COL; col_idx = col_idx + 1) $fwrite(file, "%8d ", col_idx);
      $fwrite(file, "%0s", _space1);
      fwrite_new_line(file);
      // _________________
      $fwrite(file, "%0s", _line1);
      for (col_idx = 0; col_idx < WEIGHT_COL; col_idx = col_idx + 1) $fwrite(file, "%0s", _line2);
      $fwrite(file, "%0s", _space1);
      fwrite_new_line(file);
      //   0| **1 **2 **3
      for (row_idx = 0; row_idx < IN_STR_ROW; row_idx = row_idx + 1) begin
        $fwrite(file, "%2d| ", row_idx);
        for (col_idx = 0; col_idx < WEIGHT_COL; col_idx = col_idx + 1) begin
          $fwrite(file, "%8.3f ", $bitstoshortreal(_golden_ans[row_idx][col_idx]));
        end
        $fwrite(file, "%0s", _space1);
        fwrite_new_line(file);
      end
      fwrite_new_line(file);
      $fclose(file);
    end
  endtask

  task randomize_input;
    integer _row;
    integer _col;
    begin
      // In_str
      for (_row = 0; _row < IN_STR_ROW; _row = _row + 1) begin
        for (_col = 0; _col < IN_STR_COL; _col = _col + 1) begin
          _in_str[_row][_col] = _getRandInput(i_pat);
        end
      end
      // Wieght
      for (_row = 0; _row < WEIGHT_ROW; _row = _row + 1) begin
        for (_col = 0; _col < WEIGHT_COL; _col = _col + 1) begin
          _k_weight[_row][_col]   = _getRandInput(i_pat);
          _q_weight[_row][_col]   = _getRandInput(i_pat);
          _v_weight[_row][_col]   = _getRandInput(i_pat);
          _out_weight[_row][_col] = _getRandInput(i_pat);
        end
      end
    end
  endtask


  function [inst_sig_width+inst_exp_width:0] _getRandInput;
    input integer i_pat;
    reg [inst_sig_width+inst_exp_width:0] _minFloatBits;
    reg [inst_sig_width+inst_exp_width:0] _maxFloatBits;
    real _range;
    reg [inst_sig_width+inst_exp_width:0] _rangeFloatBits;
    real _randOut;
    integer int_range;  // Integer for the range as an integer
    real _fracRandomPart;  // Fractional random part

    begin
      _getRandInput = 0;

      if (i_pat < PAT_NUM) begin
        // For pattern less than PAT_NUM, use a different random pattern

        // random floating point (32bits)
        // using $shortrealtobits() to convert shortreal to 32bits IEEE754 format
        // the random value is between -0.5 ~ +0.5
        _randOut = $urandom() / (2.0 ** 32) - 0.5;  // Random float value between -0.5 and 0.5

        // Convert the random float value back to its floating-point bit representation
        _getRandInput = $shortrealtobits(_randOut);
      end
    end
  endfunction



  task reset_signal_task;
    begin
      #CYCLE;
      rst_n = 1'b1;
      #CYCLE;
      rst_n = 1'b0;

      // input
      in_valid = 1'b0;
      in_str = 32'bx;
      k_weight = 32'bx;
      q_weight = 32'bx;
      v_weight = 32'bx;
      #CYCLE;
      rst_n = 1'b1;

      // Check spec4
      if (out_valid !== 1'b0 || out !== 32'b0) begin
        $display("\033[31m");
        $display("**************************************************");
        $display("                    SPEC-4 FAIL                   ");
        $display("  All output signals should be 0 at the beginning ");
        $display("**************************************************");
        $display("\033[0m");
        $finish;
      end
    end
  endtask

  task fwrite_new_line;
    input integer file;
    begin
      $fwrite(file, "\n");
    end
  endtask


  //================================================================
  // global check
  //================================================================
  initial begin
    while (1) begin
      if ((out_valid === 0) && (out !== 0)) begin
        $display("\033[31m");
        $display("***********************************************************************");
        $display("*  Error Code:                                                        *");
        $display("*  The out        should be reset when out_valid is low.              *");
        $display("***********************************************************************");
        $display("\033[0m");
        $finish;
      end
      @(negedge clk);
    end
  end

  // Output signal out_valid and out_matrix should be zero when in_valid is high
  initial begin
    while (1) begin
      if ((in_valid === 1) && (out_valid !== 0)) begin
        $display("\033[31m");
        $display("***********************************************************************");
        $display("*  Error Code:                                                        *");
        $display("*  The out_valid should be reset when in_valid is high.               *");
        $display("***********************************************************************");
        $display("\033[0m");
        $finish;
      end
      @(negedge clk);
    end
  end

  // global check
  //================================================================


  task YOU_PASS_TASK;
    begin
      $display(
          "                               `-:/+++++++/:-`                                        ");
      $display(
          "                          ./shmNdddmmNNNMMMMMNNhs/.                                   ");
      $display(
          "                       `:yNMMMMMdo------:/+ymMMMMMNds-                                ");
      $display(
          "                     +dNMMNysmMMMd/....-ymNMMMMNMMMMMd+                             ");
      $display(
          "                    .+NMMNy:-.-oNMMm..../MMMNho:-+dMMMMMm+`                           ");
      $display(
          "      ``            +-oso/:::::/+so:....-:+++//////hNNm++dd-                          ");
      $display(
          "      +/-  -`      -:.-//--.....-:+-.....-+/--....--/+-..:Nm:                         ");
      $display(
          "  :--./-:::/.      /-.+:..-:+oso+:-+....-+:/oso+:....-+:..yMN:                        ");
      $display(
          "  -/:-:-.+-/      `+--+.-smNMMMMMNh/....:ymNMMMMNy:...-+../MMm.                       ");
      $display(
          " ::/+-...--/   --:-...-dMMMh/.-yMMd-..-mMMy::oNMMm:...-..-mMMy.                     ");
      $display(
          " .-:+:.....---::-......+MMMM-  sMMN-..oMMN.  .mMMM+.......hd+:-::                   ");
      $display(
          "   /+/::/:..:/-........:mMMMmddmMMMs...+NMMmddNMMMm:......-+-....-/.                  ");
      $display(
          "   ```  /.::...........:odmNNNNmh/-..../ydmNNNmds:.......-.......-+                 ");
      $display(
          "         -:+..............--::::--........--:::--..................::                 ");
      $display(
          "          //.......................................................-:                 ");
      $display(
          "          `+...........................................--::::-....-/`                 ");
      $display(
          "           ::.....................................-//os+/+/+oo----.`                  ");
      $display(
          "            :/-.............................-::/\033[0;31;111mosyyyyyyyyyyyh\033[m-   ");
      $display(
          "             +s+:-...................--::/\033[0;31;111m+ssyyyyyyyyyyyyyyyyy\033[m+   ");
      $display(
          "            .\033[0;31;111myyyyso+:::----:/::://+osssyyyyyyyyyyyyyyyyyyyyyyyy\033[m-  ");
      $display(
          "             -/\033[0;31;111msyyyyyyysssssssyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy\033[m. ");
      $display(
          "               `-/\033[0;31;111mssyhyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy\033[m`");
      $display(
          "                  `.\033[0;31;111mohyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyhyyyyyyyyyyss\033[m/");
      $display(
          "                   \033[0;31;111myyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyydyyyyysso/o\033[m. ");
      $display(
          "                   :\033[0;31;111mhyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyhhhyy\033[m:-...+   ");
      $display(
          "                   \033[0;31;111msyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy\033[m+....o   ");
      $display(
          "                  `\033[0;31;111mhyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy\033[m+:..//   ");
      $display(
          "                  :\033[0;31;111mhyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy\033[m:+.-o`   ");
      $display(
          "                  -\033[0;31;111mhyyyyyyssoosyyyyyssoosyyyyyyssoo+oosy\033[m+--..o`   ");
      $display(
          "                  `s\033[0;33;219m/////:-.``.://::-.``.:/++/:-```````.\033[m+:--:+    ");
      $display(
          "                  ./\033[0;33;219m`````````````````````````````````````\033[ms.-.     ");
      $display(
          "                  /-\033[0;33;219m`````````````````. ``````````````````\033[mo        ");
      $display(
          "                  +\033[0;33;219m``````````````````. ``````````````````\033[m+`       ");
      $display(
          "                  +-\033[0;33;219m....-...---------: :::::::::::::/::::\033[m+`       ");
      $display(
          "                  `\033[0;33;219m.....+::::-:+`````   `   `/+..---o:```\033[m         ");
      $display(
          "                        :-..../`              o-....s``                              ");
      $display(
          "                        ./-.--o               :+:::/o                                ");
      $display(
          "                         /::--o               `o````o                                ");
      $display(
          "                        -//   +                +- `-s/                               ");
      $display(
          "                      -/-::::o:              :+////-+/:-                           ");
      $display(
          "                  `///:-:///:::+             `+////:////+s+                          ");
      $display(
          "*************************************************************************************");
      $display(
          "                        \033[0;38;5;219mCongratulations!\033[m                       ");
      $display(
          "                 \033[0;38;5;219mYou have passed all patterns!\033[m                 ");
      $display(
          "                 \033[0;38;5;219mTotal Cycles : %d\033[m                             ",
          total_latency);
      $display(
          "*************************************************************************************");
      $finish;
    end
  endtask



  task YOU_FAIL_TASK;
    begin
      $display("\033[31m");
      $display(
          "*************************************************************************************");
      $display(
          "*                                   FAILURE!                                        ");
      $display(
          "*                                   (;´༎ຶД༎ຶ`)                                         ");
      $display(
          "*                     Something went wrong with the test!                           ");
      $display(
          "*************************************************************************************");
      $display("\033[0m");
      $finish;
    end
  endtask

endmodule
