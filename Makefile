VERILATOR ?= verilator
BUILD_DIR := build

COMMON_FLAGS := --binary --timing --Wall --assert -sv

CTRL_RTL := rtl/chiplet_link_ctrl.sv
PACKET_RTL := rtl/chiplet_packet_channel.sv

.PHONY: all controller packet edges integration random faultstress back-to-back sva-negative clean

all: controller packet edges integration random faultstress back-to-back

back-to-back:
	mkdir -p $(BUILD_DIR)/back_to_back_obj_dir
	$(VERILATOR) $(COMMON_FLAGS) --top-module tb_packet_channel_back_to_back \
		$(PACKET_RTL) tb/tb_packet_channel_back_to_back.sv \
		--Mdir $(BUILD_DIR)/back_to_back_obj_dir
	./$(BUILD_DIR)/back_to_back_obj_dir/Vtb_packet_channel_back_to_back
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

faultstress:
	mkdir -p $(BUILD_DIR)/faultstress_obj_dir
	$(VERILATOR) $(COMMON_FLAGS) --top-module tb_link_fault_stress \
		$(CTRL_RTL) $(PACKET_RTL) rtl/chiplet_link_top.sv \
		tb/chiplet_link_sva.sv tb/tb_link_fault_stress.sv \
		--Mdir $(BUILD_DIR)/faultstress_obj_dir
	./$(BUILD_DIR)/faultstress_obj_dir/Vtb_link_fault_stress

clean:
	rm -rf $(BUILD_DIR)


# Intentional assertion failure: verify that the SVA checker detects a violation.

sva-negative:
	@set -eu; \
	mkdir -p $(BUILD_DIR); \
	run_negative_test() { \
		name="$$1"; tb="$$2"; expected="$$3"; \
		obj="$(BUILD_DIR)/$${name}_obj_dir"; \
		log="$(BUILD_DIR)/$${name}.log"; \
		echo "=== Building $$name ==="; \
		$(VERILATOR) $(COMMON_FLAGS) --top-module "$$tb" \
			tb/chiplet_link_sva.sv "tb/$$tb.sv" --Mdir "$$obj"; \
		echo "=== Running $$name ==="; \
		set +e; ulimit -c 0; "./$$obj/V$$tb" > "$$log" 2>&1; status=$$?; set -e; \
		cat "$$log"; \
		if [ "$$status" -ne 0 ] && grep -Fq "$$expected" "$$log"; then \
			echo "PASS: $$name detected expected assertion"; \
		else \
			echo "FAIL: $$name did not produce the expected assertion"; \
			return 1; \
		fi; \
	}; \
	run_negative_test sva_negative tb_sva_negative "SVA FAIL: m_valid asserted while link is down"; \
	run_negative_test sva_stall_negative tb_sva_stall_negative "SVA FAIL: stalled packet payload changed"; \
	run_negative_test sva_failed_negative tb_sva_failed_negative "SVA FAIL: FAILED state was not sticky"; \
	echo "ALL SVA NEGATIVE TESTS PASSED"
