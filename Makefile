USE_SPL = 1
TARGET = Template

BUILD_DIR = build
EXCLUD_DIR = "./SPLib/*"
ifeq ($(USE_SPL), 1)
EXCLUD_DIR =""
endif
C_SRC = $(shell find . -name '*.c' ! -path $(EXCLUD_DIR))


# compile
PREFIX = arm-none-eabi-
CC = $(PREFIX)gcc
CP = $(PREFIX)objcopy
AS = $(PREFIX)gcc -x assembler-with-cpp
SZ = $(PREFIX)size

# from Truestudio
ASM_SRC = ./startup_stm32f401xx.s

# wheather debug DEBUG = 1
DEBUG = 1

#optimize
OPT = -Og

###############
# CFLAGS
###############

#cpu
CPU = -mcpu=cortex-m4

# fpu
FPU = -mfpu=fpv4-sp-d16

# float-abi
FLOAT-ABI = -mfloat-abi=hard

# mcu
MCU = $(CPU) -mthumb $(FPU) $(FLOAT-ABI)

AS_DEFS =

# C defs
SPLib_C_DEFS = \
				 -DUSE_STDPERIPH_DRIVER \

C_DEFS = \
				 -DSTM32F401xx \

AS_INC =



SPLib_C_INC = \
				-I./SPLib \
				-I./SPLib/inc \

C_INC = \
				-I./Basic/Inc \
				-I./Hardware/Inc \
				-I./User \


ifeq ($(USE_SPL), 1)
C_INC += $(SPLib_C_INC)
endif

ifeq ($(USE_SPL), 1)
C_DEFS += $(SPLib_C_DEFS)
endif


# the "sections" options and the --gc-sections in link process
# is used to delete the dead code that not used
# they must be used at the same time

ASFLAG = $(MCU) $(AS_DEFS) $(AS_INC) $(OPT)-Wall -fdata-sections -ffunction-sections

CFLAGS = $(MCU) $(C_DEFS) $(C_INC) $(OPT) -Wall -fdata-sections -ffunction-sections

# set debug flag
ifeq ($(DEBUG), 1)
CFLAGS += -g
endif

# dependency output .d file to build dir
# mmd output .d file -mp will gen a phony target to
# make sure make no error when deleted .h file
CFLAGS += -MMD -MP -MF"$(BUILD_DIR)/$(notdir $(@:%.o=%.d))"

# link script
# this file define memory map/section stack location and size
LDSCRIPT = \
./STM32F401RETx_FLASH.ld

#LIBS = -lc -lm -lnosys
# lc stand for standard c LIB
# lm stands for math LIB
# lnosys is from newlib(For embeded) not sure what for (for now)
LIBS = -lc
LIBDIR = 

#Wl, pass things behind ',' to linker
# map seems store data useful for debug
# cref seems also have to do with debug
# --gc-sections delete the unused code
LDFLAG = $(MCU) -T$(LDSCRIPT) $(LIBDIR) $(LIBS) -Wl,-Map=$(BUILD_DIR)/$(TARGET).map,--cref -Wl,--gc-sections


all: $(BUILD_DIR)/$(TARGET).elf $(BUILD_DIR)/$(TARGET).hex $(BUILD_DIR)/$(TARGET).bin

# ????????? vpath ????????????????????????????????????
OBJ = $(addprefix $(BUILD_DIR)/,$(notdir $(C_SRC:%.c=%.o)))

vpath %.c $(sort $(dir $(C_SRC)))

OBJ += $(addprefix $(BUILD_DIR)/,$(notdir $(ASM_SRC:%.s=%.o)))

vpath %.s $(sort $(dir $(ASM_SRC)))

# "|" then reqiures changes won't cause target rebuild(update)
# ???????????? make ???????????????????????????????????? ???|??? ???????????????????????????????????????

# things behind a like "d, lms" is settings for .lis file
# after "=" is the .lis file
# .lst file contains rich info about stack frame
$(BUILD_DIR)/%.o: %.c Makefile | $(BUILD_DIR)
	$(CC) -c $(CFLAGS) -Wa,-a,-ad,-alms=$(BUILD_DIR)/$(notdir $(<:%.c=%.lst)) $< -o $@
	
$(BUILD_DIR)/%.o: %.s Makefile | $(BUILD_DIR)
	$(AS) -c $(CFLAGS) $< -o $@

$(BUILD_DIR)/$(TARGET).elf: $(OBJ) Makefile | $(BUILD_DIR)
	$(CC) $(OBJ) $(LDFLAG) -o $@
	$(SZ) $@

$(BUILD_DIR)/%.hex: $(BUILD_DIR)/%.elf | $(BUILD_DIR)
	$(CP) -O ihex $< $@

$(BUILD_DIR)/%.bin: $(BUILD_DIR)/%.elf | $(BUILD_DIR)
	$(CP) -O binary -S  $< $@

$(BUILD_DIR):
	mkdir $@

#######################################
# clean up
#######################################
clean:
	-rm -fR $(BUILD_DIR)

burn: all
	st-flash --reset write $(BUILD_DIR)/$(TARGET).bin 0x08000000
#######################################
# dependencies
#######################################
-include $(wildcard $(BUILD_DIR)/*.d)

