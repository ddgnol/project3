/*****************************************************************************************
 * Copyright (c) 2000-2003 The Regents of the University of California.  
 * All rights reserved.
 * Copyright (c) 2005 Arch Rock Corporation
 * All rights reserved.
 * Copyright (c) 2006, Technische Universitaet Berlin
 * All rights reserved.
 * Copyright (c) 2010, ADVANTIC Sistemas y Servicios S.L.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without modification, are 
 * permitted provided that the following conditions are met:
 *
 *    * Redistributions of source code must retain the above copyright notice, this list  
 * of conditions and the following disclaimer.
 *    * Redistributions in binary form must reproduce the above copyright notice, this  
 * list of conditions and the following disclaimer in the documentation and/or other 
 * materials provided with the distribution.
 *    * Neither the name of ADVANTIC Sistemas y Servicios S.L. nor the names of its 
 * contributors may be used to endorse or promote products derived from this software 
 * without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY 
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF 
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL 
 * THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, 
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, 
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS 
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, 
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF
 * THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 * - Revision -------------------------------------------------------------
 * $Revision: 1.0 $
 * $Date: 2011/12/12 18:24:06 $
 * @author: Advanticsys <info@advanticsys.com>
*****************************************************************************************/

#include "TestCM5000.h"

module TestCM5000P @safe() {
  uses {
  
  	// Main, Leds
    interface Boot;
    interface Leds;
    
		// Radio
    interface SplitControl as RadioControl;
    interface AMSend		   as ThlSend;
		interface Packet;
	
	

		// Timers
		interface Timer<TMilli>  as SampleTimer;
		
		// Sensors    
		interface Read<uint16_t> as Vref;
  	interface Read<uint16_t> as Temperature;    
  	interface Read<uint16_t> as Humidity;    
		interface Read<uint16_t> as Photo;
		interface Read<uint16_t> as Radiation;
  }
}

implementation
{
  
/*****************************************************************************************
 * Global Variables
*****************************************************************************************/  
	uint8_t   numsensors;
	THL_msg_t data;
	message_t auxmsg;
	
/*****************************************************************************************
 * Task & function declaration
*****************************************************************************************/
  task void sendThlMsg();

/*****************************************************************************************
 * Boot
*****************************************************************************************/

  event void Boot.booted() {
  	call SampleTimer.startPeriodic(DEFAULT_TIMER); // Start timer
  }

/*****************************************************************************************
 * Timers
*****************************************************************************************/

	event void SampleTimer.fired() {
		numsensors = 0;
		call Vref.read();
		call Temperature.read();
		call Humidity.read();
		call Photo.read();
		call Radiation.read();
	}
	
/*****************************************************************************************
 * Sensors
*****************************************************************************************/

	event void Vref.readDone(error_t result, uint16_t value) {
    data.vref = value;										// put data into packet 
		if (++numsensors == MAX_SENSORS) {		
			call RadioControl.start();					// start radio if this is last sensor
		}
  }

	event void Temperature.readDone(error_t result, uint16_t value) {
    data.temperature = value;							// put data into packet 
		if (++numsensors == MAX_SENSORS) {		
			call RadioControl.start();					// start radio if this is last sensor
		}
	}

	event void Humidity.readDone(error_t result, uint16_t value) {
    data.humidity = value;								// put data into packet 
		if (++numsensors == MAX_SENSORS) {		
			call RadioControl.start();					// start radio if this is last sensor
		}
  }    

	event void Photo.readDone(error_t result, uint16_t value) {
    data.photo = value;										// put data into packet 
		if (++numsensors == MAX_SENSORS) {		
			call RadioControl.start();					// start radio if this is last sensor
		}
  }  
  
	event void Radiation.readDone(error_t result, uint16_t value) {
    data.radiation = value;								// put data into packet 
		if (++numsensors == MAX_SENSORS) {		
			call RadioControl.start();					// start radio if this is last sensor
		}
  }

/*****************************************************************************************
 * Radio
*****************************************************************************************/

	event void RadioControl.startDone(error_t err) {
		if (err == SUCCESS) {	
			post sendThlMsg();					// Radio started successfully, send message
		}else	{
			call RadioControl.start();
		}
	}

	task void sendThlMsg()	{
		THL_msg_t* aux;
		aux = (THL_msg_t*)
		call Packet.getPayload(&auxmsg, sizeof(THL_msg_t));
					
		aux -> vref 			 = data.vref;
		aux -> temperature = data.temperature;
		aux -> humidity		 = data.humidity;
		aux -> photo       = data.photo; 
		aux -> radiation	 = data.radiation; 			
							
		if (call ThlSend.send(AM_BROADCAST_ADDR, &auxmsg, sizeof(THL_msg_t))!= SUCCESS)	{
			post sendThlMsg();
		}
	}
	
	event void ThlSend.sendDone(message_t* msg, error_t error) {
		if (error == SUCCESS)	{
			call RadioControl.stop();	// Msg sent, stop radio
		}else
		{
			post sendThlMsg();
		}
	}
	
	event void RadioControl.stopDone(error_t err) {
		if (err != SUCCESS) {
			call RadioControl.stop();
		}
	}



}// End  
