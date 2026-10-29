CROSS_CCOPTS += --peep-file $(FUZIX_ROOT)/Kernel/cpu-z80/rst.peep
#
#	All the C code goes in CODE2 so that _CODE (which the linker always
#	places first, at 0x0100) stays small and the common memory and data
#	that follow it stay in the fixed lower 32K.
#
export CROSS_CC_SEG1=--codeseg CODE2
export CROSS_CC_SEG2=--codeseg CODE2
export CROSS_CC_SEG3=--codeseg CODE2
export CROSS_CC_SEG4=--codeseg CODE2
export CROSS_CC_VIDEO=--codeseg CODE2
export CROSS_CC_SYS1=--codeseg CODE2
export CROSS_CC_SYS2=--codeseg CODE2
export CROSS_CC_SYS3=--codeseg CODE2
export CROSS_CC_SYS4=--codeseg CODE2
export CROSS_CC_SYS5=--codeseg CODE2
export CROSS_CC_NETWORK=--codeseg CODE2
