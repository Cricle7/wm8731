`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
module mywav
(
		input 	        clk50M      ,
			
		input  [15:0]	wav_out_data,
		output     	    wav_rden    ,
        input           play_en     , 
        
        
		output [15:0] 	wav_in_data ,
		output 	        wav_wren    ,		
        input           record_en   ,
 	

		input 	        DACLRC      ,
		input 	        BCLK        ,
		output 	        DACDAT      ,
		input           ADCLRC      ,                   
		input           ADCDAT      ,					      

		
		output   	    I2C_SCLK    ,
		inout 	        I2C_SDAT
);


wire	rst_n;


//��λ��ʱ65536*20ns
reset_delay	reset_delay_inst(
	.clock_50m(clk50M),
	.rst_n(rst_n));

//����WM8731�ļĴ���
reg_config	reg_config_inst(
	.clock_50m(clk50M),
	.reset_n(rst_n),
	.i2c_sdat(I2C_SDAT),
	.i2c_sclk(I2C_SCLK)
	);

//������Ƶ����,right justified
sinwave_gen sinwave_gen_inst(
	.clock_50M(clk50M),
	.wav_out_data(wav_out_data),
	.dacclk(DACLRC),
	.bclk(BCLK),
	.play_en(play_en),
	.dacdat(DACDAT),
	
	.wav_rden(wav_rden)
	);
	
//������Ƶ����,right justified
sinwave_store sinwave_store_inst(
	.clock_50M(clk50M),
	.wav_in_data(wav_in_data),
	.adcclk(ADCLRC),
	.bclk(BCLK),
	.adcdat(ADCDAT),
	.record_en(record_en),
	.wav_wren(wav_wren)
	);



endmodule
