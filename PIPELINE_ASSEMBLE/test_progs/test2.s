/*
   btest1.s: Hammer on the branch prediction logic somewhat.
             This test is a series of 64 code-blocks that check a register
             and update a bit-vector by or'ing with 2^block#.  The resulting
             bit-vector sequence is 0xbeefbeefbaadbaad stored in mem line 2000

             Do not expect a decent prediction rate on this test.  No branches
             are re-visited (though a global predictor _may_ do reasonably well)
             The intent of this benchmark is to test control flow.

             Note: 'call_pal 0x000' is an instruction that is not decoded by
                   simplescalar3.  It is being used in this instance as a way
                   to pad the space between (almost) basic blocks with invalid
                   opcodes.
 */
data = 0x3E80


	li	x30, 0     #0          
	li	x1, 0      #4
	li	x2, 1      #8
B0:	slli	x21,	x2,	0 #c
	or	x30,	x21,	x30 #10
	beq	x1,	x0,	B32 #14
	j   bad               #18
	wfi                   #1c
	wfi                   #20

B32: slli	x21,	x2,	0 #24
     wfi

bad: wfi
