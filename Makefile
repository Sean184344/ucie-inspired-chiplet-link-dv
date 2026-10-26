VERILATOR ?= verilator
BUILD_DIR := build

COMMON_FLAGS := --binary --timing --Wall -sv

CTRL_RTL := rtl/chiplet_link_ctrl.sv
PACKET_RTL := rtl/chiplet_packet_channel.sv

.PHONY: all controller packet edges integration random clean

all: controller packet edges integration random
	@echo "======================================"
	@echo "ALL REGRESSION TESTS PASSED"
	@echo "======================================"

controller:
	mkdir -p $(BUILD_DIR)/obj_dir
	$(VERILATOR) $(COMMON_FLAGS) --top-module tb_link_ctrl \
		$(CTRL_RTL) tb/tb_link_ctrl.sv --Mdir $(BUILD_DIR)/obj_dir
	./$(BUILD_DIR)/obj_dir/Vtb_link_ctrl

packet:
	mkdir -p $(BUILD_DIR)/packet_obj_dir
	$(VERILATOR) $(COMMON_FLAGS) --top-module tb_packet_channel \
		$(PACKET_RTL) tb/tb_packet_channel.sv \
		--Mdir $(BUILD_DIR)/packet_obj_dir
	./$(BUILD_DIR)/packet_obj_dir/Vtb_packet_channel

edges:
	mkdir -p $(BUILD_DIR)/edges_obj_dir
	$(VERILATOR) $(COMMON_FLAGS) --top-module tb_packet_channel_edges \
		$(PACKET_RTL) tb/tb_packet_channel_edges.sv \
		--Mdir $(BUILD_DIR)/edges_obj_dir
	./$(BUILD_DIR)/edges_obj_dir/Vtb_packet_channel_edges

integration:
	mkdir -p $(BUILD_DIR)/integration_obj_dir
	$(VERILATOR) $(COMMON_FLAGS) --top-module tb_link_integration \
		$(CTRL_RTL) $(PACKET_RTL) rtl/chiplet_link_top.sv \
		tb/tb_link_integration.sv --Mdir $(BUILD_DIR)/integration_obj_dir
	./$(BUILD_DIR)/integration_obj_dir/Vtb_link_integration

random:
	mkdir -p $(BUILD_DIR)/random_obj_dir
	$(VERILATOR) $(COMMON_FLAGS) --top-module tb_packet_channel_random \
		$(PACKET_RTL) tb/tb_packet_channel_random.sv \
		--Mdir $(BUILD_DIR)/random_obj_dir
	./$(BUILD_DIR)/random_obj_dir/Vtb_packet_channel_random

clean:
	rm -rf $(BUILD_DIR)

.PHONY: faultstress

all: faultstress

faultstress:
	mkdir -p $(BUILD_DIR)/faultstress_obj_dir
	$(VERILATOR) $(COMMON_FLAGS) --top-module tb_link_fault_stress \
		$(CTRL_RTL) $(PACKET_RTL) rtl/chiplet_link_top.sv \
		tb/tb_link_fault_stress.sv \
		--Mdir $(BUILD_DIR)/faultstress_obj_dir
	./$(BUILD_DIR)/faultstress_obj_dir/Vtb_link_fault_stress
