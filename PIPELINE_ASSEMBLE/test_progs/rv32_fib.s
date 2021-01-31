/*
	TEST PROGRAM #3: compute first 16 fibonacci numbers
			 with forwarding and stall conditions in the loop


	long output[16];
	
	void
	main(void)
	{
	  long i, fib;
	
	  output[0] = 1;
	  output[1] = 2;
	  for (i=2; i < 16; i++)
	    output[i] = output[i-1] + output[i-2];
	}
*/
	
	data = 0x1000
	li	x4, data    # x4  = 0x1000
	li	x5, 0x1008  # x5  = 0x1008
	li	x6, 0x1010  # x6  = 0x1010
	li	x10, 2      # x10 = 0x2
	li	x2, 1				# x2  = 0x1
	sw	x2, 0(x4)   # [x4(0x1000)] = 0x1
	sw	x2, 0(x5)   # [x5(0x1008)] = 0x1
									#
									#					     loop1	                   loop2
loop:	lw	x2, 0(x4)  #   x2 = [x4(0x1000)] = 0x1    x2 = [x4(0x1008)] = 0x1        1010=2     1018=3      1020=5     1028=8    1030=d     1038=15     1040=22     1048=37  1050 = 59
	lw	x3, 0(x5)      #   x3 = [x5(0x1008)] = 0x1    x3 = [x5(0x1010)] = 0x2        1018=3     1020=5      1028=8     1030=d    1038=15    1040=22     1048=37     1050=59  1058 = 90
	add	x3,	x3,	x2     #         x3  = 0x2                  x3 = 0x3
	addi	x4,	x4,	0x8  #         x4  = 1008                 x4 = 1010
	addi	x5,	x5,	0x8  #         x5  = 1010                 x5 = 1018
	addi	x10,	x10,	 0x1 #     x10 = 0x3                 x10 = 0x4
	slti	x11,	x10,	 16 #      x11 = 0x3 << 16           x11 = 0x4 << 16
	sw	x3, 0(x6)        #   [x6(0x1010)] = 0x2         [x6(1018)] = 0x3             1020=5     1028=8      1030=d    1038=15    1040=22    1048=37     1050=59
	addi	x6,	x6,	0x8 #          x6 = 0x1018                x6 = 1020   
	bne	x11,	x0,	loop #
	wfi
