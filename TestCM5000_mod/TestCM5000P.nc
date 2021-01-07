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


#include"TestCM5000.h"

module TestCM5000P @safe() {
  uses {
  
  	// Main, Leds
    interface Boot;
    interface Leds;
    
		// Radio
    interface SplitControl as RadioControl;
    interface AMSend		   as ThlSend;
		interface Packet;
	interface Receive as RadioReceive[am_id_t id];
	interface AMPacket as RadioAMPacket;

		// Timers
		interface Timer<TMilli>  as SampleTimer;
		interface Timer<TMilli>  as AckTimer;
		
		// Sensors    
		//interface Read<uint16_t> as Vref;
  	interface Read<uint16_t> as Temperature;    
  	interface Read<uint16_t> as Humidity;    
		interface Read<uint16_t> as Photo;
		//interface Read<uint16_t> as Radiation;


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

	ack_m* ack_message;
	
/*****************************************************************************************
 * Task & function declaration
*****************************************************************************************/
  task void sendThlMsg();

/*****************************************************************************************
 * Boot
*****************************************************************************************/

  event void Boot.booted() {
  	call SampleTimer.startPeriodic(DEFAULT_TIMER); // Start timer
	call RadioControl.start();
  }

/*****************************************************************************************
 * Timers
*****************************************************************************************/
	

message_t* ONE receive(message_t* ONE msg, void* payload, uint8_t len);

event message_t *RadioReceive.receive[am_id_t id](message_t *msg,
						    void *payload,
						    uint8_t len) {
    return receive(msg, payload, len);
  }

 message_t* receive(message_t *msg, void *payload, uint8_t len) {
	
    message_t *ret = msg;
	am_addr_t addr;
    addr = call RadioAMPacket.destination(ret);
	if(addr==TOS_NODE_ID){
		ack_message = (ack_m*) payload;
		call Leds.led2Toggle();
		call AckTimer.stop();
		call SampleTimer.startPeriodic(10240);
	}
    return ret;
  }

  event void SampleTimer.fired() {
		numsensors = 0;
		//call Vref.read();
		call Temperature.read();
		call Humidity.read();
		call Photo.read();
		//call Radiation.read();
	}
/*****************************************************************************************
 * Sensors
*****************************************************************************************/
	/*
	event void Vref.readDone(error_t result, uint16_t value) {
    data.vref = value;										// put data into packet 
		if (++numsensors == MAX_SENSORS) {		
			call RadioControl.start();					// start radio if this is last sensor
		}
  }
	*/
	event void Temperature.readDone(error_t result, uint16_t value) {
    data.temperature = value;							// put data into packet 
		if (++numsensors == MAX_SENSORS) {		
			//call RadioControl.start();					// start radio if this is last sensor
			post sendThlMsg();
		}
	}

	event void Humidity.readDone(error_t result, uint16_t value) {
    data.humidity = value;								// put data into packet 
		if (++numsensors == MAX_SENSORS) {		
			//call RadioControl.start();					// start radio if this is last sensor
			post sendThlMsg();
		}
  }    

	event void Photo.readDone(error_t result, uint16_t value) {
    data.photo = value;										// put data into packet 
		if (++numsensors == MAX_SENSORS) {		
			//call RadioControl.start();					// start radio if this is last sensor
			post sendThlMsg();
		}
  }  
  /*
	event void Radiation.readDone(error_t result, uint16_t value) {
    data.radiation = value;								// put data into packet 
		if (++numsensors == MAX_SENSORS) {		
			//call RadioControl.start();					// start radio if this is last sensor
			post sendThlMsg();
		}
  }
  */

/*****************************************************************************************
 * Radio
*****************************************************************************************/

	event void RadioControl.startDone(error_t err) {
		if (err == SUCCESS) {	
			//post sendThlMsg();					// Radio started successfully, send message
		}else	{
			call RadioControl.start();
		}
	}

	task void sendThlMsg()	{
		THL_msg_t* aux;
		aux = (THL_msg_t*) call Packet.getPayload(&auxmsg, sizeof(THL_msg_t));
					
		//aux -> vref 			 = data.vref;
		aux -> temperature = data.temperature;
		aux -> humidity		 = data.humidity;
		aux -> photo       = data.photo; 
		//aux -> radiation	 = data.radiation; 			
							
		if (call ThlSend.send(0x0009, &auxmsg, sizeof(THL_msg_t))!= SUCCESS)	{ //AM_BROADCAST_ADDR
			post sendThlMsg();
		}
		call Leds.led0On();
	}
	
	event void ThlSend.sendDone(message_t* msg, error_t error) {
		if (error == SUCCESS)	{
			call Leds.led0Off();
			call SampleTimer.stop();
			call AckTimer.startPeriodic(2048);
			//call RadioControl.stop();	// Msg sent, stop radio
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

	event void AckTimer.fired(){
		call Leds.led1Toggle();
		post sendThlMsg();
		//call RadioControl.stop();
	}

}// End  
