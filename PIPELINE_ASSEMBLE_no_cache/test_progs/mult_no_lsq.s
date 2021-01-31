	li	x2, 0x8
start:	li	x3, 0x27bb
	slli	x3,	x3,	16 #8	8
	li	x1, 0x2ee6
	or	x3,	x3,	x1 #16	10
	li	x1, 0x87b
	slli	x3,	x3,	12 #24	18
	or	x3,	x3,	x1 #28	1c
	li	x1, 0x0b0
	slli	x3,	x3,	12 #36	24
	or	x3,	x3,	x1 #40	28
	li	x1, 0xfd
	slli	x3,	x3,	8 #48	30
	or	x3,	x3,	x1 #52	34
	li	x4, 0xb50
	slli	x4,	x4,	12 #60	3c
	li	x1, 0x4f3
	or	x4,	x4,	x1 #68	44
	li	x1, 0x2d
	slli	x4,	x4,	0x4 #76	4c
	or	x4,	x4,	x1 #80	50
	li	x5, 0
loop:	addi	x5,	x5,	1 #88	58
	slti	x6,	x5,	16 #92	5c
	mul	x11,	x2,	x3 #96	60
	add	x11,	x11,	x4 #100	64
	mul	x12,	x11,	x3 #104	68
	add	x12,	x12,	x4 #108	6c
	mul	x13,	x12,	x3 #112	70
	add	x13,	x13,	x4 #116	74
	mul	x2,	x13,	x3 #120	78
	add	x2,	x2,	x4 #124	7c
	srli	x11,	x11,	16 #128	80
	srli	x12,	x12,	16 #132	84
	srli	x13,	x13,	16 #136	88
	srli	x14,	x2,	16 #140	8c
	addi	x1,	x1,	16 #144	90
	bne	x6,	x0,	loop #148	94
	wfi