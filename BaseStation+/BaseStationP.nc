// $Id: BaseStationP.nc,v 1.12 2010-06-29 22:07:14 scipio Exp $

/*									tab:4
 * Copyright (c) 2000-2005 The Regents of the University  of California.  
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * - Redistributions of source code must retain the above copyright
 *   notice, this list of conditions and the following disclaimer.
 * - Redistributions in binary form must reproduce the above copyright
 *   notice, this list of conditions and the following disclaimer in the
 *   documentation and/or other materials provided with the
 *   distribution.
 * - Neither the name of the University of California nor the names of
 *   its contributors may be used to endorse or promote products derived
 *   from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL
 * THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
 * OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 * Copyright (c) 2002-2005 Intel Corporation
 * All rights reserved.
 *
 * This file is distributed under the terms in the attached INTEL-LICENSE     
 * file. If you do not find these files, copies can be found by writing to
 * Intel Research Berkeley, 2150 Shattuck Avenue, Suite 1300, Berkeley, CA, 
 * 94704.  Attention:  Intel License Inquiry.
 */

/*
 * @author Phil Buonadonna
 * @author Gilman Tolle
 * @author David Gay
 * Revision:	$Id: BaseStationP.nc,v 1.12 2010-06-29 22:07:14 scipio Exp $
 */
  
/* 
 * BaseStationP bridges packets between a serial channel and the radio.
 * Messages moving from serial to radio will be tagged with the group
 * ID compiled into the BaseStation, and messages moving from radio to
 * serial will be filtered by that same group id.
 */

#include "AM.h"
#include "Serial.h"
#include "BaseStation.h"

module BaseStationP @safe() {
  uses {
    interface Boot;
    interface SplitControl as SerialControl;
    interface SplitControl as RadioControl;

    interface AMSend as UartSend[am_id_t id];
    interface Receive as UartReceive[am_id_t id];
    interface Packet as UartPacket;
    interface AMPacket as UartAMPacket;
    
    interface AMSend as RadioSend[am_id_t id];
    interface Receive as RadioReceive[am_id_t id];
    interface Receive as RadioSnoop[am_id_t id];
    interface Packet as RadioPacket;
    interface AMPacket as RadioAMPacket;

    interface AMSend		   as ThlSend;
    interface Packet;
    interface Leds;

    // Sensors    
		//interface Read<uint16_t> as Vref;
  	interface Read<uint16_t> as Temperature;    
  	interface Read<uint16_t> as Humidity;    
		interface Read<uint16_t> as Photo;
  }
}

implementation
{
  enum {
    UART_QUEUE_LEN = 12,
    RADIO_QUEUE_LEN = 12,
  };

  //nx_uint16_t vref;
	uint16_t temperature;
	uint16_t humidity;
	uint16_t photo; 
  uint8_t numsensors = 0;

  custom_m_t* cm;
  uint64_t* _payload1;
  uint64_t* _payload2;
  uint8_t counter;
  bool odd = TRUE;
  message_t  uartQueueBufs[UART_QUEUE_LEN];
  message_t  * ONE_NOK uartQueue[UART_QUEUE_LEN];
  uint8_t    uartIn, uartOut;
  bool       uartBusy, uartFull;

  message_t  radioQueueBufs[RADIO_QUEUE_LEN];
  message_t  * ONE_NOK radioQueue[RADIO_QUEUE_LEN];
  uint8_t    radioIn, radioOut;
  bool       radioBusy, radioFull;

  task void uartSendTask();
  task void radioSendTask();

  task void sendThlMsg();
  message_t auxmsg;
  am_addr_t _src;
  void dropBlink() {
    call Leds.led2Toggle();
  }

  void failBlink() {
    call Leds.led2Toggle();
  }

  event void Boot.booted() {
    uint8_t i;

    for (i = 0; i < UART_QUEUE_LEN; i++)
      uartQueue[i] = &uartQueueBufs[i];
    uartIn = uartOut = 0;
    uartBusy = FALSE;
    uartFull = TRUE;

    for (i = 0; i < RADIO_QUEUE_LEN; i++)
      radioQueue[i] = &radioQueueBufs[i];
    radioIn = radioOut = 0;
    radioBusy = FALSE;
    radioFull = TRUE;

    if (call RadioControl.start() == EALREADY)
      radioFull = FALSE;
    if (call SerialControl.start() == EALREADY)
      uartFull = FALSE;
  }

  event void RadioControl.startDone(error_t error) {
    if (error == SUCCESS) {
      radioFull = FALSE;
    }
  }

  event void SerialControl.startDone(error_t error) {
    if (error == SUCCESS) {
      uartFull = FALSE;
    }
  }

  event void SerialControl.stopDone(error_t error) {}
  event void RadioControl.stopDone(error_t error) {}

  uint8_t count = 0;

  message_t* ONE receive(message_t* ONE msg, void* payload, uint8_t len);
  
  event message_t *RadioSnoop.receive[am_id_t id](message_t *msg,
						    void *payload,
						    uint8_t len) {
    return receive(msg, payload, len);
  }
  
  event message_t *RadioReceive.receive[am_id_t id](message_t *msg,
						    void *payload,
						    uint8_t len) {
    
    return receive(msg, payload, len);
  }

  message_t* receive(message_t *msg, void *payload, uint8_t len) {
    message_t *ret = msg;
    am_addr_t addr;
    addr = call RadioAMPacket.destination(ret);
    if(addr==0x0009){
    am_addr_t src;
    src = call RadioAMPacket.source(msg);
    if(!odd){
      _payload2 = (uint64_t*) payload;
      cm->src2 = (uint16_t) src;
      cm->m2 = *_payload2;
      //cm->src3 = (uint16_t) src;
      //cm->m3 = *_payload2;
      odd = TRUE; 
      //call Vref.read();
		  call Temperature.read();
		  call Humidity.read();
		  call Photo.read();
      //post sendThlMsg();
    }
    else{
      cm = (custom_m_t*) call UartPacket.getPayload(&auxmsg, sizeof(custom_m_t));
      _payload1 = (uint64_t*) payload;
      cm->src1 = src;
      cm->m1 = *_payload1;
      odd = FALSE;
    }
      
   
    atomic {
      if (!uartFull)
	{
    //call Leds.led2Toggle();
	  ret = uartQueue[uartIn];
	  uartQueue[uartIn] = msg;
      uartIn = (uartIn + 1) % UART_QUEUE_LEN;
	
	    if (uartIn == uartOut)
	      uartFull = TRUE;

	    if (!uartBusy)
	    {
	      post uartSendTask();
	      uartBusy = TRUE;
	    } 
	}
      else
	  dropBlink();
    }
    }
    return ret;
  }

  uint8_t tmpLen;
  
  task void uartSendTask() {
    uint8_t len;
    am_id_t id;
    am_addr_t addr, src;
    message_t* msg;
    am_group_t grp;
    atomic
      if (uartIn == uartOut && !uartFull)
	{
	  uartBusy = FALSE;
	  return;
	}

    msg = uartQueue[uartOut];
    /*
    cm = (custom_m_t*) call UartPacket.getPayload(&auxmsg, sizeof(custom_m_t));
    cm->m1 = *_payload;
    cm->m2 = 0x0000000000000000;
    */
    tmpLen = len = call RadioPacket.payloadLength(msg);
    id = call RadioAMPacket.type(msg);
    addr = call RadioAMPacket.destination(msg);
    src = call RadioAMPacket.source(msg);
    grp = call RadioAMPacket.group(msg);
    call UartPacket.clear(msg);
    call UartAMPacket.setSource(msg, src);
    call UartAMPacket.setGroup(msg, grp);
    //auxmsg = msg;
    //_src = src;
    //post sendThlMsg();
    if (call UartSend.send[id](addr, uartQueue[uartOut], len) == SUCCESS){
      call Leds.led1Toggle();
    }  
    else
      {
	failBlink();
	post uartSendTask();
      }
      
  }

  event void UartSend.sendDone[am_id_t id](message_t* msg, error_t error) {
    if (error != SUCCESS)
      failBlink();
    else
      atomic
	if (msg == uartQueue[uartOut])
	  {
	    if (++uartOut >= UART_QUEUE_LEN)
	      uartOut = 0;
	    if (uartFull)
	      uartFull = FALSE;
	  }
    post uartSendTask();
    //post sendThlMsg(); 
  }

  event message_t *UartReceive.receive[am_id_t id](message_t *msg,
						   void *payload,
						   uint8_t len) {
   
    message_t *ret = msg;
    bool reflectToken = FALSE;
    call Leds.led2Toggle();
    atomic
      if (!radioFull)
	{
	  reflectToken = TRUE;
	  ret = radioQueue[radioIn];
	  radioQueue[radioIn] = msg;
	  if (++radioIn >= RADIO_QUEUE_LEN)
	    radioIn = 0;
	  if (radioIn == radioOut)
	    radioFull = TRUE;

	  if (!radioBusy)
	    {
	      post radioSendTask();
	      radioBusy = TRUE;
	    }
	}
      else
	dropBlink();

    if (reflectToken) {
      //call UartTokenReceive.ReflectToken(Token);
    }
    
    return ret;
  }

  task void radioSendTask() {
    uint8_t len;
    am_id_t id;
    am_addr_t addr,source;
    message_t* msg;
    
    atomic
      if (radioIn == radioOut && !radioFull)
	{
	  radioBusy = FALSE;
	  return;
	}

    //msg = radioQueue[radioOut];
    msg = uartQueue[uartOut];
    len = call UartPacket.payloadLength(msg);
    addr = call UartAMPacket.destination(msg);
    source = call UartAMPacket.source(msg);
    id = call UartAMPacket.type(msg);

    call RadioPacket.clear(msg);
    call RadioAMPacket.setSource(msg, source);
    
    if (call RadioSend.send[id](AM_BROADCAST_ADDR, msg, len) == SUCCESS)
      call Leds.led2Toggle();
    else
      {
	failBlink();
	post radioSendTask();
      }
  }

  event void RadioSend.sendDone[am_id_t id](message_t* msg, error_t error) {
    if (error != SUCCESS)
      failBlink();
    else
      atomic
	if (msg == radioQueue[radioOut])
	  {
	    if (++radioOut >= RADIO_QUEUE_LEN)
	      radioOut = 0;
	    if (radioFull)
	      radioFull = FALSE;
	  }
    
    post radioSendTask();
  }

  task void sendThlMsg()	{
    /*
    uint8_t len;
    am_addr_t addr, source;
    am_id_t id;
    len = call Packet.payloadLength(auxmsg);	
    source = call UartAMPacket.source(auxmsg);
    addr = call UartAMPacket.destination(auxmsg);
    id = call UartAMPacket.type(auxmsg);

    call RadioPacket.clear(auxmsg);
    call RadioAMPacket.setSource(auxmsg, _src);
    */
    //cm->vref = vref;
    cm->humidity = humidity;
    cm->temperature = temperature;
    cm->photo = photo;
		if (call ThlSend.send(0x0004, &auxmsg, sizeof(custom_m_t))!= SUCCESS)	{ //AM_BROADCAST_ADDR
			post sendThlMsg();
		}
    call Leds.led0On();
	}

  event void ThlSend.sendDone(message_t* msg, error_t error) {
		if (error == SUCCESS)	{
			call Leds.led0Off();
			//call RadioControl.stop();	// Msg sent, stop radio
		}else
		{
			post sendThlMsg();
		}
	}

  /*****************************************************************************************
 * Sensors
*****************************************************************************************/
  /*
	event void Vref.readDone(error_t result, uint16_t value) {
    vref = value;										// put data into packet 
		if (++numsensors == MAX_SENSORS) {		
			numsensors = 0;		
			post sendThlMsg();
		}
  }
  */
	event void Temperature.readDone(error_t result, uint16_t value) {
    temperature = value;							// put data into packet 
		if (++numsensors == MAX_SENSORS) {
      numsensors = 0;		
			post sendThlMsg();
		}
	}

	event void Humidity.readDone(error_t result, uint16_t value) {
    humidity = value;								// put data into packet 
		if (++numsensors == MAX_SENSORS) {		
			numsensors = 0;		
			post sendThlMsg();
		}
  }    

	event void Photo.readDone(error_t result, uint16_t value) {
    photo = value;										// put data into packet 
		if (++numsensors == MAX_SENSORS) {		
			numsensors = 0;		
			post sendThlMsg();
		}
  }  
	
}  
