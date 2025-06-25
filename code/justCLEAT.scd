/*
Views the CLEAT system as a Just Intonation Lattice, playable on a laptop,
or alternatively using TouchOSC
*/
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

s.plotTree;

// Support functions
(

/*  Ordering of the triangles used in interpolation
               lower      upper
               A-B-C      C-B-D

    C--D        C          C--D
    |\ |        |\          \ |
    | \|        | \          \|
    A--B        A--B          B
*/
// interpolation functions for the upper triangle, in order C-D-B
~upperInterp = {arg p;
	[ 1-p.x, 1-p.y, (p.x+p.y)-1 ]
};

// interpolation functions for lower triangle, in order A-B-C
~lowerInterp = {arg p;
	[ 1-(p.x+p.y), p.x, p.y ]
};
/*
Uses a cross product for ba x ca, given points a= 0@1 and b=1@0,
given an input point c.

Function will return 1 if in upper triangle of JI lattice; 0 if lower
*/
~pickSide = { arg a, b, c; var cross;
	cross = ((b.x-a.x)*(c.y-a.y)) - ((b.y-a.y)*(c.x-a.x));
	cross.sign;
};
/*
Provdes a list of speaker #'s and volume based on position within the lattice.
Input point must be within range [0,3] & [0,3].
Returns the amplitudes and indices of speakers at vertices of triangle
containing the input point.
*/
~speak = {arg p; var amp, dp, i, j, op, spkrs;
	op = p.trunc(1);    // origin of cell in CLEAT array
	i = op.x.asInteger;
	j = op.y.asInteger;
	dp = p - op;
	if (~pickSide.value(0@1,1@0,dp)<1,
		{
			amp = ~lowerInterp.value(dp);
			// assign speaker #'s based on ordering shown above
			spkrs = [(j*4)+i, (j*4)+(i+1), ((j+1)*4)+i];
		},
		{
			amp = ~upperInterp.value(dp);
			// assign speaker #'s based on ordering shown above
			spkrs = [((j+1)*4)+i, (j*4)+(i+1), ((j+1)*4)+(i+1)];
		}
	);
	[amp, spkrs]
};

// Just Intonation Lattice code
// Given integers a, b & c, compute the frequency ratio at that lattice position.
~baseV = Array.with(3/2, 5/4, 7/4);

~calc_ratio = {arg a, b, c;
	var r;

	r = (~baseV[0]**a)*(~baseV[1]**b)*(~baseV[2]**c);
	while ( {r>=2.0}, {r = r/2.0} );
	while ( {r<1.0}, {r = r*2.0} );
	r
};

// Fills an 1D array with frequency multiplier for CLEAT speakers
~latticeFreq = Array.fill(16, { |i|
	~calc_ratio.value((i%4).asInteger,(i/4).floor.asInteger,0)
});
)

//=========================================================================
// SynthDef

// a simple sine wave with envelope
(
SynthDef(\tone, {arg amp = 0.05, freq = 220, out = 0,
	attack = 0.1, sustain = 1.0, release = 1.5;
var env, snd;
env = Env.linen(attack, sustain, release, amp, \welch).kr(doneAction: Done.freeSelf);
	snd = SinOsc.ar(freq);
Out.ar(out, env*snd);
}).add;

// from https://thormagnusson.gitbooks.io/scoring/content/PartII/chapter11.html
SynthDef(\marimba, {arg out=0, amp=0.1, t_trig=1, freq=100, rq=0.006;
    var env, signal;
    var rho, theta, b1, b2;
    b1 = 1.987 * 0.9889999999 * cos(0.09);
    b2 = 0.998057.neg;
    signal = SOS.ar(K2A.ar(t_trig), 0.3, 0.0, 0.0, b1, b2);
    signal = RHPF.ar(signal*0.8, freq, rq) + DelayC.ar(RHPF.ar(signal*0.9, freq*0.99999, rq*0.999), 0.02, 0.01223);
    signal = Decay2.ar(signal, 0.4, 0.3, signal);
    DetectSilence.ar(signal, 0.01, doneAction:2);
    Out.ar(out, signal*(amp*0.4)!2);
}).add;

SynthDef(\pluck, {arg out=0, amp = 0.05, wnamp=0.1, freq = 440, decay = 5, mutedString = 0.05;
var env, snd;
env = Env.linen(0, decay, 0).kr(doneAction: 2);
snd = Pluck.ar(
in: WhiteNoise.ar(wnamp),
trig: Impulse.kr(0),
maxdelaytime: 0.1,
delaytime: freq.reciprocal,
decaytime: decay,
coef: mutedString);
Out.ar(out, amp*snd);
}).add;
)

//=========================================================================
// Set up window for "playing" the CLEAT array
(
w = Window.new("CLEAT Lattice", Rect(600, 100, 600, 600)).front;
w.view.background_(Color.white);
w.drawFunc = {
    // set the Color
    Pen.fillColor = Color.red;

	[0,200,400].do({ arg j;
		[0,200,400].do({ arg i;
			Pen.moveTo((i+0)@(j+0));
			Pen.lineTo((i+200)@(j+0));
			Pen.lineTo((i+200)@(j+200));
			Pen.lineTo((i+0)@(j+0));
			Pen.draw(2); // just stroke
		});
	});
};

w.acceptsMouseOver = true;

~notes = Array2D.fromArray(4,4,
	["C", "G", "D", "A","E", "B", "F#", "C#","G#","D#", "A#","F","C", "G", "D", "A"] );
~lowChords = Array2D.fromArray(3,3,
	["C","G","D","E","B","F#","Ab","Eb","Bb"]);
~hiChords = Array2D.fromArray(3,3,
	["Em","Bm","F#m","G#m","Ebm","Bbm","Cm","Gm","Dm"]);

[15,220,420,580].do({ arg j, jj;
	[5,205,405,575].do({ arg i, ii; var a;
		a = StaticText(w,Rect(i,j,40,20));
		a.string = ~notes[3-jj,ii];
		a.font = Font("Monaco", 16);
	});
});

[130,330,530].do({ arg j, jj;
	[60,260,460].do({ arg i, ii; var a;
		a = StaticText(w,Rect(i,j,40,20));
		a.string = ~lowChords[2-jj,ii];
		a.font = Font("Monaco", 20);
	});
});

[55,255,455].do({ arg j, jj;
	[115,325,525].do({ arg i, ii; var a;
		a = StaticText(w,Rect(i,j,60,30));
		a.string = ~hiChords[2-jj,ii];
		a.font = Font("Monaco", 20);
	});
});
w.refresh;

v = UserView(w, w.view.bounds);

v.mouseOverAction_({arg v, ax, ay; //|v,ax,ay|
	x = ax; y = ay;
/*	Point.new(
		x: x*(3/v.bounds.width),
		y: (((v.bounds.height-1)-y)*(3/v.bounds.height))
	).postln;*/
});

v.mouseDownAction_({arg v,ax,ay; var p, as, op, frq;
	p = Point.new(
		x: x*(3/v.bounds.width),
		y: (((v.bounds.height-1)-y)*(3/v.bounds.height))
	);
	as = ~speak.value(p);
	as.postln;
	as[0].do({arg a, i;
		a.postln;
		op = as[1][i];  // speaker
		frq = 220.0*~latticeFreq[op];
		// Just for testing in stereo (comment out for CLEAT)
		// op = if( (op%4)<2, 0, 1);
		Synth(\tone, ["freq", frq, "out",op, "amp", (0.02*a) ] );
		//Synth(\marimba, ["freq", frq, "out",op, "amp", (0.2*a) ] );
	});
});
)

// Close the window when done
w.close;


//=========================================================================
// Alternatively, use touchOSC to play the CLEAT array

/*
This is intended for the XY option of the SIMPLE TouchOSC interface

For seeing of TouchOSC is working
Set up TouchOSC with outgoing port set to 57120
Run the next line.  There should be messages from TouchOSC actions
(e.g. moving the xy cursor).
*/
OSCFunc.trace(true); // Turn posting on

OSCFunc.trace(false); // Turn posting off

/*
Notes will play when the first button on the TouchOSC SIMPLE/XY screen
is pressed. To reset the button, we will need to send messages back to TouchOSC.
The default incoming port is 9000.  Get the ip address from the OSC messages
printed out above.

And, run this next line only once:
*/
b = NetAddr.new(x.x.x.x,9000);
/*
Handle OSC messages
*/
(
// Address and port for touchOSC to receive messages from supercollider
~oscX = 0.0;
~oscY = 0.0;
~pressedOSC = false;

~latticeX = OSCFunc({
	arg msg, time, addr, recvPort;
	~oscX = 3*msg[1];

},'/3/xy/x');

~latticeY = OSCFunc({
	arg msg, time, addr, recvPort;
	~oscY = 3*msg[1];
},'/3/xy/y');

~toggle1 = OSCFunc({
	arg msg, time, addr, recvPort;
	if(msg[1]>0.0,~pressedOSC = true);
	b.sendMsg("/3/toggle1",0.0);  // turn off the toggle
},'/3/toggle1');
)

(
r = Routine {

	inf.do(
		{
			if ( ~pressedOSC,
				{
					var p, as, op, frq;

					p = Point.new(x: ~oscX, y: ~oscY);
					p.postln;
					as = ~speak.value(p);
					as.postln;
					as[0].do({arg a, i;
						a.postln;
						op = as[1][i];  // speaker
						frq = 220.0*~latticeFreq[op];
						// Just for testing in stereo (comment out for CLEAT)
						frq.postln;
						// op = if( (op%4)<2, 0, 1);
						Synth(\tone, ["freq", frq, "out",op, "amp", (0.01*a) ] );
						//Synth(\marimba, ["freq", frq, "out",op, "amp", (0.2*a) ] );
						//Synth(\pluck, ["freq", frq, "out",op, "amp", (0.1*a) ] );
					});

					~pressedOSC = false;
				}
			);
			0.2.wait;
		}
	);
	}.play(AppClock);
)

// To stop the routine
r.stop;

// Disconnect from TouchOSC
b.disconnect;
// To release OSC message handlers
(
~latticeX.release;
~latticeY.release;
~toggle1.release;
)