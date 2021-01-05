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

configuration TestCM5000C {
}
implementation {
  components MainC, TestCM5000P as App, LedsC;

	// Main c  
  MainC.Boot <- App;
	App.Leds 					-> LedsC;

	// Radio
	components ActiveMessageC as Radio;
  App.RadioControl 	-> Radio;
  
  components new AMSenderC(TestCM5000_AM_ID);
	App.ThlSend 	-> AMSenderC;
	App.Packet 		-> AMSenderC;
 
	// Timers
	components new TimerMilliC() as SampleTimer;
	App.SampleTimer 	-> SampleTimer;
 
 // Sensors
	components new Msp430InternalVoltageC() as SensorVref;  // Voltage    
  App.Vref -> SensorVref;
 
  components new SensirionSht11C() as SensorHT;           // Humidity/Temperature    
  App.Temperature 	-> SensorHT.Temperature;  
  App.Humidity 			-> SensorHT.Humidity;
      
  components new HamamatsuS1087ParC() as SensorPhoto; 	  // Photosynthetically Active Radiation
  App.Photo 				-> SensorPhoto;

  components new HamamatsuS10871TsrC() as SensorTotal;    // Total Solar Radiation  
  App.Radiation 		-> SensorTotal;
 
}
