#ifndef BASESTATION_H
#define BASESTATION_H

enum{
	MAX_SENSORS				= 3,			// Number of sensors (Vref, Temp, Hum, Light, TSR)
};

typedef nx_struct custom_message {
  //nx_uint16_t vref;
	nx_uint16_t temperature;
	nx_uint16_t humidity;
	nx_uint16_t photo; 
  nx_uint16_t src1;
  nx_uint64_t m1;
  nx_uint16_t src2;
  nx_uint64_t m2;
  //nx_uint16_t src3;
  //nx_uint64_t m3;
} custom_m_t;


#endif
