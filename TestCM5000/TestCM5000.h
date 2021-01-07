#ifndef TESTCM5000_H
#define TESTCM5000_H

enum{
	DEFAULT_TIMER 		= 10240,	// 10 seconds
	MAX_SENSORS				= 5,			// Number of sensors (Vref, Temp, Hum, Light, TSR)
	TestCM5000_AM_ID	= 0x01,		// TestCM5000 AM ID
};

typedef nx_struct THL_msg {
	nx_uint16_t vref;
	nx_uint16_t temperature;
	nx_uint16_t humidity;
	nx_uint16_t photo; 
	nx_uint16_t radiation; 
} THL_msg_t;

#endif
