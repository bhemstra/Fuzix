extern int8_t iop_diskop(void);
extern int8_t iop_diskopen(void);
extern uint8_t disk_unit;
extern uint32_t disk_lba;
extern uint8_t disk_op;

extern void disk_probe(void);

extern uint8_t anykey(void);
extern uint8_t keyscan(void);
extern uint8_t keytab[];
