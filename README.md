# scCLEAT

Some supercollider scripts for use with the CLEAT system at Elastic Arts in Chicago

### justCLEAT.sc

This demo treats the CLEAT array as a just intonation lattice.  Clicking the mouse in the window showing the lattice provides for playing single notes, note pairs and chords. Playing chords in adjacent triangles of the lattice allows for neo-Reimannian chord progressions.

This file contains code for placing sound within the CLEAT array using piecewise linear interpolation functions.  The interpolation requires two coordinates between 0 and 3.

### two_community_graphics_multiaudio.scd

An example based on a paper for a [Two-Community Noisy Kuramoto Model](https://journals.sagepub.com/doi/10.1177/0748730419898314), that allows for multiple copies of two audio samples to be brought in and out of synchronization -- both within and between the communities.  The Simple layout of TouchOSC is used for setting parameters that enable interaction between the communities.

An alternate interpolation strategy is used in this code.  A continuous bicubic interpolation takes perpendicular spatial coordinates x1 & x2 in range [-1,1],[-1,1] and maps to CLEAT speaker array.  The bicubic interpolation can result in (relatively small) negative values, which can create some phasing effects (which may or may not be desirable).  At present, there is a line of code that sets any negative values to zero.
