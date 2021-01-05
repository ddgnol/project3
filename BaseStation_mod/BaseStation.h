#ifndef BASESTATION_H
#define BASESTATION_H

enum{
	MAX_SENSORS				= 3,			// Number of sensors (Vref, Temp, Hum, Light, TSR)
};

typedef nx_struct forward_message{
  nx_uint16_t temperature;
	nx_uint16_t humidity;
	nx_uint16_t photo; 
} fw_message;

typedef nx_struct full_message {
  //nx_uint16_t vref;
	nx_uint16_t temperature;
	nx_uint16_t humidity;
	nx_uint16_t photo; 
  nx_uint16_t src1;
  fw_message m1;
  nx_uint16_t src2;
  fw_message m2;

} custom_m_t;

typedef nx_struct ack_message {
  nx_uint16_t destination; 
  nx_uint8_t success;
} ack_m;


#endif
