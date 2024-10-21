//-----------------------------------------------------------------------------
// name: LiSa-granular.ck
// desc: Granular synthesis using audio input with LiSa
//-----------------------------------------------------------------------------

// Audio input (microphone or line-in)
adc => LiSa2 lisa => dac;

// LiSa duration (this also allocates internals)
lisa.duration( 1::second ); // 5 seconds of buffer
// Set max voices
lisa.maxVoices( 60 );
// Set voice pan
for( int v; v < lisa.maxVoices(); v++ )
{
    // Can pan across all available channels
    lisa.pan( v, Math.random2f( 0, lisa.channels()-1 ) );
}
// Set ramp time for smooth transitions
lisa.recRamp( 50::ms );

// Start recording from audio input (adc)
lisa.record( true );
// Set recording gain (how much of the input gets recorded)
lisa.gain( 0.8 );

// Loop indefinitely, generating grains
while( true )
{
    // Generate random grain parameters
    Math.random2f( 1, 2 ) => float newrate;
    Math.random2f( 250, 750 )::ms => dur newdur;

    // Spork a new grain
    spork ~ getgrain( newdur, 20::ms, 20::ms, newrate );

    // Advance time (this sets the interval between grains)
    50::ms => now;
}

// Function to play a grain
fun void getgrain( dur grainlen, dur rampup, dur rampdown, float rate )
{
    // Get an available voice from LiSa
    lisa.getVoice() => int newvoice;

    // Make sure we got a valid voice
    if( newvoice > -1 )
    {
        // Set play rate (affects pitch and speed)
        lisa.rate(newvoice, rate);
        
        // Set play position (start playing from a random position within the recorded buffer)
        Math.random2f( 0.0, lisa.duration() / second )::second => dur playPos;
        lisa.playPos(newvoice, playPos);
        
        // Set ramp up duration for the grain (fade in)
        lisa.rampUp( newvoice, rampup );
        
        // Play the grain for the specified duration minus the ramp times
        (grainlen - (rampup + rampdown)) => now;
        
        // Set ramp down duration (fade out)
        lisa.rampDown( newvoice, rampdown );
        
        // Wait for the ramp down to complete
        rampdown => now;
    }
}
