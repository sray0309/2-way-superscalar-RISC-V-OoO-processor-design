def read_program(filepath):
    with open(filepath,"r",encoding='utf-8') as file_obj:
        data = []
        for line in file_obj:
            data.append(line.strip())
    return data

def write_program(filepath, data):
    with open(filepath,'w',encoding='utf-8') as file_obj:
        for line in data:
            file_obj.write(f'{line}\n')
            

read_path = "../program.out"

data = read_program(read_path)

cache_info = {}
memory_info = {}
output_data=[]

for line in data:
    if ("cache" in line[:15]):
        cache_addr_startpoint = line.index("[")
        line_cache_addr = int(line[cache_addr_startpoint+1:cache_addr_startpoint+6])
        cache_info_startpoint = line.index("mem[")
        cache_info_endpoiint = line.index("cache_idx")-2
        line_cache_info = line[cache_info_startpoint:cache_info_endpoiint]
        cache_info[line_cache_addr] = "@@@ " + line_cache_info
    if ("memory" in line[:15]):
        memory_addr_startpoint = line.index("[")
        line_memory_addr = int(line[memory_addr_startpoint+1:memory_addr_startpoint+6])
        memory_info_startpoint = line.index("mem[")
        line_memory_info = line[memory_info_startpoint:]
        memory_info[line_memory_addr] = "@@@ " + line_memory_info

for i in range (0,65542,8):
    if (i in cache_info.keys()):
        output_data.append(cache_info[i])
    elif (i in memory_info.keys()):
        output_data.append(memory_info[i])

write_program("../mem_info",output_data)