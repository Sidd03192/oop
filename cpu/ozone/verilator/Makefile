VERILATOR = verilator
V_FLAGS = -Wall --cc --exe --build -j
FILES = Top.sv frontend/ozone_itlb.sv

all: obj_dir/VTop

# obj_dir/VTop: Top.sv sim_main.cpp
# 	$(VERILATOR) $(V_FLAGS) Top.sv sim_main.cpp -o VTop -LDFLAGS "-lrt"

obj_dir/VTop: Top.sv sim_main.cpp
	$(VERILATOR) $(V_FLAGS) $(FILES) sim_main.cpp -o VTop

decode_tb: obj_dir/Vdecode_tb
obj_dir/Vdecode_tb: tb/tb_ozone_decode.sv frontend/ozone_decode.sv ozone_pkg.sv
	$(VERILATOR) --binary --timing -Wno-fatal -j \
		--top-module tb_ozone_decode \
		ozone_pkg.sv frontend/ozone_decode.sv tb/tb_ozone_decode.sv \
		-o Vdecode_tb

clean:
	rm -rf obj_dir
