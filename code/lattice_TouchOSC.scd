/*
This code plays notes on a 3 dimensional just intonation lattice, based on the orientation of
a cell phone.  TouchOSC is used to read accelerometer data, and the position of the gravity vector is derived from is used to determine the position on the sphere.
*/

/*
1. Run ifconfig in a terminal window to figure out ip address of laptop, and enter this as
Host in TouchOSC (on phone or tablet).

2. The second argument printed out from the following line is the port # to set as outgoing
   on TouchOSC, typically 57120.

Testing was done using Mobile Hotspot on an Android phone.
*/
NetAddr.localAddr.postln

// To check if TouchOSC is communicating...
// run the next line.  There should be lots of /accxyz messages
OSCFunc.trace(true); // Turn posting on

OSCFunc.trace(false); // Turn posting off

// Filter the accelerometer data, using a simple moving average.
(
~a_time = -1.0;
~gravity = [0.0,0.0,0.0];

// Parameter to adjust running average (to filter out gravity)
~alpha = 0.8;

~acc_gravity = {arg ax, ay, az;
	var acc, a_g;

	a_g = if(~a_time<0.0,
		{

			~a_time = SystemClock.seconds;
			~gravity = [ax,ay,az];
		},
		{
			~a_time = SystemClock.seconds;
			// update running average for gravity, then subtract off
			acc = [ax,ay,az];
			~gravity = (~alpha*~gravity) + ((1 - ~alpha)*acc);
		}
	);
}
)

// This starts listening to osc messages, and computes orientation current gravity vector
(
o = OSCFunc(
	{ arg msg, time, addr, recvPort;
		~acc_gravity.value(msg[1],msg[2],msg[3]);
	},
	'/accxyz');
)

// Just Intonation Lattice code
// Given integers a, b & c, compute the frequency ratio at that lattice position.
(
~baseV = Array.with(3/2, 5/4, 7/4);

~calc_ratio = {arg a, b, c;

	var r;

	r = (~baseV[0]**a)*(~baseV[1]**b)*(~baseV[2]**c);
	while ( {r>2.0}, {r = r/2.0} );
	while ( {r<=1.0}, {r = r*2.0} );
	r
};
)

(
// Takes coordinates x1 & x2 in range [-1,1],[-1,1] and maps to CLEAT speaker array
// Also returns "1" as a 17th element for the subwoofer
~nShape16 = {arg x1, x2;
	var n1, n2, n3, n4, n5, n6, n7, n8, n9, n10, n11, n12, n13, n14, n15, n16;
	n1  =  (81/256)*(1+(-1*x1))*(1+( 1*x2))*((1/9)-(x1*x1))*((1/9)-(x2*x2));
	n2  = (243/256)*(1-(x1*x1))*((x2*x2)-(1/9))*((1/3)+(3*(-1/3)*x1))*(1+( 1*x2));
	n3  = (243/256)*(1-(x1*x1))*((x2*x2)-(1/9))*(( 1/3)+(3*( 1/3)*x1))*(1+( 1*x2));
	n4  =  (81/256)*(1+( 1*x1))*(1+( 1*x2))*((1/9)-(x1*x1))*((1/9)-(x2*x2));
	n5  = (243/256)*(1-(x2*x2))*((x1*x1)-(1/9))*((1/3)+(3*( 1/3)*x2))*(1+(-1*x1));
	n6 =  (729/256)*((1-(x1*x1))*(1-(x2*x2))*((1/3)+(3*(-1/3)*x1))*((1/3)+(3*( 1/3)*x2)));
	n7 =  (729/256)*((1-(x1*x1))*(1-(x2*x2))*((1/3)+(3*( 1/3)*x1))*((1/3)+(3*( 1/3)*x2)));
	n8  = (243/256)*(1-(x2*x2))*((x1*x1)-(1/9))*((1/3)+(3*( 1/3)*x2))*(1+( 1*x1));
	n9  = (243/256)*(1-(x2*x2))*((x1*x1)-(1/9))*((1/3)+(3*(-1/3)*x2))*(1+(-1*x1));
	n10 =  (729/256)*((1-(x1*x1))*(1-(x2*x2))*((1/3)+(3*(-1/3)*x1))*((1/3)+(3*( -1/3)*x2)));
	n11 =  (729/256)*((1-(x1*x1))*(1-(x2*x2))*((1/3)+(3*( 1/3)*x1))*((1/3)+(3*( -1/3)*x2)));
	n12 = (243/256)*(1-(x2*x2))*((x1*x1)-(1/9))*((1/3)+(3*(-1/3)*x2))*(1+( 1*x1));
	n13 =  (81/256)*(1+(-1*x1))*(1+(-1*x2))*((1/9)-(x1*x1))*((1/9)-(x2*x2));
	n14  = (243/256)*(1-(x1*x1))*((x2*x2)-(1/9))*((1/3)+(3*(-1/3)*x1))*(1+(-1*x2));
	n15  = (243/256)*(1-(x1*x1))*((x2*x2)-(1/9))*((1/3)+(3*( 1/3)*x1))*(1+(-1*x2));
	n16 =  (81/256)*(1+( 1*x1))*(1+(-1*x2))*((1/9)-(x1*x1))*((1/9)-(x2*x2));
	[n1, n2, n3, n4, n5, n6, n7, n8, n9, n10, n11, n12, n13, n14, n15, n16,1]
};
)

// Boot the server
s.boot;

// Execute the following lines to get access to the 24 output channels
o = Server.default.options;

// for windows.  MAKE SURE MOTU rate is set to rate Windows is expecting (it could be 44.1!)
// o.outDevice_("ASIO : MOTU Pro Audio");

o.numOutputBusChannels_(24);
Server.default.reboot;

// If the above worked, then outputs will appear in meter
s.meter;

// To keep track of synths being generated (they should disappear when phone is still)
s.plotTree;

// An example synth from "A Gentle Introduction to Supercollider"
// modified to use multichannel expansion for the CLEAT array
(
SynthDef(\pluck, {arg out=0, amp = 0.1, wnamp=0.1, freq = 440, decay = 5, mutedString = 0.05;
var env, snd;
var spkrAmp = NamedControl.kr(\spkrAmp,[1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1]);
env = Env.linen(0, decay, 0).kr(doneAction: 2);
snd = Pluck.ar(
in: WhiteNoise.ar(wnamp),
trig: Impulse.kr(0),
maxdelaytime: 0.1,
delaytime: freq.reciprocal,
decaytime: decay,
coef: mutedString);
Out.ar(0, amp*spkrAmp*snd);
}).add;
)

// Routine to play the lattice
(
r = Routine {
	var iGravity, lastGravity;

	lastGravity = ~gravity.asInteger;

	inf.do(
		{
			var x1, x2;

			iGravity = ~gravity.asInteger;
			if ( lastGravity != iGravity,
				{
					var frq, ratio, sFns, spkrVol;

					x1 = iGravity[0]/10.0;
					x1 = if (x1>1.0,{1.0},{x1});
					x1 = if( x1<(-1.0),{-1.0},{x1});
					x2 = iGravity[1]/10.0;
					x2 = if(x2>1.0,{1.0},{x2});
					x2 = if(x2<(-1.0),{-1.0},{x2});
					[ x1, x2].postln;
					ratio = ~calc_ratio.value(iGravity[0],iGravity[1],iGravity[2]);
					frq = ratio*220.0;

					sFns = ~nShape16.value(x1,2);
					// klutzy... clean out any negative values from the interpolation.
					spkrVol = sFns;
					sFns.do({ |item, i| if(item<0,{spkrVol[i]=0},{spkrVol[i]=item})};);
					spkrVol.postln;
					// x = Synth(\pluck, ["freq", frq ] );iGravity.postln;
					x = Synth(\pluck, ["freq", frq, "amp", 0.02] );
					x.set(\spkrAmp,spkrVol);
				}

			);
			lastGravity = iGravity;
			0.1.wait;
		}
	);
	}.play(AppClock);
)


// To stop the routine
r.stop;

// To free osc messages
o.free;