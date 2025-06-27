/*
A code based on the 2 community Kuramoto model described in

https://journals.sagepub.com/doi/10.1177/0748730419898314

*/
===========================================================================================
/* Global variables

        b - buffer
        c - array of Kuramoto synths
        o - array of Kuramoto oscillators, combined for 2 communities (phase angle)
        r - routine to perform simulation of synchronization
        s - the server (Server.local)
        v - volume
*/
// ===========================================================================================
// Boot the supercollider server

// Server.killAll;

s.boot;

ServerOptions.outDevices;
ServerOptions.inDevices;

o = Server.default.options;

// for windows.  MAKE SURE MOTU rate is set to rate Windows is expecting (44.1?)
// o.outDevice_("ASIO : MOTU Pro Audio");

o.numOutputBusChannels_(24);
Server.default.reboot;

s.meter;

// to quit server
s.quit;

// Run ifconfig in a terminal window to figure out ip address of laptop, and enter this as
// Host in TouchOSC
// The second argument printed out is the port # to set as outgoing on TouchOSC

NetAddr.localAddr.postln

// For seeing of TouchOSC is working
// Set up TouchOSC with outgoing port set to 57120
// Run the next line.  There should be lots of /accxyz messages
OSCFunc.trace(true); // Turn posting on

OSCFunc.trace(false); // Turn posting off

//==============================================================================
/*
Start listening to osc messages, expecting simple interface from TouchOSC with 4 faders

The top horizontal fader is volume

The four vertical faders are:
  1. interaction strength within a community
  2. interaction strength between the two communities
  3. noise, to disrupt interaction within community 1
  4. noise, to disrupt interaction within community 2
*/
(
~fader1 = OSCFunc(
	{ arg msg, time, addr, recvPort;
		~kK = msg[1];
	},
	'/1/fader1');

~fader2 = OSCFunc(
	{ arg msg, time, addr, recvPort;
		~kL = msg[1];
	},
	'/1/fader2');

~noise1 = 0;
~fader3 = OSCFunc(
	{ arg msg, time, addr, recvPort;
		~noise1 = msg[1] / 20.0;
	},
	'/1/fader3');

~noise2 = 0;
~fader4 = OSCFunc(
	{ arg msg, time, addr, recvPort;
		~noise2 = msg[1] / 20.0;
	},
	'/1/fader4');

~volumeOSC = -40;
~fader5 = OSCFunc(
	{ arg msg, time, addr, recvPort;
		~volumeOSC = (-40.0*(1.0-msg[1]));
	},
	'/1/fader5');
)

// To stop OSC
(
~fader1.release();
~fader2.release();
~fader3.release();
~fader4.release();
~fader5.release();
)

//==============================================================================
// Graphics display (generates OSC messages, so start after any checking of
// TouchOSC
(
s.plotTree;  // Server.local.plotTree

// Volume gui

v = s.volume;
v.gui;
)

//==============================================================================
// Support routines, for use with the oscillators in the Kuramoto model
(
// Develop the average
~avg = {arg ol;
	var av;

	av = 0;
	ol.do({ arg item, i;  av = av+item });
	av = av/ol.size;
	av
};

// Place oscillators in range [0,2pi]
~inCircle = {arg ol;
	for (0, ol.size-1,
	{
		arg i;
		var os;

		os = ol[i];
		while ( {os>2pi}, {os = os-2pi});
		while ( {os<0},   {os = os+2pi});
		ol[i] = os;
	});
	ol
};

// Evaluate dTheta for an oscillator
// Arguments are the oscillator list and the oscillator index and
// coupling constant K
~dTheta = {arg ol, j, kk;
	var dT;
	dT = 0;

	for (0, ol.size-1,
		{
			arg i;

			// can add omega from list in later version
			dT = dT + sin( ol[i] - ol[j] )
	});
	dT = (kk/ol.size)*dT;
	dT
};

~dTh2pop = {arg ok, ol, i, k, l;
	/*
	Find delta theta for an oscillator

	Input arguments:
	ok - oscillators in same community as oscillator to update
	ol - oscillators in the "other" community
	i  - the index of the oscillator to update
	k  - interaction between oscillators
	l  - interaction between oscillators in "other" community
	*/
	var dT, kN, lN;

	dT = 0;
	kN = k / ok.size;
	lN = l / ol.size;

	for (0, ok.size-1,
		{
			arg j;

			dT = dT + ( kN * sin( ok[j] - ok[i] ) )
	});

		for (0, ol.size-1,
		{
			arg j;

			dT = dT + ( lN * sin( ol[j] - ok[i] ) )
	});

	dT
};

// update the state of the two communities
~update = {
	var dth1, dth2;

	dth1 = Array.newClear( ~o1.size );
	dth2 = Array.newClear( ~o2.size );

	// Develop delta theta for thr two communities
	~o1.size.do( { arg i;  dth1[i] = ~dTh2pop.value(~o1,~o2,i,~kK,~kL) } );
	~o2.size.do( { arg i;  dth2[i] = ~dTh2pop.value(~o2,~o1,i,~kK,~kL) } );

	// Add noise
	~o1.size.do( { arg i;  dth1[i] = dth1[i] + (~noise1*pi).rand2 } );
	~o2.size.do( { arg i;  dth2[i] = dth2[i] + (~noise2*pi).rand2 } );

	// explicit update
	~o1 = ~o1 + dth1;
	~o2 = ~o2 + dth2;

	// Place on the unit circle (will change value of argument to function
	~inCircle.value(~o1);
	~inCircle.value(~o2);

	// Return the maximum delta theta
	max(dth1.maxItem,dth2.maxItem);
};

~nShape4 = {arg x1, x2;
	var n1, n2, n3, n4;
	// Following order of speakers
	n1 = 0.25*(1-x1)*(1+x2);
	n2 = 0.25*(1+x1)*(1+x2);
	n3 = 0.25*(1+x1)*(1-x2);
	n4 = 0.25*(1-x1)*(1-x2);

	[n1, n2, n3, n4]
};

// Takes coordinates x1 & x2 in range [-1,1],[-1,1] and maps to CLEAT speaker array
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
)

//==============================================================================
// SynthDef for a Kuramoto oscillator
(
SynthDef.new(\granPlay, {
	arg buf, bufPos, panPos, gate=0, trigPhasor=0;
    var trate, dur, rate, sig, bufNorm, pos, env, chnl;
	var spkrAmp = NamedControl.kr(\spkrAmp,[1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1]);

	trate = 20.0;  // trigger rate
	dur   = 2 / trate; //0.25; //0.3; //0.4;   // 1.0; // 1 / trate; // 4 / trate;
    rate  = 1.0;

	// Phasor
	pos = bufPos + Phasor.ar(
		trigPhasor,                  // trigger
		1.0,                         // rate (per sample increment) could multiply by BufRateScale for mismatch
		0.0,                         // start
		1.0,                         // end
		0.0                          // resetPos
	);

	// JI example may work better w/o noise
	// pos = pos + LFNoise0.kr(100).bipolar(0.01);

	// Envelope to gracefully ramp down volume (using default parameters)
	env = EnvGen.kr(Env.adsr, gate);

	// May want to use Dust as trigger
	sig = TGrains.ar(1,
		Impulse.ar(trate),           // trigger rate
		buf,                         // buffer
		rate,                        // rate
		pos,                         // position, was bufPos
		dur,
		0.0,                         // pan, center 0.0, was Dseq([-1, 1], inf),
		1.0,                         // amplitude
		4);                          // interpolation

/*	chnl = floor(panPos).asInteger;
	Out.ar(chnl, sig*env);*/

	// Out.ar(0, sig*env*[1,1]);     // for testing with 2 channels
	Out.ar(0,env*spkrAmp*sig);       // multichannel expansion for CLEAT

}).add;
)


//==============================================================================
/* Set up sound file(s).
   Can have two different files, but they must be of exactly the same
   length.

   The strategy here is to use a single stereo file,
   and assign a channel to each buffer.

   You will have to change directories here!
*/

// overtones in one channel, undertones in the other
(
b = Buffer.readChannel(s,
	"/Users/abeaudoi/sw/git_repos/scCLEAT/recordings/overUnder.wav",
	channels: [0]);

~b1 = Buffer.readChannel(s,
	"/Users/abeaudoi/sw/git_repos/scCLEAT/recordings/overUnder.wav",
	channels: [1]);
)

// claves
(
b = Buffer.readChannel(s,
	"/Users/abeaudoi/sw/git_repos/scCLEAT/recordings/rhumba_claves.wav",
	channels: [0]);

~b1 = Buffer.readChannel(s,
	"/Users/abeaudoi/sw/git_repos/scCLEAT/recordingsrhumba_claves.wav",
	channels: [0]);
)

//==============================================================================
// Initialization
// set the number of copies to play, the same number is used in each community
(
~n_osc = 32;

~o1 = Array.fill(~n_osc, { arg i; (2pi).rand });
~o2 = Array.fill(~n_osc, { arg i; (2pi).rand });

c = Array.newClear(2*~n_osc);

// set initial parameter values
// ~kK, ~kL are coupling between 'self' and 'other' communities, respectively

~kK = 0.0;
~kL = 0.0;
)

//==============================================================================
// Main routine for performance
(

// Combine two communities into global variable o
o = ~o1 ++ ~o2;

for (0, o.size-1,
	{
		arg i;
		var phase, bPos;

		phase = o[i] / 2pi;
		bPos = phase*b.duration;

		c[i] = if (i<(o.size/2),
			{ Synth.new(\granPlay, [\buf, b, \bufPos, bPos, \panPos, 0.0]) },
			{ Synth.new(\granPlay, [\buf, ~b1, \bufPos, bPos, \panPos, 0.0]) }
		);

		c[i].set(\gate,1);
	});

r = Routine {
	var ts, wt, omega, bCtr, lastTime, sFns, spkrVol, horiz = 400, vert = 400;

	ts = 0;
	wt = 0.02;

	// divide the circle up into (buffer duration) / (wait time) intervals
	omega = 2pi / (b.duration / wt);

	bCtr = wt;

	w = Window("Two Community", Rect(40, 40, horiz, vert), false);
	w.front;
	w.drawFunc = {
		var al, am=0.1;
		// fill the gradient
		Pen.addOval(w.view.bounds.insetBy(30));
		Pen.fillRadialGradient(w.view.bounds.center,
			w.view.bounds.center, 0, w.bounds.width, Color.white, Color.gray);
		Pen.color = Color.blue(0.5,0.5);
		al = max( am, min( (1-~order1.rho)*pi, (pi-am) ) );
		Pen.addWedge(w.view.bounds.center, (~order1.rho*(w.view.bounds.width/2))-30, ~order1.angle-al, 2*al);
		Pen.perform(\fill);

		Pen.color = Color.red(0.5,0.5);
		al = max( am, min( (1-~order2.rho)*pi, (pi-am) ) );
		Pen.addWedge(w.view.bounds.center, (~order2.rho*(w.view.bounds.width/2)-30), ~order2.angle-al, 2*al);
		Pen.perform(\fill);
	};

	lastTime = r.seconds;

	while ( {ts<1000000},
		{
			ts = ts + 1;

			// advance through the buffer
			bCtr = bCtr + (r.seconds-lastTime); // + wt;
			lastTime = r.seconds;
			bCtr =  if (bCtr>(b.duration-wt), {wt}, {bCtr});

			// update the two community Kuramoto model
			~update.value();

			// compute buffer position for granular synthesis
			o = ~o1 ++ ~o2;    // combine the two communities
			for (0, c.size-1,
				{
					arg i;
					var bPos, ph, pp;

					// c[i].free;
					ph = o[i] / 2pi;
					bPos = bCtr + (ph*b.duration);
					bPos = if (bPos>b.duration, {bPos-b.duration}, {bPos});

					c[i].set(\bufPos,bPos);

					pp = if (i<(o.size/2), { Polar(1,o[i]) }, { Polar(1,o[i]+pi) } );
					sFns = ~nShape16.value(pp.real,pp.imag);
					// klutzy... clean out negative values in interpolation.
					spkrVol = sFns;
					sFns.do({ |item, i| if(item<0,{spkrVol[i]=0},{spkrVol[i]=item})};);
					c[i].set(\spkrAmp,spkrVol);
				}
			);

			// update the graphics
			~order1 = complex(0,0);
			~o1.do( { arg o_i;  ~order1 = ~order1 + exp(Complex(0,o_i)) } );
			~order1 = -1*~order1 / ~o1.size;

			~order2 = complex(0,0);
			~o2.do( { arg o_i;  ~order2 = ~order2 + exp(Complex(0,o_i)) } );
			~order2 = ~order2 / ~o2.size;

			w.refresh;

			[~order1.real, ~order1.imag, ~order2.real, ~order2.imag].postln;

			v.volume = ~volumeOSC;

			// (wt).wait;
			// Change (wt).wait; to this to turn off trigger
			(0.1*wt).wait;
			for (0, c.size-1,
				{
					arg i;
					c[i].set(\trigPhasor,0);
				}
			);

			(0.9*wt).wait;

		};
	)
}.play(AppClock);
)

//==============================================================================

/*
(gracefully) Shut things down:
        1. Trigger envelope off, to quiet things down
        2. Stop the routine
        3. Free the synths
*/

(
for (0, c.size-1,
	{
		arg i;

		c[i].set(\gate,0);
	});

r.stop;
w.close;

// Free the synths
for (0, c.size-1,
	{
		arg i;

		c[i].free;
	});
)

thisProcess.platform.recordingsDir