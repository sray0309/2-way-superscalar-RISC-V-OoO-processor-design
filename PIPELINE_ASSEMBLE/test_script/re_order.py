def read_writeback(filepath):
    with open(filepath,"r",encoding='utf-8') as file_obj:
        data = []
        for line in file_obj:
            data.append(line.strip())
    return data

def write_writeback(filepath, data):
    with open(filepath,'w',encoding='utf-8') as file_obj:
        for line in data:
            file_obj.write(f'{line}\n')
            

read_path = "../writeback.out"

data = read_writeback(read_path)

pc = 0
data_temp = []
data_out = []
for line in data:
    pc_idx = line.index("PC=")+3
    reg_idx = line.index(",")+2
    if line[pc_idx:pc_idx+8] != 'fffffffc' and line[reg_idx:reg_idx+3] != '---':
        data_temp.append(line)



for i in range (len(data_temp)):
    for line in data_temp:
        pc_idx = line.index("PC=")+3
        reg_idx = line.index(",")+1
        if int(line[pc_idx:pc_idx+8],16) == pc:
            hexpc = hex(pc)
            hexpc = hexpc.replace('x','0')
            formated_pc = ''
            for j in range (8-len(hexpc)):
                formated_pc = formated_pc+'0'
            formated_pc = formated_pc + hexpc
            str_temp = f'PC={formated_pc}, {line[reg_idx:]}'
            data_out.append(str_temp)
    pc = pc + 4
    
write_path = '../ordered_writeback.out'

write_writeback(write_path, data_out)

